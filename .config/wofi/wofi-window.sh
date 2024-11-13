#!/bin/bash

# Get the list of windows from hyprctl
windows=$(hyprctl clients -j | jq -r '.[] | select(.class != "wofi") | "\(.class): \(.title) \(.address)"')

# Show windows in wofi and get user selection
selected=$(echo "$windows" | wofi --dmenu --prompt="Switch to window" --cache-file=/dev/null)

# If user selected a window, focus it
if [ -n "$selected" ]; then
    # Extract window address from selection
    window_address=$(echo "$selected" | awk '{print $NF}')
    # Focus the selected window
    hyprctl dispatch focuswindow "address:$window_address"
fi

