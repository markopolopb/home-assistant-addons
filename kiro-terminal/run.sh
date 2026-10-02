#!/usr/bin/with-contenv bashio

# Kiro Terminal — Amazon's Kiro CLI in a browser terminal (ttyd + tmux).
#
# Startup philosophy: everything the terminal needs is baked into the image,
# and nothing on the boot path may depend on the network or block on input.
# Network work (Kiro updates) happens in the background after the terminal is
# already available.

set -e
set -o pipefail

# Initialize environment for Kiro CLI using /data (HA best practice).
# Kiro stores its config/auth under the XDG dirs; pinning them to /data makes
# the Builder ID login and settings survive restarts and add-on updates.
init_environment() {
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"

    bashio::log.info "Initializing Kiro CLI environment in /data..."

    if ! mkdir -p "$data_home" "$config_dir" "$cache_dir" "$state_dir" "/data/.local/bin" "/data/.local/share"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir"

    # XDG + application environment
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # A persistent install in /data wins over the copy bundled in the image
    export PATH="$data_home/.local/bin:/data/.local/bin:$PATH"

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

# Resolve a kiro-cli binary that actually runs. The bundled copy in the image
# is frozen at build time; a persistent install in /data (when present and
# runnable) takes precedence.
kiro_bin() {
    if [ -x "$HOME/.local/bin/kiro-cli" ]; then
        echo "$HOME/.local/bin/kiro-cli"
    else
        echo "/usr/local/bin/kiro-cli"
    fi
}

# A persistent install being executable is not the same as it being runnable
# (a libc mismatch aborts a dynamically linked binary on launch). Treat
# "installed" and "actually runs" as separate facts.
persistent_kiro_runs() {
    [ -x "$HOME/.local/bin/kiro-cli" ] || return 1
    timeout 10 "$HOME/.local/bin/kiro-cli" --version >/dev/null 2>&1
}

# Keep Kiro CLI current. The bundled copy in the image is frozen at build
# time, so install the official musl build into /data (persists across
# restarts and add-on updates) and refresh it in the background on each boot.
update_kiro() {
    if [ "$(bashio::config 'kiro_auto_update' 'true')" != "true" ]; then
        bashio::log.info "Kiro auto-update disabled; using bundled Kiro CLI ($(kiro_bin))"
        return 0
    fi

    if persistent_kiro_runs; then
        bashio::log.info "Persistent Kiro CLI found; checking for updates in background"
        (
            "$HOME/.local/bin/kiro-cli" update >/dev/null 2>&1 || true
            # An update can pull a build this image's libc can't run; drop it
            # so it doesn't shadow the working bundled copy on next launch.
            if [ -x "$HOME/.local/bin/kiro-cli" ] && ! timeout 10 "$HOME/.local/bin/kiro-cli" --version >/dev/null 2>&1; then
                bashio::log.warning "Updated Kiro CLI no longer runs in this image; falling back to the bundled copy"
                rm -f "$HOME/.local/bin/kiro-cli"
            fi
        ) &
        return 0
    fi

    bashio::log.info "Installing persistent Kiro CLI into /data (background)..."
    (
        local arch zip tmp
        case "$(uname -m)" in
            x86_64|amd64)  arch="x86_64" ;;
            aarch64|arm64) arch="aarch64" ;;
            *) bashio::log.warning "Unsupported architecture $(uname -m); using bundled Kiro CLI"; exit 0 ;;
        esac
        zip="kirocli-${arch}-linux-musl.zip"
        tmp=$(mktemp -d /tmp/kiro-install.XXXXXX)

        if curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 10 \
                "https://prod.download.cli.kiro.dev/stable/latest/${zip}" -o "$tmp/kirocli.zip" \
            && unzip -q "$tmp/kirocli.zip" -d "$tmp/pkg" \
            && chmod +x "$tmp/pkg/kirocli/install.sh" \
            && KIRO_CLI_SKIP_SETUP=1 bash "$tmp/pkg/kirocli/install.sh" </dev/null >/dev/null 2>&1 \
            && persistent_kiro_runs; then
            bashio::log.info "Persistent Kiro CLI installed: $("$HOME/.local/bin/kiro-cli" --version 2>/dev/null || echo 'version unknown')"
        else
            rm -f "$HOME/.local/bin/kiro-cli"
            bashio::log.warning "Persistent Kiro CLI install unavailable or unrunnable; using bundled copy"
        fi
        rm -rf "$tmp"
    ) &
}

# Install persistent packages from config
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
    bin=$(kiro_bin)
    extra=$(bashio::config 'kiro_extra_args' '')
    [ "$extra" = "null" ] && extra=""

    if [ "$(bashio::config 'auto_launch_kiro' 'true')" = "true" ]; then
        # `kiro-cli chat` starts an interactive agent session.
        echo "$bin chat${extra:+ $extra}"
    else
        # Shell mode: banner + interactive bash, still inside tmux for
        # reconnect persistence. Run 'kiro-cli chat' manually when ready.
        echo "/usr/local/bin/welcome --shell"
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    local session_command workdir
    session_command=$(get_session_command)
    workdir=$(get_working_directory)

    bashio::log.info "Starting web terminal on port ${port} (auto_launch_kiro=$(bashio::config 'auto_launch_kiro' 'true'))"

    # Terminal theme — dark palette with a Kiro purple accent (#8b5cf6)
    local ttyd_theme='{"background":"#1a1b26","foreground":"#c0caf5","cursor":"#8b5cf6","cursorAccent":"#1a1b26","selectionBackground":"#33467c","selectionForeground":"#c0caf5","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#7dcfff","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#7dcfff","brightWhite":"#c0caf5"}'

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
        tmux new-session -A -s kiro -c "$workdir" "$session_command"
}

# Main execution
main() {
    bashio::log.info "Starting Kiro Terminal add-on..."

    init_environment
    setup_commands
    update_kiro
    install_persistent_packages
    start_web_terminal
}

main "$@"
