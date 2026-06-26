#!/usr/bin/env bash
# Dynamic monitor layout for Framework 13 (+ desktop, + external displays).
# Runs once at startup and again on every hotplug (see monitor-watch.sh).
#
#   external 3840x1600 (ultrawide) -> drive at native res, laptop panel OFF
#   external 3840x2160 (4K)        -> drive at native res, laptop panel OFF
#   no external, or unknown-res external -> laptop panel ON (extend the unknown one)
#
# All eDP operations are no-ops on the desktop, which has no internal panel.
set -euo pipefail

SCALE_EDP=1.5   # Framework 13 2256x1504 panel (adjust to taste: 1.333 / 1.6 ...)
SCALE_UW=1      # 3840x1600 ultrawide
SCALE_4K=1      # 3840x2160 4K -- bump to 1.5 or 2 if the UI is too small

mons=$(hyprctl monitors all -j)

# Internal panel name (eDP*); empty string on the desktop.
edp=$(echo "$mons" | jq -r '[.[] | select(.name|startswith("eDP")) | .name] | first // empty')

# Walk external monitors; pick the first that *advertises* a known resolution
# (we read availableModes, so the right mode is forced even if the EDID-preferred
# mode was something lower -- "resolution resolved").
chosen_name=""; chosen_mode=""; chosen_scale=""
externals=$(echo "$mons" | jq -r '.[] | select(.name|startswith("eDP")|not) | .name')
while read -r name; do
    [ -z "$name" ] && continue
    modes=$(echo "$mons" | jq -r --arg n "$name" '.[] | select(.name==$n) | .availableModes[]')
    uw=$(echo "$modes" | grep -E '^3840x1600@' | sort -t@ -k2 -gr | head -1)
    k4=$(echo "$modes" | grep -E '^3840x2160@' | sort -t@ -k2 -gr | head -1)
    if   [ -n "$uw" ]; then chosen_name=$name; chosen_mode=$uw; chosen_scale=$SCALE_UW; break
    elif [ -n "$k4" ]; then chosen_name=$name; chosen_mode=$k4; chosen_scale=$SCALE_4K; break
    fi
done <<< "$externals"

if [ -n "$chosen_name" ]; then
    echo "monitors: driving $chosen_name at $chosen_mode (scale $chosen_scale); laptop panel off"
    hyprctl keyword monitor "$chosen_name,$chosen_mode,0x0,$chosen_scale"
    [ -n "$edp" ] && hyprctl keyword monitor "$edp,disable"
else
    echo "monitors: no known external; laptop panel on"
    [ -n "$edp" ] && hyprctl keyword monitor "$edp,preferred,auto,$SCALE_EDP"
fi
