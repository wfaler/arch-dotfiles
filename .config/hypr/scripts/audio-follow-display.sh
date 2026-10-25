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

# Monitors that advertise an audio sink but have no speakers, matched against the
# sink's alsa.name (the monitor name from its ELD, e.g. "DELL G3223Q"). Their sink
# is never chosen, so audio stays on the built-in card while they are attached.
NO_AUDIO_MONITORS='["DELL G3223Q"]'

# Monitors with speakers that are offered but never switched to automatically: their
# sink is made available (see ensure_speaker_profile) for picking by hand in the
# sound settings, and once picked it is left alone like a headset would be.
MANUAL_AUDIO_MONITORS='["LG HDR 4K"]'

cards_json() {
    if [ -n "${AUDIO_CARDS_JSON:-}" ]; then cat "$AUDIO_CARDS_JSON"; else pactl -f json list cards 2>/dev/null; fi
}

# "card/port" -> monitor name, from the card ports' device.product.name (the ELD
# monitor name). The sink's own alsa.name cannot be trusted for this: the Dell's sink
# carried "DELL G3223Q", but the LG's came up as plain "HDMI 3" after a profile switch.
monitor_names=$(cards_json | jq -c '
    [ .[] | .name as $c | .ports | to_entries[]
      | select(.value.properties["device.product.name"])
      | { key: "\($c)/\(.key)", value: .value.properties["device.product.name"] } ]
    | from_entries' 2>/dev/null)
[ -z "$monitor_names" ] && monitor_names='{}'

jq_lists=(--argjson no_audio "$NO_AUDIO_MONITORS" --argjson manual "$MANUAL_AUDIO_MONITORS"
          --argjson names "$monitor_names")

JQ_DEFS='
def ports_of_type: [.ports[]? | select(.type == "HDMI" or .type == "DisplayPort")];
def is_display:    (ports_of_type | length) > 0;
def monitor_name:  $names["\(.properties["device.name"] // "")/\(.active_port // .ports[0].name // "")"]
                   // .properties["alsa.name"] // "";
def in_list($l):   monitor_name as $m | $l | index([$m]) != null;
def display_live:  ([ports_of_type[] | select(.availability == "available")] | length) > 0;
def auto_target:   display_live and (in_list($no_audio) | not) and (in_list($manual) | not);
'

# Name of the first display sink with a live connection that audio may follow.
live_display_sink() {
    sinks_json | jq -r "${jq_lists[@]}" "$JQ_DEFS"' map(select(auto_target)) | .[0].name // empty'
}

# Name of the built-in card's sink (on-board analog out; absent on most desktops).
builtin_sink() {
    sinks_json | jq -r "${jq_lists[@]}" "$JQ_DEFS"'
        map(select((is_display | not) and .properties["device.bus"] == "pci"))
        | .[0].name // empty'
}

sink_is_display() { # name
    sinks_json | jq -e -r "${jq_lists[@]}" "$JQ_DEFS"' map(select(.name == $n and is_display)) | length > 0' \
        --arg n "$1" >/dev/null 2>&1
}

# A live sink of a MANUAL_AUDIO_MONITORS monitor: only there because it was picked.
sink_is_manual_choice() { # name
    sinks_json | jq -e -r "${jq_lists[@]}" "$JQ_DEFS"'
        map(select(.name == $n and display_live and in_list($manual))) | length > 0' \
        --arg n "$1" >/dev/null 2>&1
}

# The GPU's audio device plays to ONE display connector at a time, chosen by its
# card profile, so a monitor with speakers is not even offered while the profile
# points at another (e.g. the speakerless Dell). Point the profile at a connected
# monitor that has speakers when the current one does not. Leaves the card alone
# when no connected monitor has speakers, or the active port already does.
ensure_speaker_profile() {
    local card profile
    pactl -f json list cards 2>/dev/null | jq -r --argjson no_audio "$NO_AUDIO_MONITORS" '
        .[] | . as $c
        | [ .ports | to_entries[] | .value
            | select((.type == "HDMI" or .type == "DisplayPort") and .availability == "available")
            | select((.properties["device.product.name"] // "") as $m | $no_audio | index([$m]) == null) ]
        | select(length > 0)
        | select(map(.profiles | index([$c.active_profile]) != null) | any | not)
        | "\($c.name) \(.[0].profiles | map(select(test("stereo"))) | first // .[0].profiles[0])"' |
    while read -r card profile; do
        if [ "$dry_run" = 1 ]; then echo "audio: would set $card profile -> $profile"; continue; fi
        pactl set-card-profile "$card" "$profile" && echo "audio: $card profile -> $profile"
    done
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

[ -z "${AUDIO_SINKS_JSON:-}" ] && ensure_speaker_profile

current=$(pactl get-default-sink 2>/dev/null) || exit 0

# Only manage the two cases this script is about. Anything else is a deliberate
# choice (headset, dock audio, Bluetooth, a MANUAL_AUDIO_MONITORS monitor picked by
# hand) and is left alone.
if [ -n "$current" ] && sink_exists "$current" && ! sink_is_display "$current" \
   && [ "$current" != "$(builtin_sink)" ]; then
    exit 0
fi
sink_is_manual_choice "$current" && exit 0

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
