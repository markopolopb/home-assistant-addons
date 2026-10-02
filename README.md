# Home Assistant AI Terminal Add-ons

A collection of Home Assistant add-ons that bring AI coding assistants and agents into a web terminal, right inside your Home Assistant dashboard. Each add-on runs a CLI (Claude Code, Kiro CLI, Goose, or Gemini CLI) in a browser-based terminal with your `/config` mounted.

## Installation

To add this repository to your Home Assistant instance:

1. Go to **Settings** → **Add-ons** and select **Add-on Store**
2. In the top-right corner, select the three dots menu, and select **Repositories**
3. Add the URL: `https://github.com/markopolopb/home-assistant-addons`
4. Select **Add**

## Add-ons

### Claude Terminal

A web-based terminal interface with Anthropic's Claude Code CLI pre-installed. Provides a terminal environment directly in your Home Assistant dashboard for coding, automation, and configuration tasks.

Features:
- Web terminal access through your Home Assistant UI
- Pre-installed Claude Code CLI that launches automatically
- Direct access to your Home Assistant config directory
- No configuration needed (uses OAuth)
- ha-mcp integration for direct Home Assistant control

[Documentation](claude-terminal/DOCS.md) · [Development guide](DEVELOPMENT.md)

### Kiro Terminal

A web-based terminal interface with Amazon's [Kiro CLI](https://kiro.dev/docs/cli/) AI coding assistant pre-installed. Launches automatically in your Home Assistant dashboard with read/write access to your config directory. Sign in once with a free AWS Builder ID.

Features:
- Web terminal access through your Home Assistant UI
- Pre-installed Kiro CLI that launches automatically
- Builder ID login persisted across restarts and updates
- Direct access to your Home Assistant config directory

[Documentation](kiro-terminal/DOCS.md)

### Goose Terminal

A web-based terminal interface with Block's [Goose](https://github.com/block/goose) CLI AI agent, wired to Google Gemini. Add a Gemini API key in the add-on configuration and Goose starts an agent session automatically.

Features:
- Web terminal access through your Home Assistant UI
- Pre-installed Goose CLI, pre-configured for Google Gemini
- Provider and model set from the add-on configuration (no setup wizard)
- Direct access to your Home Assistant config directory

[Documentation](goose-terminal/DOCS.md)

### Gemini Terminal

A web-based terminal interface with Google's [Gemini CLI](https://github.com/google-gemini/gemini-cli) and deep Home Assistant MCP integration. Vendored from the upstream project by [@oded996](https://github.com/oded996/gemini-cli-home-assistant-addons) (see Credits).

Features:
- Web terminal access through your Home Assistant UI
- Pre-installed Gemini CLI with the bundled ha-mcp server for native HA control
- Smart context: auto-generates a `GEMINI.md` with your system state
- Screenshot/visual verification tooling and session persistence via tmux

[Documentation](gemini-terminal/DOCS.md)

## Community Tools

Tools built by the community to enhance these terminals:

- **[ha-ws-client-go](https://github.com/schoolboyqueue/home-assistant-blueprints/tree/main/scripts/ha-ws-client-go)** by [@schoolboyqueue](https://github.com/schoolboyqueue) - Lightweight Go CLI for Home Assistant WebSocket API. Gives the assistant direct access to entity states, service calls, automation traces, and real-time monitoring. Single binary, no dependencies.

- **[Claude Home Assistant Plugins](https://github.com/ESJavadex/claude-homeassistant-plugins)** by [@ESJavadex](https://github.com/ESJavadex) - A collection of Claude Code skills/plugins for Home Assistant, including YAML validation, pre-save hooks, and Lovelace dashboard validation.

- **[Claude Terminal Pro](https://github.com/ESJavadex/claude-code-ha)** by [@ESJavadex](https://github.com/ESJavadex) - A fork with additional features including image paste support, persistent package management, and auto-install configuration.

## Support

If you have any questions or issues with these add-ons, please open an issue in this repository.

## Credits

This repository stands on the work of several people in the Home Assistant and AI tooling communities:

- **Claude Terminal** by **[Tom Cassady (@heytcass)](https://github.com/heytcass/home-assistant-addons)** — the original add-on that every terminal here is built on. The Kiro and Goose add-ons reuse its architecture (ttyd + tmux, `/data` persistence, ingress model).
- **Gemini Terminal** by **[@oded996](https://github.com/oded996/gemini-cli-home-assistant-addons)** — vendored into this repo under its own MIT license (see `gemini-terminal/LICENSE`). That project is itself a refit of Claude Terminal, and additionally credits **[Magnus Overli (@magnusoverli)](https://github.com/magnusoverli)** for OpenCode for Home Assistant.
- **Kiro Terminal** and **Goose Terminal** add-ons in this repo were authored for this collection, modeled on the Claude Terminal foundation above.

The CLIs themselves — Claude Code, Kiro CLI, Goose, and Gemini CLI — are the work of Anthropic, Amazon, Block, and Google respectively, and are each subject to their own terms of service.

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. Vendored add-ons retain their own license files where present (e.g. `gemini-terminal/LICENSE`).
