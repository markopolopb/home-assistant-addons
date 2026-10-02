# Changelog

## 1.1.0

- Validate `goose_model` at startup against the models the Gemini API key can
  call (ListModels), matching only models that support `generateContent`.
- An unavailable or typo'd model now falls back to a working default
  (preferring `gemini-2.5-flash`) with the available models logged, instead of
  Goose exiting silently (code 0) a few seconds after launch.
- The validation lookup is strictly bounded (short timeout, single attempt, no
  retries) and non-fatal: startup never blocks on it, and any failure keeps the
  configured model unchanged.

## 1.0.0

- Initial release.
- Block's Goose CLI in a ttyd + tmux web terminal.
- Wired to Google Gemini via `gemini_api_key` (exported as `GEMINI_API_KEY`/`GOOGLE_API_KEY`).
- Provider and model pinned via `GOOSE_PROVIDER`/`GOOSE_MODEL` and `~/.config/goose/config.yaml`.
- Persistent config, sessions, and optional native Goose install in `/data`.
- Background auto-update of the Goose binary.
- `/config`, `/addon_configs`, and `/share` mounted read/write.
