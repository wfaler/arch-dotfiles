#!/usr/bin/env bash
# Lid switch handler, bound in hyprland.lua. Only acts while logind is told to ignore
# the lid -- the Waybar stay-awake toggle, or lid-hold.sh (docked + powered) -- so
# that nothing lights the panel under the closed lid. Otherwise logind suspends on
# close as usual and this does nothing.
#
# Closing the lid with no external display connected also locks the session.
#
# The panel is disabled, not DPMS'd off: mouse_move/key_press_enables_dpms would
# light it again on the first touch of an external mouse or keyboard.
#
# The flag file tells monitors.sh not to re-enable the panel on a hotplug while the
# lid is shut (e.g. unplugging the external monitor with the lid closed).
#
# Usage: lid.sh close | open
set -uo pipefail

flag="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lid-panel-off"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

edp=$(hyprctl monitors all -j | jq -r '[.[] | select(.name|startswith("eDP")) | .name] | first // empty')
[ -z "$edp" ] && exit 0

case "${1:-}" in
    close)
        ~/.config/waybar/scripts/stay-awake.sh is-on || "$here/lid-hold.sh" is-on || exit 0
        # Nothing suspends now, so nothing would lock either: the stay-awake toggle
        # also holds off hypridle's auto-lock. Without an external display (lid shut =
        # nobody is using it, e.g. in a bag) lock now. Docked clamshell use stays
        # unlocked.
        "$here/lid-hold.sh" external || loginctl lock-session
        touch "$flag"
        hyprctl eval "hl.monitor({ output = \"$edp\", disabled = true })" >/dev/null
        ;;
    open)
        [ -e "$flag" ] || exit 0
        rm -f "$flag"
        # monitors.sh decides: panel back on unless a known external is driving.
        "$here/monitors.sh"
        ;;
    *) echo "usage: $0 close|open" >&2; exit 2 ;;
esac
