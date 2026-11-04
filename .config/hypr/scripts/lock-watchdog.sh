#!/usr/bin/env bash
# Relaunch hyprlock when it dies while the session is still locked.
#
# hyprlock aborts when Hyprland recreates outputs (hyprwm/hyprlock#1064): on resume,
# but also on a monitor hotplug while locked, e.g. the LG reconnecting (2026-11-02
# 23:04, 00:05, 08:15, no sleep involved). Hyprland then keeps the session locked
# behind its "lockscreen app died" screen, with only a TTY or a reboot as a way out.
#
# This never unlocks anything. The session stays locked throughout; the new hyprlock
# takes over the existing lock (misc.allow_session_lock_restore in hyprland.lua) and
# asks for the password or fingerprint as usual. A renderer reload then clears the
# crash screen, which can otherwise stay frozen on top (hyprwm/hyprlock#1082).
#
# Started from hyprland.start in hyprland.lua; one per Hyprland instance.
set -uo pipefail

sig=${HYPRLAND_INSTANCE_SIGNATURE:?not inside Hyprland}
exec 9> "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lock-watchdog-$sig.lock"
flock -n 9 || exit 0

h() { hyprctl --instance "$sig" "$@"; }
# Sleep without inheriting the lock fd, so a restarted watchdog is not locked out
# by a leftover sleep of the old one.
nap() { sleep "$1" 9>&-; }

# Watch the compositor's pid, not hyprctl: IPC briefly fails during a config reload.
hpid=$(hyprctl instances -j 2>/dev/null | jq -r --arg s "$sig" '.[] | select(.instance == $s) | .pid')
[ -n "$hpid" ] || exit 1

locked() { [ "$(h locked 2>/dev/null)" = true ]; }

lock_running() {
    local p
    for p in $(pidof hyprlock); do
        tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null |
            grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$sig" && return 0
    done
    return 1
}

# Crash-loop guard: a hyprlock that dies on every start (broken config, PAM fault)
# would otherwise be relaunched every ~9 s forever, each with a ~3 MB coredump.
# After MAX_RELAUNCHES within WINDOW seconds, stop until the session is unlocked
# (from a TTY: restore-lock.sh). The session stays locked meanwhile.
MAX_RELAUNCHES=5
WINDOW=600
relaunches=()
gave_up=0

while nap 3; do
    # Hyprland gone (logout): stop.
    kill -0 "$hpid" 2>/dev/null || exit 0
    # Cheapest first: unlocked (nearly always) costs one hyprctl call, ~4 ms.
    if ! locked; then
        gave_up=0
        continue
    fi
    lock_running && continue
    [ "$gave_up" = 1 ] && continue
    # A normal unlock clears "locked" before hyprlock exits; re-check after a pause
    # so a lock that is just starting or ending is never doubled.
    nap 2
    lock_running && continue
    locked || continue

    now=$(date +%s)
    recent=()
    for t in "${relaunches[@]}"; do [ $((now - t)) -lt "$WINDOW" ] && recent+=("$t"); done
    relaunches=("${recent[@]}")
    if [ "${#relaunches[@]}" -ge "$MAX_RELAUNCHES" ]; then
        logger -t hyprlock-restore -p user.err \
            "hyprlock died $MAX_RELAUNCHES times in ${WINDOW}s; giving up until unlocked (TTY: restore-lock.sh)"
        gave_up=1
        continue
    fi
    relaunches+=("$now")

    logger -t hyprlock-restore "hyprlock gone while locked; relaunching"
    h dispatch 'hl.dsp.exec_cmd("/usr/bin/hyprlock")' >/dev/null
    nap 2
    h dispatch 'hl.dsp.force_renderer_reload()' >/dev/null
    # Give it time to take the lock before checking again.
    nap 5
done
