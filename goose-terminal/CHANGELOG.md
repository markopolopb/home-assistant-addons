# Changelog

## 1.0.0

- Initial release.
- Block's Goose CLI in a ttyd + tmux web terminal.
- Wired to Google Gemini via `gemini_api_key` (exported as `GEMINI_API_KEY`/`GOOGLE_API_KEY`).
- Provider and model pinned via `GOOSE_PROVIDER`/`GOOSE_MODEL` and `~/.config/goose/config.yaml`.
- Persistent config, sessions, and optional native Goose install in `/data`.
- Background auto-update of the Goose binary.
- `/config`, `/addon_configs`, and `/share` mounted read/write.
