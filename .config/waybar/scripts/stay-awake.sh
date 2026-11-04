#!/usr/bin/env bash
# "Stay awake" toggle for the Waybar custom/stay-awake module.
#
# On: holds a systemd-logind inhibitor that blocks
#   handle-lid-switch  closing the lid does nothing (logind's HandleLidSwitch=suspend)
#   sleep              nothing suspends the machine, including hypridle's 10 min
#                      battery suspend and `systemctl suspend`
#   idle               hypridle skips its idle lock / screen-off / suspend (it honours
#                      systemd idle inhibitors)
# Off: releases it, back to the normal lid and idle behaviour.
#
# The inhibitor lives as long as the background systemd-inhibit process, so it ends
# at logout or reboot -- the machine never stays awake by accident across sessions.
#
# Closing the lid while it is on turns the laptop panel off instead (see
# ~/.config/hypr/scripts/lid.sh).
#
# Usage: stay-awake.sh toggle | on | off | status (Waybar JSON) | is-on (exit code)
set -uo pipefail

pidfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/stay-awake.pid"
SIGNAL=9   # matches "signal" of custom/stay-awake in modules.json

running() {
    local pid
    pid=$(cat "$pidfile" 2>/dev/null) || return 1
    [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = systemd-inhibit ]
}

on() {
    running && return 0
    setsid systemd-inhibit --what=handle-lid-switch:sleep:idle --mode=block \
        --who="Stay awake (Waybar)" --why="Stay-awake toggle is on" \
        sleep infinity >/dev/null 2>&1 < /dev/null &
    echo $! > "$pidfile"
}

off() {
    if running; then kill "$(cat "$pidfile")" 2>/dev/null; fi
    rm -f "$pidfile"
}

refresh() { pkill -RTMIN+"$SIGNAL" -x waybar 2>/dev/null || true; }

case "${1:-status}" in
    toggle) if running; then off; else on; fi; refresh ;;
    on)     on; refresh ;;
    off)    off; refresh ;;
    is-on)  running ;;
    status)
        if running; then
            printf '{"text":"󰅶","class":"on","tooltip":"Stay awake: ON\\nLid close, idle and sleep are blocked.\\nClick to turn off."}\n'
        else
            printf '{"text":"󰛊","class":"off","tooltip":"Stay awake: off\\nClick to keep the laptop awake with the lid closed."}\n'
        fi ;;
    *) echo "usage: $0 toggle|on|off|status" >&2; exit 2 ;;
esac
