#!/bin/bash
# Window switcher using fuzzel and hyprctl
# Replaces wofi-window.sh
# Requires jq

selection=$(hyprctl clients -j | \
  jq -r '.[] | "\(.address) \(.workspace.name) | \(.class) — \(.title)"' | \
  fuzzel --dmenu -p "Window: " | \
  awk '{print $1}')

if [[ -n "$selection" ]]; then
  hyprctl dispatch focuswindow "address:$selection"
fi
