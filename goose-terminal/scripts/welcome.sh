#!/bin/bash

# Goose Terminal banner — compact, non-blocking header with version and tips.
# With --shell, drops into an interactive bash afterwards (shell mode).
# Runs inside ttyd/tmux (user-visible) — plain bash, no bashio.

GOOSEBLUE='\033[38;2;79;156;249m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version=$(cat /opt/scripts/addon-version 2>/dev/null || echo "unknown")
model="${GOOSE_MODEL:-gemini-2.5-flash}"

echo ""
echo -e "  ${GOOSEBLUE}Goose Terminal${NC}  ${DIM}v${version} · Home Assistant add-on${NC}"
echo -e "  ${DIM}provider: gemini · model: ${model}${NC}"
echo ""
echo -e "  ${WHITE}goose session${NC}       start an interactive Goose session"
echo -e "  ${WHITE}goose session -r${NC}    resume the previous session"
echo -e "  ${WHITE}goose run -t '...'${NC}   run a one-shot task non-interactively"
echo -e "  ${WHITE}goose --version${NC}      print the installed Goose version"
echo ""

if [ -z "$GEMINI_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
    echo -e "  ${WHITE}!${NC} No Gemini API key set. Add 'gemini_api_key' in the add-on configuration."
    echo ""
fi

echo -e "  ${DIM}Copy: hold Shift and drag · Paste: Ctrl+Shift+V${NC}"
echo ""

if [ "$1" = "--shell" ]; then
    exec bash
fi
