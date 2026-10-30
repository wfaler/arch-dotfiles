#!/usr/bin/env bash
# Record how each external display link came up, so sessions where a monitor
# blinks can be compared with sessions where it does not. The LG 38WN95C blinks
# off/on (as if replugged) every ~15 min in some sessions and never in others,
# with nothing at all in the kernel or Hyprland logs -- so the difference has to
# be in something negotiated at connect time and fixed for the session.
#
# Called (backgrounded) by monitors.sh on startup and every hotplug. Appends to
# ~/.local/state/hypr/link-snapshots.log, trimmed to the last MAX_LINES.
#
# Usage:
#   link-snapshot.sh          take a snapshot (after a short settle delay)
#   link-snapshot.sh blink    mark "a blink just happened" in the log
#   link-snapshot.sh now      take a snapshot without the settle delay
set -uo pipefail

MAX_LINES=5000
dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
log="$dir/link-snapshots.log"
mkdir -p "$dir"

trim() {
    local n
    n=$(wc -l < "$log")
    if [ "$n" -gt "$MAX_LINES" ]; then
        tail -n "$MAX_LINES" "$log" > "$log.tmp" && mv -f "$log.tmp" "$log"
    fi
}

if [ "${1:-}" = blink ]; then
    echo "$(date -Is) BLINK" >> "$log"
    echo "Blink marked in $log"
    exit 0
fi

# Link training and Thunderbolt tunnel setup finish a moment after the hotplug.
[ "${1:-}" = now ] || sleep 5

snapshot() {
    echo "=== $(date -Is) snapshot (host $(uname -n), uptime $(awk '{printf "%dm", $1/60}' /proc/uptime)) ==="

    # How this connection started: a fresh boot, or a resume shortly before.
    local resume
    resume=$(journalctl -k -b -o short-iso --no-pager -g 'PM: suspend exit' 2>/dev/null | grep -E '^[0-9]' | tail -1 | cut -d' ' -f1)
    echo "last resume this boot: ${resume:-none}"

    echo "-- monitors"
    hyprctl -j monitors 2>/dev/null | jq -r '.[] |
        "\(.name): \(.description) \(.width)x\(.height)@\(.refreshRate | . * 100 | round / 100) vrr=\(.vrr)"'

    echo "-- thunderbolt"
    boltctl list 2>/dev/null | grep -E '^\s*\*|generation|rx speed|tx speed|connected:' | sed -E 's/^[ |`-]*/  /'

    echo "-- usb-c ports with a partner (active role in [])"
    local p
    for p in /sys/class/typec/port[0-9]; do
        [ -e "$p-partner" ] || continue
        echo "  ${p##*/}: power=$(cat "$p/power_role" 2>/dev/null) data=$(cat "$p/data_role" 2>/dev/null)"
    done

    echo "-- power"
    for p in /sys/class/power_supply/ucsi-source-psy-*; do
        [ "$(cat "$p/online" 2>/dev/null)" = 1 ] || continue
        awk -v n="${p##*/}" -v v="$(cat "$p/voltage_now")" -v i="$(cat "$p/current_max")" \
            'BEGIN { printf "  %s: %.0fV x %.2fA = %.0fW offered\n", n, v/1e6, i/1e6, v*i/1e12 }'
    done
    for p in /sys/class/power_supply/BAT*; do
        [ -e "$p" ] && echo "  ${p##*/}: $(cat "$p/capacity")% $(cat "$p/status")"
    done

    echo "-- dp link (amdgpu debugfs)"
    if [ -x /usr/local/bin/dp-link-state ] && sudo -n /usr/local/bin/dp-link-state 2>/dev/null; then :; else
        echo "  unavailable (install.sh deploys /usr/local/bin/dp-link-state and its sudoers rule)"
    fi
}

snapshot >> "$log" 2>&1
trim
