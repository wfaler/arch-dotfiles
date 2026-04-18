#!/bin/bash
# Launch bluetui in kitty, or focus the existing window if already open.

APP_ID="hypr.bluetui"

# Focus existing window if open
if hyprctl clients -j | jq -e ".[] | select(.initialClass == \"$APP_ID\")" > /dev/null 2>&1; then
    hyprctl dispatch focuswindow "initialClass:$APP_ID"
    exit 0
fi

# Unblock bluetooth in case rfkill had it blocked
rfkill unblock bluetooth

# Launch bluetui in a dedicated kitty instance
exec kitty --app-id="$APP_ID" --title="Bluetooth" bluetui
