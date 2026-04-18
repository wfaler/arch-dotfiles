#!/bin/bash
# Launch bluetui in kitty, or focus the existing window if already open.
# Based on omarchy's omarchy-launch-bluetooth pattern.
# NOTE: Ensure this script is executable (`chmod +x ~/.config/hypr/hypr-launch-bluetooth.sh`) after stow.

APP_ID="hypr.bluetui"

# Focus existing window if open
if command -v hyprctl > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
    if hyprctl clients -j | jq -e ".[] | select(.initialClass == \"$APP_ID\")" > /dev/null 2>&1; then
        hyprctl dispatch focuswindow "initialClass:$APP_ID"
        exit 0
    fi
fi

# Unblock bluetooth in case rfkill had it blocked
if ! rfkill unblock bluetooth > /dev/null 2>&1; then
    echo "Warning: could not run 'rfkill unblock bluetooth' (missing permission or rfkill unavailable)." >&2
fi

# Launch bluetui in a dedicated kitty instance
exec kitty --app-id="$APP_ID" --title="Bluetooth" bluetui
