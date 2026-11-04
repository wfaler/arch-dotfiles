#!/usr/bin/env bash
# Recover a Hyprland session whose lock screen crashed, from a text console.
#
# When hyprlock dies, Hyprland keeps the session locked and shows its
# "lockscreen crashed" screen; nothing typed there reaches your apps, and the only way
# back in is a new lock screen. This starts one inside the stuck session, so you
# unlock it normally (password or fingerprint) and keep all your windows -- no
# reboot, no new Hyprland.
#
#   1. Ctrl+Alt+F3 (or F4...), log in on the text console.
#   2. ~/.config/hypr/scripts/restore-lock.sh
#   3. Switch back with the Ctrl+Alt+F<n> it prints, and unlock.
#
# It also restarts hypridle in that session if it is missing (no hypridle = no
# auto-lock and no lock before sleep).
#
# Usage: restore-lock.sh [instance-signature]   (default: the only/newest instance)
set -uo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

instances=$(hyprctl instances -j 2>/dev/null) || { echo "No running Hyprland found." >&2; exit 1; }
if [ -n "${1:-}" ]; then
    sig=$1
else
    count=$(echo "$instances" | jq length)
    [ "$count" -eq 0 ] && { echo "No running Hyprland found." >&2; exit 1; }
    [ "$count" -gt 1 ] && echo "Several Hyprland sessions are running; using the newest. Pass a signature to choose:" &&
        echo "$instances" | jq -r '.[] | "  \(.instance)  (pid \(.pid))"'
    sig=$(echo "$instances" | jq -r 'sort_by(.time) | last | .instance')
fi
pid=$(echo "$instances" | jq -r --arg s "$sig" '.[] | select(.instance == $s) | .pid')
[ -z "$pid" ] && { echo "No Hyprland instance $sig." >&2; exit 1; }
h() { hyprctl --instance "$sig" "$@"; }

# A new locker may only take over a crashed lock with this on (it is in hyprland.lua;
# set it again in case that session runs an older config).
h eval 'hl.config({ misc = { allow_session_lock_restore = true } })' >/dev/null

# A hyprlock that still runs but is hung would keep the new one from starting.
for p in $(pgrep -x hyprlock); do
    if tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$sig"; then
        echo "Stopping the old hyprlock (pid $p)."
        kill "$p"; sleep 1
    fi
done
h dispatch 'hl.dsp.exec_cmd("/usr/bin/hyprlock")' >/dev/null && echo "Started a new lock screen."

# The crash screen can stay frozen on top of the new lock screen, which then takes
# input unseen (hyprwm/hyprlock#1082). A renderer reload repaints the real one.
sleep 2
h dispatch 'hl.dsp.force_renderer_reload()' >/dev/null

has_idle=0
for p in $(pgrep -x hypridle); do
    tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$sig" && has_idle=1
done
if [ "$has_idle" = 0 ]; then
    h dispatch 'hl.dsp.exec_cmd("hypridle")' >/dev/null && echo "hypridle was not running there; started it."
fi

vt=$(loginctl show-session "$(cat "/proc/$pid/sessionid" 2>/dev/null)" -p VTNr --value 2>/dev/null)
echo "Now switch back with Ctrl+Alt+F${vt:-1/F2} and unlock."
