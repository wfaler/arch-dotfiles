#!/usr/bin/env bash
# Move audio output to the external display when it has one, and back to the
# built-in card when it goes away. Called from monitors.sh, so it runs at login and
# on every display hotplug.
#
# The choice is made from PipeWire port availability, never from a remembered device
# name. PipeWire exposes one sink per GPU audio connector (HDMI1..4 on the Framework
# 13) and marks the one with a live sink "available"; which connector that is changes
# between plugs -- the same monitor came up as DP-8 and DP-7 within an hour -- so
# anything keyed to a node name eventually points at a dead connector.
#
# A sink that is neither a display output nor the built-in card (USB headset,
# Bluetooth, ...) is left alone: docking should not steal audio from headphones you
# deliberately chose.
#
# Usage:
#   audio-follow-display.sh                one pass, no waiting (manual runs)
#   audio-follow-display.sh expect-display wait up to 6s for the display sink to
#                                          appear (the ELD/jack state lags the
#                                          DRM hotplug by a moment)
#   --dry-run                              print the decision, change nothing
set -uo pipefail

expect_display=0; dry_run=0
for arg in "$@"; do
    case "$arg" in
        expect-display) expect_display=1 ;;
        --dry-run)      dry_run=1 ;;
    esac
done

# Test seam: a file holding `pactl -f json list sinks` output, used instead of the
# live server so the decision can be exercised without a monitor to plug in.
sinks_json() {
    if [ -n "${AUDIO_SINKS_JSON:-}" ]; then cat "$AUDIO_SINKS_JSON"; else pactl -f json list sinks; fi
}

JQ_DEFS='
def ports_of_type: [.ports[]? | select(.type == "HDMI" or .type == "DisplayPort")];
def is_display:    (ports_of_type | length) > 0;
def display_live:  ([ports_of_type[] | select(.availability == "available")] | length) > 0;
'

# Name of the first display sink with a live connection, if any.
live_display_sink() { sinks_json | jq -r "$JQ_DEFS"' map(select(display_live)) | .[0].name // empty'; }

# Name of the built-in card's sink (on-board analog out; absent on most desktops).
builtin_sink() {
    sinks_json | jq -r "$JQ_DEFS"'
        map(select((is_display | not) and .properties["device.bus"] == "pci"))
        | .[0].name // empty'
}

sink_is_display() { # name
    sinks_json | jq -e -r "$JQ_DEFS"' map(select(.name == $n and is_display)) | length > 0' \
        --arg n "$1" >/dev/null 2>&1
}

sink_exists() { # name
    sinks_json | jq -e --arg n "$1" 'map(select(.name == $n)) | length > 0' >/dev/null 2>&1
}

switch_to() { # name
    local target=$1 current=$2 old_index
    if [ "$dry_run" = 1 ]; then echo "audio: would switch $current -> $target"; return 0; fi
    old_index=$(sinks_json | jq -r --arg n "$current" '.[] | select(.name==$n) | .index')
    pactl set-default-sink "$target" || return 1
    # Streams that were on the old default follow; anything routed elsewhere on
    # purpose stays where it is.
    if [ -n "$old_index" ]; then
        pactl -f json list sink-inputs 2>/dev/null |
            jq -r --argjson s "$old_index" '.[] | select(.sink == $s) | .index' |
            while read -r i; do pactl move-sink-input "$i" "$target" 2>/dev/null; done
    fi
    echo "audio: $current -> $target"
}

current=$(pactl get-default-sink 2>/dev/null) || exit 0

# Only manage the two cases this script is about. Anything else is a deliberate
# choice (headset, dock audio, Bluetooth) and is left alone.
if [ -n "$current" ] && sink_exists "$current" && ! sink_is_display "$current" \
   && [ "$current" != "$(builtin_sink)" ]; then
    exit 0
fi

target=$(live_display_sink)
if [ -z "$target" ] && [ "$expect_display" = 1 ]; then
    for _ in $(seq 1 12); do
        sleep 0.5
        target=$(live_display_sink)
        [ -n "$target" ] && break
    done
fi
[ -z "$target" ] && target=$(builtin_sink)

[ -z "$target" ] && exit 0
[ "$target" = "$current" ] && exit 0
switch_to "$target" "$current"
