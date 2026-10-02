# Goose Terminal

Block's [Goose](https://block.github.io/goose/) CLI AI agent in a web terminal, wired to Google Gemini, as a Home Assistant add-on.

## About

This add-on runs the open-source [Goose](https://github.com/block/goose) CLI in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Goose is a general-purpose, on-machine AI agent: it runs shell commands, edits files, and orchestrates multi-step tasks. This add-on connects it to Google Gemini out of the box.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Goose Terminal add-on
3. Get a Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
4. Open the add-on **Configuration** tab and paste the key into `gemini_api_key`
5. Start the add-on
6. Click "OPEN WEB UI" to access the terminal

Goose config and session history are stored under `/data` and persist across restarts and add-on updates.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `gemini_api_key` | `""` | Your Google Gemini API key (from [AI Studio](https://aistudio.google.com/app/apikey)). Exported into the environment as `GEMINI_API_KEY`/`GOOGLE_API_KEY` so Goose can reach Gemini. Masked in the UI, but included in HA backups like all add-on options. |
| `goose_model` | `"gemini-2.5-flash"` | Gemini model Goose uses, e.g. `gemini-2.5-flash` or `gemini-2.5-pro`. Validated at startup against the models available to your API key; an unavailable (or typo'd) model falls back to a working default, with the available models listed in the add-on log. |
| `auto_launch_goose` | `true` | Start a Goose session immediately when the terminal opens. Set to `false` to get a shell instead (run `goose session` yourself). |
| `goose_auto_update` | `true` | Keep Goose current: installs the official build into `/data` and updates it in the background on each startup. |
| `working_directory` | `""` | Directory the terminal session starts in (default `/config`), e.g. `/config/ai_repo`. A non-existent path falls back to `/config` with a warning. |
| `goose_extra_args` | `""` | Extra flags appended to the `goose session` launch. Parsed like a shell command line. |
| `persistent_apk_packages` | `[]` | APK packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Usage

With default settings, Goose starts an interactive session automatically inside a tmux session named `goose`. Navigating away in Home Assistant and coming back reattaches to the same session.

Useful commands (in shell mode, or after exiting Goose):

```bash
goose session         # start an interactive Goose session
goose session -r      # resume the previous session
goose run -t "..."    # run a one-shot task non-interactively
goose --version       # print the installed Goose version
```

### How the Gemini key is wired

The add-on reads `gemini_api_key` from your configuration at startup and exports it to the environment the terminal inherits:

```bash
# Export the API key for the agent
export GEMINI_API_KEY="$(bashio::config 'gemini_api_key')"
export GOOGLE_API_KEY="$GEMINI_API_KEY"
export GOOSE_PROVIDER="gemini"
export GOOSE_MODEL="<goose_model>"
```

It also writes a minimal `~/.config/goose/config.yaml` pinning the provider and model, so Goose never prompts the interactive setup wizard. The key value is never written to the config file or logged.

### Terminal tips

- **Scrolling**: use the mouse wheel — tmux copy-mode opens automatically. Press `q` to jump back to the bottom.
- **Copying**: hold **Shift** while you drag to select, which uses the browser terminal's own selection and copies on release.
- **Pasting**: use `Ctrl+Shift+V` (or right-click, depending on browser).

### File access

The terminal starts in `/config` (your Home Assistant configuration). Also mounted:

- `/addon_configs` — configuration directories of your other add-ons
- `/share` — the shared folder

## Security notes

**This add-on gives Goose a lot of power by design**: it runs as root in its container and has read/write access to `/config`, `/addon_configs`, and `/share`. A prompt injection in any file or web page Goose reads could modify your HA configuration. Treat every account on your instance as trusted while this add-on is installed.

**Any Home Assistant user can reach the terminal, not just administrators.** `panel_admin: true` hides the sidebar entry from non-admins but does not restrict the ingress URL. A non-admin account is one URL away from a root shell in this container.

**Publishing port 7681 exposes an unauthenticated root shell.** The port is closed by default and ingress does not need it. Leave it unset unless the port is firewalled off.

## Troubleshooting

- **Goose can't reach Gemini / authentication errors**: confirm `gemini_api_key` is set in the add-on configuration and restart the add-on. Check the add-on log for the "Gemini API key loaded" message.
- **Model errors**: `goose_model` is validated at startup against the models your key can call. If it is unavailable (e.g. a typo or a model your key lacks access to), the add-on logs a warning, lists the available models, and automatically falls back to a working default (preferring `gemini-2.5-flash`) so the terminal still launches. Check the add-on log to see which model is in use.
- **Goose exits immediately**: restart the add-on so the background auto-updater can fetch the latest Goose; check the add-on log for update messages.
