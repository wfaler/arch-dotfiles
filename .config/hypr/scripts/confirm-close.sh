#!/usr/bin/env bash
# Super + Q. Asks before closing a window -- except for apps that ask by themselves.
#
# kitty already guards its own windows (confirm_os_window_close), and does it better
# than a blanket dialog can: with shell integration it only asks when a command is
# actually running, so an idle shell closes instantly. Adding this prompt on top
# means two dialogs for the one case that matters and one for every case that does
# not. Everything launched with --class= from hyprland.lua is a kitty window too,
# hence the TUI classes below.
#
#   --dry-run   print the decision without closing anything
set -uo pipefail

SELF_CONFIRMING='^(kitty|wiremix|nmtui|bluetuith)$'

dry_run=0
[ "${1:-}" = "--dry-run" ] && dry_run=1

active=$(hyprctl activewindow -j 2>/dev/null) || exit 0
class=$(echo "$active" | jq -r '.class // empty')
title=$(echo "$active" | jq -r '.title // empty')
[ -z "$class" ] && exit 0   # nothing focused

close() {
    [ "$dry_run" = 1 ] && { echo "would close $class directly"; return 0; }
    hyprctl dispatch 'hl.dsp.window.close()'
}

if [[ "$class" =~ $SELF_CONFIRMING ]]; then
    close
    exit 0
fi

if [ "$dry_run" = 1 ]; then echo "would prompt for $class: $title"; exit 0; fi

choice=$(printf "Yes\nNo" | wofi --dmenu --prompt "Close → $class: $title ?" \
    --width 420 --height 140 --lines 3 --cache-file /dev/null)
[[ "$choice" == "Yes" ]] && close
