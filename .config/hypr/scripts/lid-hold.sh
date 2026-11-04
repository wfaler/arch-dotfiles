#!/usr/bin/env bash
# Keep the laptop awake with the lid closed while it is docked AND powered.
#
# logind's own "docked" test (HandleLidSwitchDocked=ignore) is not enough: it only
# counts an external display that is connected *and enabled*, and Hyprland disables
# the output when hypridle turns the screen off. So 30 s after the lock, with the lid
# closed, logind saw "undocked" and suspended under a connected monitor (2026-11-02,
# reproduced). The resume then rebuilt the outputs and crashed hyprlock 0.9.7.
#
# Instead this holds a handle-lid-switch inhibitor whenever
#   - any external display is physically connected (DRM status, which screen-off does
#     not change), and
#   - AC power is online (a USB-C monitor's power counts).
# Lose either and the hold is released; with the lid already closed logind then
# applies the normal rule and suspends. The Waybar stay-awake toggle is separate and
# overrides all of this.
#
# Usage:
#   lid-hold.sh watch    run forever, re-checking on every display/power uevent
#                        (started from hyprland.start in hyprland.lua)
#   lid-hold.sh check    re-check once
#   lid-hold.sh is-on    exit 0 while the hold is active
#   lid-hold.sh external exit 0 while an external display is physically connected
set -uo pipefail

pidfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lid-hold.pid"
RELEASE_GRACE=10   # seconds the condition must stay false before the hold is released

held() {
    local pid
    pid=$(cat "$pidfile" 2>/dev/null) || return 1
    [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = systemd-inhibit ]
}

external_connected() {
    local c
    for c in /sys/class/drm/card*-*; do
        case "${c##*/}" in *-eDP-*|*-LVDS-*|*-Writeback-*) continue ;; esac
        [ "$(cat "$c/status" 2>/dev/null)" = connected ] && return 0
    done
    return 1
}

on_ac() {
    local s
    for s in /sys/class/power_supply/*; do
        [ "$(cat "$s/type" 2>/dev/null)" = Mains ] || continue
        [ "$(cat "$s/online" 2>/dev/null)" = 1 ] && return 0
    done
    return 1
}

check() {
    if external_connected && on_ac; then
        held && return 0
        setsid systemd-inhibit --what=handle-lid-switch --mode=block \
            --who="Lid hold (docked + powered)" --why="External display and AC power" \
            sleep infinity >/dev/null 2>&1 < /dev/null &
        echo $! > "$pidfile"
        echo "lid-hold: on"
    elif held; then
        # Release only if it stays false: a monitor waking from standby re-announces
        # itself (HPD) and can read as disconnected for a moment, and with the lid shut
        # logind suspends within milliseconds of the release (2026-11-02 19:27).
        sleep "$RELEASE_GRACE"
        if external_connected && on_ac; then return 0; fi
        kill "$(cat "$pidfile")" 2>/dev/null
        rm -f "$pidfile"
        echo "lid-hold: off"
    fi
}

case "${1:-check}" in
    check) check ;;
    is-on) held ;;
    external) external_connected ;;
    watch)
        # One watcher per session; a reload must not start a second.
        exec 9> "${pidfile%.pid}.lock"
        flock -n 9 || exit 0
        trap 'held && kill "$(cat "$pidfile")" 2>/dev/null; rm -f "$pidfile"' EXIT
        check
        udevadm monitor --udev --subsystem-match=drm --subsystem-match=power_supply 2>/dev/null |
            while read -r line; do
                case "$line" in UDEV*) check ;; esac
            done
        ;;
    *) echo "usage: $0 watch|check|is-on|external" >&2; exit 2 ;;
esac
