#!/usr/bin/with-contenv bashio

# Goose Terminal — Block's Goose CLI in a browser terminal (ttyd + tmux),
# wired to Google Gemini.
#
# Startup philosophy: everything the terminal needs is baked into the image,
# and nothing on the boot path may depend on the network or block on input.
# Network work (Goose updates) happens in the background after the terminal
# is already available.

set -e
set -o pipefail

# Initialize environment for Goose CLI using /data (HA best practice).
# Goose reads its config from $HOME/.config/goose and stores sessions under
# the XDG data dir; pinning all of them to /data makes config and history
# survive restarts and add-on updates.
init_environment() {
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local goose_config_dir="$config_dir/goose"

    bashio::log.info "Initializing Goose environment in /data..."

    if ! mkdir -p "$data_home" "$goose_config_dir" "$cache_dir" "$state_dir" "/data/.local/bin" "/data/.local/share"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$goose_config_dir"

    # XDG + application environment
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # A persistent install in /data wins over the copy bundled in the image
    export PATH="$data_home/.local/bin:/data/.local/bin:$PATH"

    # Store API keys in the config file rather than the OS keyring: there is
    # no keyring daemon in this container, so point Goose at the file backend.
    export GOOSE_DISABLE_KEYRING=1

    # Install tmux configuration to user home directory
    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
    fi

    bashio::log.info "Environment initialized (HOME=${HOME})"
}

# Install user-facing commands into /usr/local/bin
setup_commands() {
    if [ -f /opt/scripts/welcome.sh ]; then
        cp /opt/scripts/welcome.sh /usr/local/bin/welcome
        chmod +x /usr/local/bin/welcome
    else
        bashio::log.warning "Script not found: /opt/scripts/welcome.sh"
    fi

    # Write add-on version for the welcome banner (no bashio inside ttyd)
    bashio::addon.version > /opt/scripts/addon-version 2>/dev/null \
        || echo "unknown" > /opt/scripts/addon-version
}

# Resolve a persistent goose binary that actually runs. The bundled copy in
# the image is frozen at build time; a persistent install in /data (when
# present and runnable) takes precedence.
goose_bin() {
    if [ -x "$HOME/.local/bin/goose" ]; then
        echo "$HOME/.local/bin/goose"
    else
        echo "/usr/local/bin/goose"
    fi
}

# A persistent install being executable is not the same as it being
# runnable (a libc mismatch aborts a dynamically linked binary on launch).
# Treat "installed" and "actually runs" as separate facts.
persistent_goose_runs() {
    [ -x "$HOME/.local/bin/goose" ] || return 1
    timeout 10 "$HOME/.local/bin/goose" --version >/dev/null 2>&1
}

# Keep Goose current. Refresh happens in the background so a slow network
# never delays the terminal. Goose's own `goose update` self-updates the
# install that is on PATH; run it against the persistent copy when present,
# otherwise install the persistent copy from the official script.
update_goose() {
    if [ "$(bashio::config 'goose_auto_update' 'true')" != "true" ]; then
        bashio::log.info "Goose auto-update disabled; using bundled Goose ($(goose_bin))"
        return 0
    fi

    if persistent_goose_runs; then
        bashio::log.info "Persistent Goose found; checking for updates in background"
        (
            "$HOME/.local/bin/goose" update >/dev/null 2>&1 || true
            # An update can pull a build this image's libc can't run; drop it
            # so it doesn't shadow the working bundled copy on next launch.
            if [ -x "$HOME/.local/bin/goose" ] && ! timeout 10 "$HOME/.local/bin/goose" --version >/dev/null 2>&1; then
                bashio::log.warning "Updated Goose no longer runs in this image; falling back to the bundled copy"
                rm -f "$HOME/.local/bin/goose"
            fi
        ) &
        return 0
    fi

    bashio::log.info "Installing persistent Goose into /data (background)..."
    (
        # Portable musl build for Alpine; install into /data so it persists.
        if curl -fsSL --connect-timeout 10 https://github.com/block/goose/releases/download/stable/download_cli.sh \
            | CONFIGURE=false GOOSE_BIN_DIR="$HOME/.local/bin" GOOSE_LINUX_VARIANT=musl bash >/dev/null 2>&1 \
            && persistent_goose_runs; then
            bashio::log.info "Persistent Goose installed: $("$HOME/.local/bin/goose" --version 2>/dev/null || echo 'version unknown')"
        else
            rm -f "$HOME/.local/bin/goose"
            bashio::log.warning "Persistent Goose install unavailable or unrunnable; using bundled copy"
        fi
    ) &
}

# Export the Gemini API key and provider settings so the auto-launched Goose
# can use them. The tmux session command runs through a non-interactive
# shell, so these must be in the environment ttyd/tmux inherits — a ~/.bashrc
# export would never reach it. The key value itself is never logged.
export_gemini_config() {
    local api_key model
    api_key=$(bashio::config 'gemini_api_key' '')
    model=$(bashio::config 'goose_model' 'gemini-2.5-flash')

    # Tell Goose which provider/model to use without an interactive wizard.
    export GOOSE_PROVIDER="gemini"
    export GOOSE_MODEL="$model"

    if [ -n "$api_key" ] && [ "$api_key" != "null" ]; then
        # Goose reads the Gemini provider key from GOOGLE_API_KEY / GEMINI_API_KEY.
        export GEMINI_API_KEY="$api_key"
        export GOOGLE_API_KEY="$api_key"
        bashio::log.info "Gemini API key loaded from add-on configuration (model: ${model})"
    else
        bashio::log.warning "No gemini_api_key set — Goose cannot reach Gemini until you add one in the add-on configuration"
    fi
}

# Write a minimal Goose config.yaml so the provider/model are set even for
# commands that read the file directly. Only (re)write the provider lines;
# never store the API key here (it stays in the environment).
write_goose_config() {
    local goose_config_dir="$XDG_CONFIG_HOME/goose"
    local config_file="$goose_config_dir/config.yaml"
    local model
    model=$(bashio::config 'goose_model' 'gemini-2.5-flash')

    mkdir -p "$goose_config_dir"

    cat > "$config_file" <<EOF
GOOSE_PROVIDER: gemini
GOOSE_MODEL: ${model}
EOF
    chmod 600 "$config_file"
    bashio::log.info "Wrote Goose config (provider=gemini, model=${model})"
}

# Install persistent packages from config and saved state
install_persistent_packages() {
    local apk_packages=""
    local pip_packages=""

    if bashio::config.has_value 'persistent_apk_packages'; then
        local config_apk
        config_apk=$(bashio::config 'persistent_apk_packages')
        if [ -n "$config_apk" ] && [ "$config_apk" != "null" ]; then
            apk_packages="$config_apk"
        fi
    fi

    if bashio::config.has_value 'persistent_pip_packages'; then
        local config_pip
        config_pip=$(bashio::config 'persistent_pip_packages')
        if [ -n "$config_pip" ] && [ "$config_pip" != "null" ]; then
            pip_packages="$config_pip"
        fi
    fi

    apk_packages=$(echo "$apk_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
    pip_packages=$(echo "$pip_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    if [ -n "$apk_packages" ]; then
        bashio::log.info "Installing persistent APK packages: $apk_packages"
        # shellcheck disable=SC2086
        apk add --no-cache $apk_packages || bashio::log.warning "Some APK packages failed to install"
    fi

    if [ -n "$pip_packages" ]; then
        bashio::log.info "Installing persistent pip packages: $pip_packages"
        # shellcheck disable=SC2086
        pip3 install --break-system-packages --no-cache-dir $pip_packages || bashio::log.warning "Some pip packages failed to install"
    fi
}

# Directory the session starts in. Defaults to /config; a configured value
# must exist, or we warn and fall back — a typo'd path must never take the
# terminal down.
get_working_directory() {
    local dir
    dir=$(bashio::config 'working_directory' '')
    if [ -z "$dir" ] || [ "$dir" = "null" ]; then
        echo "/config"
        return 0
    fi
    if [ -d "$dir" ]; then
        echo "$dir"
    else
        bashio::log.warning "working_directory '$dir' does not exist; starting in /config instead"
        echo "/config"
    fi
}

# Build the command tmux runs inside the session.
get_session_command() {
    local extra bin
    bin=$(goose_bin)
    extra=$(bashio::config 'goose_extra_args' '')
    [ "$extra" = "null" ] && extra=""

    if [ "$(bashio::config 'auto_launch_goose' 'true')" = "true" ]; then
        # `goose session` starts an interactive agent session.
        echo "$bin session${extra:+ $extra}"
    else
        # Shell mode: banner + interactive bash, still inside tmux for
        # reconnect persistence. Run 'goose session' manually when ready.
        echo "/usr/local/bin/welcome --shell"
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    local session_command workdir
    session_command=$(get_session_command)
    workdir=$(get_working_directory)

    bashio::log.info "Starting web terminal on port ${port} (auto_launch_goose=$(bashio::config 'auto_launch_goose' 'true'))"

    # Terminal theme — dark palette with a goose-blue accent (#4f9cf9)
    local ttyd_theme='{"background":"#1a1b26","foreground":"#c0caf5","cursor":"#4f9cf9","cursorAccent":"#1a1b26","selectionBackground":"#33467c","selectionForeground":"#c0caf5","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#7dcfff","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#7dcfff","brightWhite":"#c0caf5"}'

    # ttyd execs its argv directly, so tmux is started without an extra shell.
    # tmux -A attaches to the live session on browser reconnects instead of
    # stacking new ones.
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option enableReconnect=true \
        --client-option reconnect=10 \
        --client-option reconnectInterval=5 \
        --client-option "theme=${ttyd_theme}" \
        --client-option fontSize=14 \
        tmux new-session -A -s goose -c "$workdir" "$session_command"
}

# Main execution
main() {
    bashio::log.info "Starting Goose Terminal add-on..."

    init_environment
    setup_commands
    export_gemini_config
    write_goose_config
    update_goose
    install_persistent_packages
    start_web_terminal
}

main "$@"
