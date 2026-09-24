#!/usr/bin/env bash
# Dynamic monitor layout for Framework 13 (+ desktop, + external displays).
# Runs once at startup and again on every hotplug (see monitor-watch.sh).
#
#   external 3840x1600 (ultrawide) -> drive it, laptop panel OFF
#   external 3840x2160 (4K)        -> drive it, laptop panel OFF
#   no external, or unknown-res external -> laptop panel ON (extend the unknown one)
#
# Refresh rate policy: every monitor runs at the mode it asks for (its EDID
# preferred mode), unless STABLE_MODE below says otherwise. Do NOT go back to
# picking the highest advertised refresh -- see the comment on STABLE_MODE.
#
# Usage:
#   monitors.sh                     apply the layout (default; called on hotplug)
#   monitors.sh --list              show each monitor's description and modes
#   monitors.sh --try NAME MODE [S] apply MODE to NAME for S seconds (default 20),
#                                   then revert unless confirmed
set -uo pipefail

# Framework 13 2.8k panel (2880x1920) -> 1800x1200 logical at 1.6.
# Hyprland only accepts scales that divide the panel into whole pixels:
# 1.25 (2304x1536), 1.6 (1800x1200) and 2 (1440x960) are the useful alternatives.
# (KWin remembers 1.7 for this panel; that one is not representable here.)
SCALE_EDP=1.6
SCALE_UW=1      # 3840x1600 ultrawide
SCALE_4K=1      # 3840x2160 4K -- bump to 1.5 or 2 if the UI is too small

# This machine, for the host-scoped table keys below. MONITORS_HOST overrides it,
# which is the only way to test another machine's entries from here.
THIS_HOST=${MONITORS_HOST:-$(uname -n)}

# Refresh rates verified STABLE, keyed by a substring of the monitor description
# (run `monitors.sh --list` to see the descriptions), optionally scoped to one
# machine as "hostname:substring". A monitor with no entry here runs at its EDID
# preferred mode, which is the conservative, always-safe choice.
#
# These are empirical and cannot be derived. A mode that is advertised, lights up
# and looks perfect can still drop the DP link every few minutes; nothing detects
# that but you, over hours. Raise a rate with `--try`, live with it for a day, then
# record it here.
#
# The stable rate belongs to the monitor AND its cable AND its port, not to the
# monitor alone -- a USB-C display shares one link between pixels, its USB hub and
# power. That is why entries are host-scoped: this repo follows the same monitor
# onto machines that drive it over plain DisplayPort, where none of that contention
# exists and the cap would be pure loss. An unscoped key still matches every host.
declare -A STABLE_MODE=(
    # LG 38WN95C over USB-C/Thunderbolt on the Framework 13. The link negotiates
    # 20 Gb/s (2 lanes x 10), leaving DP 4 lanes of HBR2 = 17.3 Gb/s of payload,
    # shared with the monitor's USB hub and power.
    #
    # 144 needs ~23.4 Gb/s before compression: it lights up, then leans hard on DSC
    # and retrains every few minutes, blanking the screen. 120 (the panel's own
    # preferred mode) still needs DSC and produced intermittent single-frame
    # flashes -- no DP link drop, no HPD, nothing in the kernel log at all, which is
    # exactly what a DSC hiccup looks like from the source side.
    #
    # 75 is the fastest mode that needs no compression whatsoever. That is the trade
    # taken here: this machine is not used for anything that needs high refresh.
    ["framework13:LG HDR WQHD+"]="3840x1600@74.98"

    # The same panel on the Nvidia desktop over native DisplayPort: no Thunderbolt
    # tunnel, no shared USB hub, so DP 1.4 (4 lanes x 8.1 = ~25.9 Gb/s of payload)
    # carries 144 (~23.4 Gb/s) without compression. An entry is needed because the
    # panel's EDID asks for 120 and nothing here raises a monitor above what it asks
    # for on its own.
    #
    # Not yet verified on that machine -- `--try DP-x 3840x1600@144`, live with it a
    # day, drop to 119.98 if it blinks. If the hostname is wrong the entry is simply
    # inert (check with `uname -n`) and the panel falls back to its preferred 120.
    ["raptor:LG HDR WQHD+"]="3840x1600@144"
)

# Per-monitor scale overrides, same key format. Falls back to the SCALE_* defaults.
declare -A STABLE_SCALE=()

# The value in table $1 whose key matches monitor description $2 on this host.
# A "host:substring" key only matches on that host and wins over a bare "substring"
# key, so a machine-specific entry can override a shared one. Returns 1 if nothing
# matches, so callers can tell "no entry" from "entry that happens to be empty".
table_lookup() { # table-name desc
    local -n tbl=$1
    local desc=$2 key host pat generic="" found=""
    for key in "${!tbl[@]}"; do
        host=""; pat=$key
        case "$key" in *:*) host=${key%%:*}; pat=${key#*:} ;; esac
        case "$desc" in *"$pat"*)
            if [ -n "$host" ]; then
                [ "$host" = "$THIS_HOST" ] && { echo "${tbl[$key]}"; return 0; }
            else
                generic=${tbl[$key]}; found=1
            fi ;;
        esac
    done
    [ -n "$found" ] && { echo "$generic"; return 0; }
    return 1
}

mons=$(hyprctl monitors all -j)

# Apply a monitor rule. A lua config only takes `hyprctl eval`, which prints "ok" on
# success; `hyprctl keyword` is not a fallback, it refuses outright with "can't work
# with non-legacy parsers", so a failure here is real and gets printed.
apply_rule() { # name lua-fields
    local out
    out=$(hyprctl eval "hl.monitor({ output = \"$1\", $2 })" 2>&1)
    [ "$out" = "ok" ] || echo "monitors: $1: $out" >&2
}

set_monitor() { # name mode position scale
    apply_rule "$1" "mode = \"$2\", position = \"$3\", scale = $4"
}

disable_monitor() { # name
    apply_rule "$1" "disabled = true"
}

# Undo a previous disable_monitor(). There is no direct way to: hl.monitor() merges
# rules per output and ignores `disabled = false` (verified on 0.56.2), so applying a
# mode/position/scale to a disabled output leaves it dark -- which is why unplugging
# an external used to leave the laptop panel black until the next login. `hyprctl
# reload` re-runs hyprland.lua, which drops the runtime rules and lights up every
# connected output; the caller then re-applies the layout it wants on top.
enable_monitor() { # name
    [ "$(echo "$mons" | jq -r --arg n "$1" '.[] | select(.name==$n) | .disabled')" = "true" ] || return 0
    echo "monitors: $1 was disabled; reloading config to re-enable it"
    hyprctl reload >/dev/null 2>&1
    mons=$(hyprctl monitors all -j)   # rules, and a disabled panel's mode list, changed
}

# Description (make + model + serial) of monitor $1.
desc_of() { echo "$mons" | jq -r --arg n "$1" '.[] | select(.name==$n) | .description'; }

# Modes ("WxH@Hz") advertised by monitor $1, preferred mode first -- the kernel
# reports DRM modes in that order and Hyprland passes it through, which is how we
# get at the EDID preferred mode without parsing EDID.
modes_of() { echo "$mons" | jq -r --arg n "$1" '.[] | select(.name==$n) | .availableModes[]' | sed 's/Hz$//'; }

preferred_mode() { modes_of "$1" | head -1; }

# The mode advertised by monitor $1 that matches $2 ("WxH@Hz"), printed in its
# canonical form, or empty if there is none. Refresh matching is deliberately
# tolerant -- "3840x1600@144", "@144.00" and "@144.00Hz" all resolve to the same
# mode -- so a hand-written STABLE_MODE entry does not silently miss by a decimal.
resolve_mode() { # name want
    local want=${2%Hz}
    modes_of "$1" | awk -F'[x@]' -v res="${want%@*}" -v hz="${want#*@}" \
        '$1"x"$2 == res && ($3 - hz < 0.5 && hz - $3 < 0.5) { print; exit }'
}

res_of()     { echo "${1%@*}"; }
refresh_of() { echo "${1#*@}"; }

# Native (largest) resolution "WxH" of monitor $1.
native_res() { modes_of "$1" | sed -E 's/@.*//' | sort -tx -k1,1n -k2,2n | tail -1 || true; }

# Highest mode of monitor $1 at resolution $2 whose refresh does not exceed $3.
# The cap is the point: it lifts a monitor whose preferred mode is not its native
# resolution up to native, without silently overclocking it past what it asked for.
best_at_capped() { # name res max_hz
    modes_of "$1" | grep -E "^${2}@" |
        awk -F@ -v max="$3" '$2 <= max + 0.5' |
        sort -t@ -k2 -gr | head -1 || true
}

# The mode to actually drive monitor $1 at.
policy_mode() { # name
    local name=$1 desc key want canon pref nat best
    desc=$(desc_of "$name")

    if want=$(table_lookup STABLE_MODE "$desc"); then
        canon=$(resolve_mode "$name" "$want")
        if [ -n "$canon" ]; then echo "$canon"; return; fi
        # A different monitor matched the key, or the entry has a typo. Either
        # way, refuse to force a mode the hardware never offered.
        echo "monitors: $name [$desc] does not advertise $want; using preferred" >&2
    fi

    pref=$(preferred_mode "$name")
    [ -z "$pref" ] && { echo preferred; return; }

    # Preferred mode is already native: nothing to decide.
    nat=$(native_res "$name")
    [ "$(res_of "$pref")" = "$nat" ] && { echo "$pref"; return; }

    best=$(best_at_capped "$name" "$nat" "$(refresh_of "$pref")")
    echo "${best:-$pref}"
}

# Scale for monitor $1, given its chosen mode $2.
policy_scale() { # name mode
    local desc override
    desc=$(desc_of "$1")
    if override=$(table_lookup STABLE_SCALE "$desc"); then echo "$override"; return; fi
    case "$(res_of "$2")" in
        3840x1600) echo "$SCALE_UW" ;;
        3840x2160) echo "$SCALE_4K" ;;
        *)         echo 1 ;;
    esac
}

##############
#### MODES ###
##############

case "${1:-}" in
--list)
    # Modes print exactly as STABLE_MODE wants them, so an entry is a copy-paste.
    # "policy" is what this script would drive the monitor at right now.
    while read -r name; do
        [ -z "$name" ] && continue
        printf '%s  [%s]\n' "$name" "$(desc_of "$name")"
        printf '  current:   %s\n' \
            "$(echo "$mons" | jq -r --arg n "$name" '.[]|select(.name==$n)|"\(.width)x\(.height)@\(.refreshRate*100|round/100)"')"
        printf '  preferred: %s\n' "$(preferred_mode "$name")"
        printf '  policy:    %s\n' "$(policy_mode "$name" 2>/dev/null)"
        printf '  available: %s\n\n' "$(modes_of "$name" | paste -sd, - | sed 's/,/, /g')"
    done <<< "$(echo "$mons" | jq -r '.[].name')"
    exit 0
    ;;
--try)
    name=${2:-}; mode=${3:-}; secs=${4:-20}
    [ -z "$name" ] || [ -z "$mode" ] && { echo "usage: monitors.sh --try NAME MODE [SECONDS]" >&2; exit 2; }
    canon=$(resolve_mode "$name" "$mode")
    if [ -n "$canon" ]; then mode=$canon
    else echo "monitors: warning, $name does not advertise $mode -- trying anyway" >&2; fi
    prev=$(echo "$mons" | jq -r --arg n "$name" '.[] | select(.name==$n) | "\(.width)x\(.height)@\(.refreshRate)"')
    scale=$(echo "$mons" | jq -r --arg n "$name" '.[] | select(.name==$n) | .scale')
    pos=$(echo "$mons" | jq -r --arg n "$name" '.[] | select(.name==$n) | "\(.x)x\(.y)"')
    echo "monitors: $name -> $mode for ${secs}s (was $prev)"
    set_monitor "$name" "$mode" "$pos" "$scale"
    # If the monitor goes dark you cannot answer, so the timeout reverts for you.
    if read -r -t "$secs" -p "Keep $mode? [y/N] " ans && [ "$ans" = "y" ]; then
        echo "monitors: keeping $mode -- add it to STABLE_MODE to make it persist"
    else
        echo
        echo "monitors: reverting to $prev"
        set_monitor "$name" "$prev" "$pos" "$scale"
    fi
    exit 0
    ;;
esac

#################
#### LAYOUT #####
#################

# Internal panel name (eDP*); empty string on the desktop.
edp=$(echo "$mons" | jq -r '[.[] | select(.name|startswith("eDP")) | .name] | first // empty')

# Walk external monitors; pick the first that is one of the known big screens.
#
# Match on the resolution the monitor ASKS for as well as the largest it advertises.
# Neither alone is enough: one LG ultrawide here lists a bogus 4096x2160@100 mode, so
# the largest-advertised test missed a perfectly ordinary 3840x1600 panel and left the
# laptop screen on; while a monitor whose preferred mode is below its native res (a 4K
# that asks for 1080p) needs the largest-advertised test to be recognised at all.
chosen_name=""
externals=$(echo "$mons" | jq -r '.[] | select(.name|startswith("eDP")|not) | .name')
while read -r name; do
    [ -z "$name" ] && continue
    for res in "$(res_of "$(preferred_mode "$name")")" "$(native_res "$name")"; do
        case "$res" in 3840x1600|3840x2160) chosen_name=$name; break 2 ;; esac
    done
done <<< "$externals"

if [ -n "$chosen_name" ]; then
    mode=$(policy_mode "$chosen_name")
    scale=$(policy_scale "$chosen_name" "$mode")
    echo "monitors: driving $chosen_name at $mode (scale $scale)${edp:+; laptop panel off}"
    set_monitor "$chosen_name" "$mode" "0x0" "$scale"
    if [ -n "$edp" ]; then disable_monitor "$edp"; fi
else
    echo "monitors: no known external${edp:+; laptop panel on}"
    if [ -n "$edp" ]; then
        enable_monitor "$edp"
        set_monitor "$edp" "$(policy_mode "$edp")" "auto" "$SCALE_EDP"
    fi
    while read -r name; do
        [ -z "$name" ] && continue
        mode=$(policy_mode "$name")
        set_monitor "$name" "$mode" "auto" "$(policy_scale "$name" "$mode")"
    done <<< "$externals"
fi

# Audio follows the display: the monitor's own output when one is attached, the
# built-in card when it is not. Backgrounded because with a display attached it
# waits for the audio sink to show up -- the ELD/jack state lags the DRM hotplug.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$here/audio-follow-display.sh" ]; then
    if [ -n "$(echo "$externals" | tr -d "[:space:]")" ]; then
        "$here/audio-follow-display.sh" expect-display &
    else
        "$here/audio-follow-display.sh" &
    fi
fi
