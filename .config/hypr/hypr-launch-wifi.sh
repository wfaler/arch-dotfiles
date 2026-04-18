#!/bin/bash
# Launch impala wifi TUI in kitty, or focus the existing window if already open.
# Based on omarchy's omarchy-launch-wifi pattern.
# NOTE: Ensure this script is executable (`chmod +x ~/.config/hypr/hypr-launch-wifi.sh`) after stow.

APP_ID="hypr.impala"

# Focus existing window if open
if command -v hyprctl > /dev/null 2>&1 && command -v jq > /dev/null 2>&1 \
    && hyprctl clients -j | jq -e ".[] | select(.initialClass == \"$APP_ID\")" > /dev/null 2>&1; then
    hyprctl dispatch focuswindow "initialClass:$APP_ID"
    exit 0
fi

# Unblock wifi in case rfkill had it blocked
if ! rfkill unblock wifi > /dev/null 2>&1; then
    echo "Warning: could not run 'rfkill unblock wifi' (missing permission or rfkill unavailable)." >&2
fi

# Launch impala in a dedicated kitty instance
exec kitty --app-id="$APP_ID" --title="WiFi" impala
