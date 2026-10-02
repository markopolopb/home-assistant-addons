#!/bin/bash

# tmux-status.sh — lightweight status bar data for Goose Terminal
# Called by tmux every status-interval seconds. Must be fast (<1s).

# --- Provider/key status ---
provider_status() {
    if [ -n "$GEMINI_API_KEY" ] || [ -n "$GOOGLE_API_KEY" ]; then
        echo "#[fg=colour114]Gemini"
    else
        echo "#[fg=colour203]Gemini"
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

provider=$(provider_status)
ha=$(ha_status)
datetime=$(date '+%a %m-%d %H:%M')

echo "${provider} #[fg=colour245]| ${ha} #[fg=colour245]| #[fg=colour252]${datetime}"
