#!/usr/bin/env bash
# Dynamic monitor layout for Framework 13 (+ desktop, + external displays).
# Runs once at startup and again on every hotplug (see monitor-watch.sh).
#
#   external 3840x1600 (ultrawide) -> drive at native res, laptop panel OFF
#   external 3840x2160 (4K)        -> drive at native res, laptop panel OFF
#   no external, or unknown-res external -> laptop panel ON (extend the unknown one)
#
# Every monitor is driven at its native resolution and the HIGHEST refresh rate
# that resolution advertises. eDP operations are no-ops on the desktop.
set -uo pipefail

SCALE_EDP=1.5   # Framework 13 2256x1504 panel (adjust to taste: 1.333 / 1.6 ...)
SCALE_UW=1      # 3840x1600 ultrawide
SCALE_4K=1      # 3840x2160 4K -- bump to 1.5 or 2 if the UI is too small

mons=$(hyprctl monitors all -j)

# Modes ("WxH@Hz") advertised by monitor $1.
modes_of() { echo "$mons" | jq -r --arg n "$1" '.[] | select(.name==$n) | .availableModes[]'; }

# Highest-refresh mode of monitor $1 at resolution $2 (e.g. 3840x1600); empty if none.
best_at() { modes_of "$1" | grep -E "^${2}@" | sort -t@ -k2 -gr | head -1 || true; }

# Native (largest) resolution "WxH" of monitor $1.
native_res() { modes_of "$1" | sed -E 's/@.*//' | sort -tx -k1,1n -k2,2n | tail -1 || true; }

# Best mode of monitor $1 at its native resolution, falling back to "preferred".
native_mode() {
    local res mode
    res=$(native_res "$1")
    mode=$(best_at "$1" "$res")
    echo "${mode:-preferred}"
}

# Internal panel name (eDP*); empty string on the desktop.
edp=$(echo "$mons" | jq -r '[.[] | select(.name|startswith("eDP")) | .name] | first // empty')

# Walk external monitors; pick the first that advertises a known resolution
# (we read availableModes, so the right mode is forced even if the EDID-preferred
# mode was something lower -- "resolution resolved").
chosen_name=""; chosen_mode=""; chosen_scale=""
externals=$(echo "$mons" | jq -r '.[] | select(.name|startswith("eDP")|not) | .name')
while read -r name; do
    [ -z "$name" ] && continue
    uw=$(best_at "$name" 3840x1600)
    k4=$(best_at "$name" 3840x2160)
    if   [ -n "$uw" ]; then chosen_name=$name; chosen_mode=$uw; chosen_scale=$SCALE_UW; break
    elif [ -n "$k4" ]; then chosen_name=$name; chosen_mode=$k4; chosen_scale=$SCALE_4K; break
    fi
done <<< "$externals"

if [ -n "$chosen_name" ]; then
    echo "monitors: driving $chosen_name at $chosen_mode (scale $chosen_scale); laptop panel off"
    hyprctl keyword monitor "$chosen_name,$chosen_mode,0x0,$chosen_scale"
    if [ -n "$edp" ]; then hyprctl keyword monitor "$edp,disable"; fi
else
    echo "monitors: no known external; laptop panel on"
    if [ -n "$edp" ]; then
        hyprctl keyword monitor "$edp,$(native_mode "$edp"),auto,$SCALE_EDP"
    fi
    # Drive any unknown external at its native resolution + highest refresh too.
    while read -r name; do
        [ -z "$name" ] && continue
        hyprctl keyword monitor "$name,$(native_mode "$name"),auto,1"
    done <<< "$externals"
fi
