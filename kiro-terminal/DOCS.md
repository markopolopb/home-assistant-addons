# Kiro Terminal

Amazon's [Kiro CLI](https://kiro.dev/docs/cli/) AI coding assistant in a web terminal, as a Home Assistant add-on.

## About

This add-on runs the Kiro CLI in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Kiro CLI is an AI coding agent that reads your codebase, writes code, and runs commands. Open it from the sidebar, sign in once with your AWS Builder ID, and ask Kiro to write automations, debug YAML, or manage your setup.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Kiro Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" to access the terminal
5. On first use, run `kiro-cli login` and follow the Builder ID browser login flow

You need an AWS Builder ID (free) to use Kiro CLI. Your credentials are stored under `/data` and persist across restarts and add-on updates, so you won't need to log in again.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_kiro` | `true` | Start `kiro-cli chat` immediately when the terminal opens. Set to `false` to get a shell instead (run `kiro-cli chat` yourself). |
| `kiro_auto_update` | `true` | Keep Kiro CLI current: installs the official build into `/data` and updates it in the background on each startup. |
| `working_directory` | `""` | Directory the terminal session starts in (default `/config`), e.g. `/config/ai_repo`. A non-existent path falls back to `/config` with a warning. |
| `kiro_extra_args` | `""` | Extra flags appended to the `kiro-cli chat` launch. Parsed like a shell command line. |
| `persistent_apk_packages` | `[]` | APK packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Usage

With default settings, Kiro CLI starts a chat session automatically inside a tmux session named `kiro`. Navigating away in Home Assistant and coming back reattaches to the same session.

Useful commands (in shell mode, or after exiting Kiro):

```bash
kiro-cli chat       # start an interactive Kiro CLI session
kiro-cli login      # sign in with your AWS Builder ID
kiro-cli whoami     # show the signed-in identity
kiro-cli version    # print the installed Kiro CLI version
```

### Authentication

Kiro CLI authenticates with a free AWS Builder ID. On first use run `kiro-cli login`; it prints a URL and a code. Open the URL in your browser, enter the code, and approve the sign-in. The resulting credentials live under `/data` and survive restarts.

### Terminal tips

- **Scrolling**: use the mouse wheel — tmux copy-mode opens automatically. Press `q` to jump back to the bottom.
- **Copying**: hold **Shift** while you drag to select, which uses the browser terminal's own selection and copies on release.
- **Pasting**: use `Ctrl+Shift+V` (or right-click, depending on browser).

### File access

The terminal starts in `/config` (your Home Assistant configuration). Also mounted:

- `/addon_configs` — configuration directories of your other add-ons
- `/share` — the shared folder

## Security notes

**This add-on gives Kiro a lot of power by design**: it runs as root in its container and has read/write access to `/config`, `/addon_configs`, and `/share`. A prompt injection in any file or web page Kiro reads could modify your HA configuration. Treat every account on your instance as trusted while this add-on is installed.

**Any Home Assistant user can reach the terminal, not just administrators.** `panel_admin: true` hides the sidebar entry from non-admins but does not restrict the ingress URL. A non-admin account is one URL away from a root shell in this container.

**Publishing port 7681 exposes an unauthenticated root shell.** The port is closed by default and ingress does not need it. Leave it unset unless the port is firewalled off.

## Troubleshooting

- **`kiro-cli` not found**: restart the add-on; startup installs the persistent build into `/data` and falls back to the bundled copy at `/usr/local/bin/kiro-cli`.
- **Authentication problems**: run `kiro-cli logout`, then `kiro-cli login` again.
- **Kiro exits immediately**: restart the add-on so the background auto-updater can fetch the latest Kiro CLI; check the add-on log for update messages.
