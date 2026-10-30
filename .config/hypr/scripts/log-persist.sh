#!/usr/bin/env bash
# Copy Hyprland's log to disk as it is written, size-capped, so it survives a
# reboot. Hyprland only logs to $XDG_RUNTIME_DIR (RAM), which a forced reboot
# wipes -- exactly when the log is needed (e.g. a black panel after unplugging
# an external display). Started from hyprland.start in hyprland.lua.
#
# ~/.local/state/hypr/hyprland.log rotates to hyprland.log.1 at MAX_BYTES, so
# disk use stays under 2 x MAX_BYTES and always holds the most recent lines.
# Each line is appended as it arrives, so a hard power-off loses only what the
# filesystem had not committed yet (seconds), not minutes.
#
# Per-event input and cursor debug lines are dropped: they are nearly all of the
# volume and filled MAX_BYTES in about 15 minutes, pushing out everything useful.
set -uo pipefail

MAX_BYTES=$((5 * 1024 * 1024))

src="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
dst="$dir/hyprland.log"
mkdir -p "$dir"

bytes=$(stat -c %s "$dst" 2>/dev/null || echo 0)

rotate() {
    mv -f "$dst" "$dst.1"
    bytes=0
}

append() { # line
    printf '%s\n' "$1" >> "$dst"
    bytes=$((bytes + ${#1} + 1))
    if [ "$bytes" -ge "$MAX_BYTES" ]; then rotate; fi
}

append "=== Hyprland session $HYPRLAND_INSTANCE_SIGNATURE started $(date -Is) ==="

# --pid: stop when this Hyprland exits, so a new session starts a fresh follower.
# -n +1 -F: copy the log from its first line, and wait for it if not created yet.
tail --pid="$PPID" -n +1 -F "$src" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"[libinput]"*|*"Cursor buffer imported"*) continue ;;
    esac
    append "$line"
done
