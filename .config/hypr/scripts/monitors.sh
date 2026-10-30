#!/usr/bin/env bash
# Dynamic monitor layout for Framework 13 (+ desktop, + external displays).
# Runs once at startup and again on every hotplug (see monitor-watch.sh).
#
#   external 3840x1600 (ultrawide) -> drive it, laptop panel OFF
#   external 3840x2160 (4K)        -> drive it, laptop panel OFF
#   several of the above           -> drive all, left to right per EXTERNAL_ORDER
#   no external, or unknown-res external -> laptop panel ON (extend the unknown one)
#
# Refresh rate policy: every monitor runs at the mode it asks for (its EDID
# preferred mode), unless STABLE_MODE below says otherwise. Do NOT go back to
# picking the highest advertised refresh -- see the comment on STABLE_MODE.
#
# VRR policy: off unless STABLE_VRR below says otherwise. VRR is a global setting
# in Hyprland, not a per-monitor one -- see the comment on apply_vrr().
#
# HDR policy: none, deliberately. It needs a whole session mode (10-bit costs 24 Hz
# on this link) -- the design and the measurements are in the HDR block below.
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

    # Dell G3223Q (32" 4K, 48-144 Hz panel, DSC 1.2a; no speakers -- see
    # NO_AUDIO_MONITORS in audio-follow-display.sh). Inputs: 2x HDMI 2.1, 1x DP 1.4.
    #
    # On the Framework 13 it hangs off the HDMI Expansion Card, an HDMI 2.0-class
    # converter whose DP side trains at 4 lanes x HBR2 (17.3 Gb/s): 4K60 is the
    # ceiling. Its EDID still lists 4K100/120 (the monitor is HDMI 2.1), which the
    # card cannot carry -- this entry pins 60 so nothing ever reaches for them.
    # It is also the fallback whenever the link type cannot be read (see link_of).
    ["framework13:DELL G3223Q"]="3840x2160@60"

    # The same Dell on its DP 1.4 input via a USB-C to DisplayPort cable (or the DP
    # card): native DP alt mode, all 4 lanes, HBR3 = 25.9 Gb/s, no Thunderbolt
    # tunnel or hub sharing it. 4K120 (~25 Gb/s at 8 bpc) fits without compression;
    # 144 (~32 Gb/s) needs DSC, which is what made the LG blink on this machine --
    # so 120 until 144 has been lived with: `--try DP-x 3840x2160@144`.
    # Not yet verified: the cable has not arrived. Inert until the mode is offered.
    ["framework13+dp:DELL G3223Q"]="3840x2160@120"

    # On the desktop over native DP 1.4 (25.9 Gb/s) or HDMI 2.1: 144 at 4K needs
    # ~32 Gb/s uncompressed, so over DP it rides on DSC (the panel and Nvidia both
    # support it); HDMI 2.1 FRL carries it outright. Not yet verified on that
    # machine -- `--try DP-x 3840x2160@144`, live with it a day, drop to 120 if it
    # blinks. Inert (falls back to preferred 60) if the mode is not advertised.
    ["raptor:DELL G3223Q"]="3840x2160@144"
)

# Per-monitor scale overrides, same key format. Falls back to the SCALE_* defaults.
declare -A STABLE_SCALE=(
    # 27" 4K (163 ppi) next to the 32" Dell G3223Q at scale 1 (138 ppi). 1.2 would
    # match the Dell's physical UI size exactly; 1.25 (3072x1728 logical) keeps it a
    # touch larger, which suits the smaller panel. Whole-pixel 4K alternatives:
    # 1.2, 1.333 (2880x1620), 1.5 (2560x1440 -- what scale = "auto" picks, too big).
    ["LG HDR 4K"]="1.25"
)

# Left-to-right order when more than one known external is attached, by description
# substring. Each sits at y=0, directly right of the previous one's logical width.
# Unlisted known externals follow the listed ones, in Hyprland's order -- so the
# layout no longer depends on which monitor happened to be plugged in first.
EXTERNAL_ORDER=(
    "DELL G3223Q"   # 32" 4K, scale 1 -- main screen, left
    "LG HDR 4K"     # 27" 4K over USB-C -- right
)

# VRR (adaptive sync) per monitor, same key format again. Values are Hyprland's:
#   0  off -- the default for any monitor with no entry here
#   1  always on, desktop included
#   2  only while a window is fullscreen
#   3  only for fullscreen windows that declare content type "game"
#
# Keyed per monitor for the same reason as STABLE_MODE -- whether a panel flickers
# under VRR is a property of that panel -- but only the value for the monitor actually
# being driven gets applied, because Hyprland has no per-monitor VRR (see apply_vrr).
#
# 2 rather than 3 for the LG on raptor: 3 keys off the wp_content_type_v1 hint, which
# mpv reports as "video" and not "game" during playback (--wayland-content-type
# defaults to auto), and which XWayland cannot set at all -- so Proton titles launched
# outside gamescope would never trigger it. 2 keys off the fullscreen state alone, so it
# covers games and fullscreen video alike, XWayland included.
#
# Verified capable on raptor, both ends: the panel's EDID carries an AMD FreeSync block
# (OUI 00-00-1A) advertising 48-144 Hz, and aquamarine logs "connector DP-1 crtc is
# capable of vrr" against the Nvidia driver. 24 fps film therefore lands exactly on the
# 48 Hz floor (each frame shown twice) and 25/30 fps on 50/60 -- the cases fixed-refresh
# handles worst. What to watch for is brightness shift on a STATIC fullscreen window,
# where the refresh sinks to the floor with no new frames arriving: that is where a VRR
# panel flickers if it is going to. Drop this to 3 (or 0) if it does.
declare -A STABLE_VRR=(
    ["raptor:LG HDR WQHD+"]=2
)

###############################################################################
#### HDR -- NOT IMPLEMENTED. DESIGN NOTES SO IT CAN BE BUILT LATER.
###############################################################################
#
# Everything here was measured on raptor on 2026-09-25. It is written down so the
# investigation does not have to be repeated; none of it is in effect.
#
# --- The one thing that is actively wrong today -------------------------------
#
# render:cm_auto_hdr defaults to 1 ("auto-switch to hdr mode when fullscreen app is
# in hdr") while bitdepth defaults to 8. On the LG 38WN95C that pairing makes the
# panel raise an on-screen warning about wide colour gamut with no 10-bit colour
# -- observed directly, not inferred. So fullscreening an HDR video right now hands
# the monitor BT.2020 primaries over an 8-bit link and it complains.
#
#   hl.config({ render = { cm_auto_hdr = 0 } })
#
# turns that off. It only wants to be 1 (hdr) or 2 (hdredid) inside a session that
# is actually running 10-bit, which is what the rest of this note is about. Left
# alone for now on purpose -- it is a one-liner whenever it starts to annoy.
#
# --- Why HDR needs a mode switch, not just a colour setting -------------------
#
# HDR on this panel requires 10 bits per channel: 8-bit HDR bands visibly, and
# raises the warning above. Hyprland *can* change colour mode per fullscreen app --
# `cm` is what render:cm_auto_hdr flips, and it logs "[CM] Auto HDR: changing
# monitor cm to {}" when it does -- but `bitdepth` is a persistent monitor property
# and cannot follow a window's fullscreen state. Verified: cm = "hdr" with
# bitdepth = 8 stays at XRGB8888; only an explicit bitdepth = 10 gives XBGR2101010.
#
# And 10-bit is 25% more bandwidth than 8, which this link cannot absorb at full
# refresh. Measured against DP 1.4 (4 lanes x 8.1 Gb/s x 8b/10b = 25.92 Gb/s of
# payload), htotal 4000 and vtotal 1694 taken from the EDID DisplayID block:
#
#     3840x1600@144   8bpc   975.7 MHz   23.42 Gb/s    90%  <- current, fits
#     3840x1600@144  10bpc   975.7 MHz   29.27 Gb/s   113%  <- would force DSC
#     3840x1600@120  10bpc   813.1 MHz   24.39 Gb/s    94%  <- fits, no DSC
#
# The 8bpc row reproduces the ~23.4 Gb/s already quoted in STABLE_MODE above, which
# is the check that this arithmetic is sound. So on raptor it is 144 Hz or HDR, and
# the switch costs 24 Hz. 120 at 10bpc is the fastest mode that needs no compression.
#
# --- Why it is keyed per host and monitor, like every other table here --------
#
# For the same reason STABLE_MODE is: the budget belongs to the monitor AND its
# cable AND its port. This same panel over the Framework's Thunderbolt tunnel has
# 17.3 Gb/s shared with the hub and power, where 10-bit would not reach even 75 Hz.
# Note the keys cover connection only implicitly -- one port per host for this panel
# -- so moving the LG to a USB-C port on raptor would match a key promising a mode
# the link cannot carry. Acceptable: it fails by not lighting up, same as any other
# bad STABLE_MODE entry.
#
# --- The design ---------------------------------------------------------------
#
# A table of the mode to use when HDR is on. No entry means HDR is unavailable for
# that monitor on that host, and `--hdr on` refuses rather than guessing:
#
#     declare -A HDR_MODE=( ["raptor:LG HDR WQHD+"]="3840x1600@120" )
#
# resolve_mode()'s +-0.5 Hz tolerance already maps @120 onto the advertised 119.98.
#
# Two session states, switched as a whole:
#
#     desktop:  STABLE_MODE   bitdepth 8    cm srgb   cm_auto_hdr 0
#     hdr:      HDR_MODE      bitdepth 10   cm srgb   cm_auto_hdr 2
#
# `cm` stays srgb in both. In the hdr state the desktop is plain 10-bit sRGB -- no
# wide-gamut signalling, so no warning -- and auto-HDR flips cm to hdredid only
# while a fullscreen HDR app is up. That is the point of the whole arrangement:
# HDR for fullscreen content that asks for it, never for the desktop. hdredid
# rather than hdr so tone mapping uses this panel's own EDID luminance (603 cd/m^2
# peak, 0.101 min) instead of generic metadata.
#
# Pieces to add:
#   - state in $XDG_RUNTIME_DIR/monitors-hdr. It must persist across invocations,
#     because this script re-runs on every hotplug -- otherwise a monitor event
#     mid-game silently drops back to the desktop mode. Runtime scope means every
#     login starts in desktop mode, which is the right default while HDR costs
#     refresh; move it under ~/.local/state to make it survive reboots.
#   - policy_mode(): consult HDR_MODE first when the state says on, else unchanged.
#   - policy_bitdepth(): 10 when on, 8 otherwise.
#   - apply_cm_auto_hdr(): global, via hl.config, exactly like apply_vrr().
#   - set_monitor(): gains a bitdepth argument. Happy accident -- a bitdepth change
#     forces the output re-commit that a per-monitor `vrr` rule would need, so
#     nothing gets stranded there.
#   - `--hdr on|off|toggle`: record the state, then re-run the layout, so the HDR
#     path and the hotplug path stay the same code. `--list` grows a line showing
#     the state, the mode each way, and the live cm/format.
#
# --- Still unverified ---------------------------------------------------------
#
#   - that 3840x1600@120 at 10bpc is stable on this link (94% utilisation). Run it
#     through --try and live with it a day before it goes in HDR_MODE, same rule as
#     every refresh rate here.
#   - that the 10-bit sRGB desktop really is warning-free. Needs eyes on the screen.
#   - auto-HDR only fires for clients that declare HDR over wp_color_management_v1.
#     XWayland cannot, so Proton titles will not trigger it; that needs gamescope,
#     which is not installed. Expect this to work for native Wayland clients (mpv
#     with vo=gpu-next, native Wayland games) and nothing else.
#
# --- Decision, 2026-09-25: deferred, not merely unbuilt ----------------------
#
# HDR for GAMES is not reachable from here regardless of what this script does, so
# the session mode above would buy 24 Hz worth of nothing for that use case. Proton
# titles run on XWayland, which cannot declare HDR over wp_color_management_v1, so
# Hyprland's auto-HDR never fires for them. The only route is gamescope, and on
# Nvidia gamescope's HDR path has a poor record:
#
#   - Nvidia's own tracker carries a long-standing report that display modes above
#     2560x1440@120 with HDR enabled flicker and corrupt inside gamescope-session,
#     reproduced on Arch and Fedora, nested and embedded, still seen on 5090-class
#     cards. Our HDR target (3840x1600@120) is above that threshold, and "flicker at
#     high resolution" is indistinguishable by eye from the DSC retraining this file
#     already fights. https://forums.developer.nvidia.com/t/295314
#   - gamescope's HDR path breaks often and not only on Nvidia: 3.16.17 broke it on
#     Fedora/GNOME (gamescope#2018) and on Arch/Plasma (gamescope#2037); washed-out
#     and yellow-cast HDR reports recur (gamescope#2000, #1827, #1404).
#   - Hyprland is the least-tested host for it. Nested-mode VRR is described as fine
#     on KDE and Sway while Hyprland lags (hyprwm/Hyprland discussion #11406).
#
# One caveat on that reading: the frequently cited claim that Nvidia's Wayland ICD
# lacks VK_EXT_swapchain_colorspace does NOT hold on 610.57.04 -- it is advertised
# at revision 5 (see the check below). Those reports predate this driver. So the
# gaming situation is better described as untested on current drivers with a bad
# history, rather than known broken. Either way it is an evening of work plus 24 Hz
# to find out, which is why this is parked rather than attempted.
#
# Revisit in ~6 months (so, from 2027-03) and check these in order, cheapest first:
#
#   1. vulkaninfo | grep VK_EXT_swapchain_colorspace
#      Present at rev 5 on 610.57.04 already -- recorded so nobody re-cites the
#      stale "Nvidia lacks it" claim as a reason not to try.
#   2. Is the Nvidia flicker/corruption thread above resolved? That is the bug that
#      would actually bite at 3840x1600@120, and it is the deciding one.
#   3. Any report of gamescope HDR working on Hyprland + Nvidia specifically. Absent
#      that, assume it does not.
#
# And note the VIDEO path does not depend on any of this. mpv with vo=gpu-next is a
# native Wayland client that can declare HDR, so the session mode above would work
# for HDR films today at the documented 24 Hz cost, with no gamescope in the picture.
# If HDR ever becomes worth building here, that is the case to build it for.
#
# --- Poking at it by hand (all of it undone by `hyprctl reload`) --------------
#
#   hyprctl eval 'hl.monitor({ output = "DP-1", cm = "hdredid", bitdepth = 10 })'
#   hyprctl eval 'hl.config({ render = { cm_auto_hdr = 2 } })'
#   hyprctl monitors -j | jq -r '.[0]|"\(.colorManagementPreset) \(.currentFormat)"'
#   edid-decode /sys/class/drm/card1-DP-1/edid   # AMD FreeSync + HDR static metadata
#
###############################################################################

# The value in table $1 whose key matches monitor description $2 on this host.
# A "host:substring" key only matches on that host and wins over a bare "substring"
# key, so a machine-specific entry can override a shared one. Returns 1 if nothing
# matches, so callers can tell "no entry" from "entry that happens to be empty".
#
# A host scope may also name the link type, "host+hdmi:substring" or
# "host+dp:substring" (see link_of), for a monitor that reaches this machine over
# more than one kind of connection. Most specific wins: host+link, then host, then
# unscoped. A host+link entry never matches when the link type is unknown, so the
# plain host entry is the safe fallback.
table_lookup() { # table-name desc [link]
    local -n tbl=$1
    local desc=$2 link=${3:-} key scope host klink pat by_host="" generic="" found=""
    for key in "${!tbl[@]}"; do
        scope=""; pat=$key
        case "$key" in *:*) scope=${key%%:*}; pat=${key#*:} ;; esac
        case "$desc" in *"$pat"*) ;; *) continue ;; esac
        host=${scope%%+*}; klink=""
        case "$scope" in *+*) klink=${scope#*+} ;; esac
        if [ -z "$scope" ]; then
            generic=${tbl[$key]}; found=1
        elif [ "$host" = "$THIS_HOST" ]; then
            if [ -n "$klink" ]; then
                [ -n "$link" ] && [ "$klink" = "$link" ] && { echo "${tbl[$key]}"; return 0; }
            else
                by_host=${tbl[$key]}; found=1
            fi
        fi
    done
    [ -n "$by_host" ] && { echo "$by_host"; return 0; }
    [ -n "$found" ] && { echo "$generic"; return 0; }
    return 1
}

# How monitor $1 is attached: "hdmi" when the DP connector feeds an HDMI converter
# (the Framework HDMI Expansion Card, a dongle), "dp" for native DisplayPort --
# USB-C alt mode, a DP card or cable -- or empty when unknown. Read from the DRM
# connector's subconnector property (HDMI=11, DP=10, Native=15) via modetest, which
# ships with libdrm (a Hyprland dependency) and only reads, so it works under a
# running compositor. The EDID cannot tell the two apart: the Dell G3223Q lists
# 4K120 over the HDMI card too, which that card cannot carry.
# Read once per run: link_of is always called inside $(...), where a lazy cache
# would not survive. Empty on non-amdgpu machines, where every link is unknown.
drm_connectors=$(modetest -M amdgpu -c 2>/dev/null | awk '
    /^[0-9]+\t[0-9]+\t(connected|disconnected)/ { c = $4 }
    /subconnector:/ { n = 4 }
    n && n-- && /value:/ { print c, $2 }')
link_of() { # name
    case "$(echo "$drm_connectors" | awk -v c="$1" '$1 == c { print $2 }')" in
        11)    echo hdmi ;;
        10|15) echo dp ;;
    esac
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

# Set Hyprland's VRR mode via the global misc:vrr rather than the per-monitor `vrr`
# field that hl.monitor() also accepts. That field does work, but only from the next
# time the output is actually re-committed -- setting it alone changes nothing, and
# setting it alongside a mode that is already current changes nothing either, because
# there is no commit. It applied immediately once a real format change (bitdepth 8->10)
# forced one. That makes it useless here: this script runs on every hotplug, usually
# with the mode already correct, so a per-monitor rule would silently not apply.
# misc:vrr takes effect the moment it is set. So the value belonging to the monitor
# being driven is applied globally instead. That is exact rather than approximate in this layout: an external
# display turns the laptop panel off, so there is only ever one active monitor here.
# If that stops being true, VRR follows the primary panel and the others inherit it.
apply_vrr() { # value
    local out
    out=$(hyprctl eval "hl.config({ misc = { vrr = $1 } })" 2>&1)
    [ "$out" = "ok" ] || echo "monitors: vrr: $out" >&2
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

    if want=$(table_lookup STABLE_MODE "$desc" "$(link_of "$name")"); then
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
    if override=$(table_lookup STABLE_SCALE "$desc" "$(link_of "$1")"); then echo "$override"; return; fi
    case "$(res_of "$2")" in
        3840x1600) echo "$SCALE_UW" ;;
        3840x2160) echo "$SCALE_4K" ;;
        *)         echo 1 ;;
    esac
}

# VRR mode for monitor $1. Off unless STABLE_VRR has an entry, so this stays inert on
# every monitor that has not been watched for flicker.
policy_vrr() { # name
    local desc override
    desc=$(desc_of "$1")
    if override=$(table_lookup STABLE_VRR "$desc" "$(link_of "$1")"); then echo "$override"; return; fi
    echo 0
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
        printf '  vrr:       policy %s (misc:vrr now %s, engaged right now: %s)\n' \
            "$(policy_vrr "$name")" \
            "$(hyprctl getoption misc:vrr -j 2>/dev/null | jq -r '.int // "?"')" \
            "$(echo "$mons" | jq -r --arg n "$name" '.[]|select(.name==$n)|.vrr')"
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
chosen=()
externals=$(echo "$mons" | jq -r '.[] | select(.name|startswith("eDP")|not) | .name')
while read -r name; do
    [ -z "$name" ] && continue
    for res in "$(res_of "$(preferred_mode "$name")")" "$(native_res "$name")"; do
        case "$res" in 3840x1600|3840x2160) chosen+=("$name"); break ;; esac
    done
done <<< "$externals"

# Position of monitor $1 in EXTERNAL_ORDER (99 if unlisted, so it sorts last).
order_of() { # name
    local desc i
    desc=$(desc_of "$1")
    for i in "${!EXTERNAL_ORDER[@]}"; do
        case "$desc" in *"${EXTERNAL_ORDER[$i]}"*) echo "$i"; return ;; esac
    done
    echo 99
}

# Logical width of a "WxH@Hz" mode at a scale (what the next monitor sits beside).
logical_width() { # mode scale
    awk -v w="${1%%x*}" -v s="$2" 'BEGIN { printf "%d", w / s + 0.5 }'
}

if [ "${#chosen[@]}" -gt 0 ]; then
    # Stable sort: EXTERNAL_ORDER first, Hyprland's order among equals.
    sorted=$(for n in "${chosen[@]}"; do printf '%s %s\n' "$(order_of "$n")" "$n"; done |
             sort -s -n -k1,1 | cut -d' ' -f2)
    x=0; primary=""
    while read -r name; do
        mode=$(policy_mode "$name")
        scale=$(policy_scale "$name" "$mode")
        echo "monitors: driving $name at $mode (scale $scale) at ${x}x0"
        set_monitor "$name" "$mode" "${x}x0" "$scale"
        case "$mode" in
            *x*@*) x=$(( x + $(logical_width "$mode" "$scale") )) ;;
            *)     x=$(( x + $(logical_width "$(native_res "$name")" "$scale") )) ;;
        esac
        primary=${primary:-$name}
    done <<< "$sorted"
    # VRR is global (see apply_vrr): it follows the leftmost, i.e. main, screen.
    vrr=$(policy_vrr "$primary")
    echo "monitors: vrr $vrr (from $primary)${edp:+; laptop panel off}"
    apply_vrr "$vrr"
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
    # VRR follows the primary panel: the laptop screen when it is in use, else the
    # first external. Unknown externals land here, and they are all off by default.
    primary=${edp:-$(echo "$externals" | head -1)}
    [ -n "$primary" ] && apply_vrr "$(policy_vrr "$primary")"
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

# Record how the external links came up, to compare sessions where a monitor
# blinks with ones where it does not (see link-snapshot.sh).
if [ -x "$here/link-snapshot.sh" ] && [ -n "$(echo "$externals" | tr -d "[:space:]")" ]; then
    "$here/link-snapshot.sh" &
fi
