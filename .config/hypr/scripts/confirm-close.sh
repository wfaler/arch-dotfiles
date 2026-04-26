#!/usr/bin/env bash
info=$(hyprctl activewindow -j | jq -r '"\(.class): \(.title)"')
choice=$(printf "Yes\nNo" | wofi --dmenu --prompt "Close → $info ?" --width 420 --height 140 --lines 3 --cache-file /dev/null)
[[ "$choice" == "Yes" ]] && hyprctl dispatch killactive ""
