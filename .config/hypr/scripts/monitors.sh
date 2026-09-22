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

# Refresh rates verified STABLE, keyed by a substring of the monitor description
# (run `monitors.sh --list` to see the descriptions). A monitor with no entry here
# runs at its EDID preferred mode, which is the conservative, always-safe choice.
#
# These are empirical and cannot be derived. A mode that is advertised, lights up
# and looks perfect can still drop the DP link every few minutes; nothing detects
# that but you, over hours. Raise a rate with `--try`, live with it for a day, then
# record it here.
#
# The stable rate belongs to the monitor AND its cable AND its port, not to the
# monitor alone -- a USB-C display shares one link between pixels, its USB hub and
# power. Re-verify after changing any of those.
declare -A STABLE_MODE=(
    # LG 38WN95C over USB-C. It advertises 144 and 144 lights up fine, but the
    # Thunderbolt link negotiates 20 Gb/s (2 lanes x 10), leaving DP 4 lanes of
    # HBR2 = 17.3 Gb/s of payload, shared with the monitor's USB hub. 144 needs
    # ~23.4 Gb/s before compression, so it leans hard on DSC and retrains every
    # few minutes, blanking the screen. 120 is the panel's own preferred mode.
    # 75 is the fastest mode that needs no compression at all, if 120 still blinks.
    ["LG HDR WQHD+"]="3840x1600@119.98"
)

# Per-monitor scale overrides, same key format. Falls back to the SCALE_* defaults.
declare -A STABLE_SCALE=()

mons=$(hyprctl monitors all -j)

# Apply a monitor rule. Hyprland >= 0.55 with a lua config takes `hyprctl eval`
# (it prints "ok" on success); pre-lua .conf sessions still need `hyprctl keyword`.
set_monitor() { # name mode position scale
    hyprctl eval "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = $4 })" 2>&1 |
        grep -qx "ok" || hyprctl keyword monitor "$1,$2,$3,$4"
}

disable_monitor() { # name
    hyprctl eval "hl.monitor({ output = \"$1\", disabled = true })" 2>&1 |
        grep -qx "ok" || hyprctl keyword monitor "$1,disable"
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

    for key in "${!STABLE_MODE[@]}"; do
        case "$desc" in *"$key"*)
            want=${STABLE_MODE[$key]}
            canon=$(resolve_mode "$name" "$want")
            if [ -n "$canon" ]; then echo "$canon"; return; fi
            # A different monitor matched the key, or the entry has a typo. Either
            # way, refuse to force a mode the hardware never offered.
            echo "monitors: $name [$desc] does not advertise $want; using preferred" >&2
            break ;;
        esac
    done

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
    local desc key
    desc=$(desc_of "$1")
    for key in "${!STABLE_SCALE[@]}"; do
        case "$desc" in *"$key"*) echo "${STABLE_SCALE[$key]}"; return ;; esac
    done
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

# Walk external monitors; pick the first that advertises a known resolution.
chosen_name=""
externals=$(echo "$mons" | jq -r '.[] | select(.name|startswith("eDP")|not) | .name')
while read -r name; do
    [ -z "$name" ] && continue
    nat=$(native_res "$name")
    if [ "$nat" = "3840x1600" ] || [ "$nat" = "3840x2160" ]; then chosen_name=$name; break; fi
done <<< "$externals"

if [ -n "$chosen_name" ]; then
    mode=$(policy_mode "$chosen_name")
    scale=$(policy_scale "$chosen_name" "$mode")
    echo "monitors: driving $chosen_name at $mode (scale $scale); laptop panel off"
    set_monitor "$chosen_name" "$mode" "0x0" "$scale"
    if [ -n "$edp" ]; then disable_monitor "$edp"; fi
else
    echo "monitors: no known external; laptop panel on"
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
