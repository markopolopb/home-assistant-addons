#!/bin/bash

# tmux-status.sh — lightweight status bar data for Kiro Terminal
# Called by tmux every status-interval seconds. Must be fast (<1s).

# --- Auth status ---
# Kiro CLI stores Builder ID credentials under its config dir. We can't
# cheaply validate the token here, so treat "a credentials/auth file exists"
# as logged in (green) and its absence as logged out (red).
auth_status() {
    local base="${XDG_CONFIG_HOME:-$HOME/.config}"
    if ls "$base"/kiro-cli/*.json "$base"/kiro/*.json \
          "$HOME"/.local/share/kiro-cli/* >/dev/null 2>&1; then
        echo "#[fg=colour114]Auth"
    else
        echo "#[fg=colour203]Auth"
    fi
}

# --- HA connection status ---
ha_status() {
    if [ -z "$SUPERVISOR_TOKEN" ]; then
        echo "#[fg=colour245]HA"
        return
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 2 \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
        "http://supervisor/core/api/" 2>/dev/null)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "#[fg=colour114]HA"
    else
        echo "#[fg=colour208]HA"
    fi
}

auth=$(auth_status)
ha=$(ha_status)
datetime=$(date '+%a %m-%d %H:%M')

echo "${auth} #[fg=colour245]| ${ha} #[fg=colour245]| #[fg=colour252]${datetime}"
