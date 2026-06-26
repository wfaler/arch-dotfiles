#!/usr/bin/env bash
# Listen to Hyprland's event socket and re-run the monitor layout on every
# display hotplug. Started via exec-once in hyprland.conf.
set -euo pipefail

if ! command -v socat >/dev/null 2>&1; then
    echo "monitor-watch: socat not installed; hotplug re-layout disabled" >&2
    exit 0
fi

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

socat -u "UNIX-CONNECT:$sock" - | while read -r line; do
    case "$line" in
        monitoradded\>\>*|monitoraddedv2\>\>*|monitorremoved\>\>*|monitorremovedv2\>\>*)
            "$here/monitors.sh" ;;
    esac
done
