#!/bin/bash
# Launch impala wifi TUI in kitty, or focus the existing window if already open.
APP_ID="hypr.impala"

# Focus existing window if open
if hyprctl clients -j | jq -e ".[] | select(.initialClass == \"$APP_ID\")" > /dev/null 2>&1; then
    hyprctl dispatch focuswindow "initialClass:$APP_ID"
    exit 0
fi

# Unblock wifi in case rfkill had it blocked
rfkill unblock wifi

# Launch impala in a dedicated kitty instance
exec kitty --app-id="$APP_ID" --title="WiFi" impala
