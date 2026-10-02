#!/bin/bash

# Kiro Terminal banner — compact, non-blocking header with version and tips.
# With --shell, drops into an interactive bash afterwards (shell mode).
# Runs inside ttyd/tmux (user-visible) — plain bash, no bashio.

PURPLE='\033[38;2;139;92;246m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version=$(cat /opt/scripts/addon-version 2>/dev/null || echo "unknown")

echo ""
echo -e "  ${PURPLE}Kiro Terminal${NC}  ${DIM}v${version} · Home Assistant add-on${NC}"
echo ""
echo -e "  ${WHITE}kiro-cli chat${NC}     start an interactive Kiro CLI session"
echo -e "  ${WHITE}kiro-cli login${NC}    sign in with your AWS Builder ID"
echo -e "  ${WHITE}kiro-cli whoami${NC}   show the signed-in identity"
echo -e "  ${WHITE}kiro-cli version${NC}  print the installed Kiro CLI version"
echo ""
echo -e "  ${DIM}First run: 'kiro-cli login' opens a browser login flow (Builder ID).${NC}"
echo -e "  ${DIM}Copy: hold Shift and drag · Paste: Ctrl+Shift+V${NC}"
echo ""

if [ "$1" = "--shell" ]; then
    exec bash
fi
