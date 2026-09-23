#!/usr/bin/env bash
# Default application handlers (browser, PDF, images, Synology Drive docs).
#
# This is a separate script, not a block inside install.sh, because it needs
# re-running on its own: any app that offers to "become your default" rewrites
# ~/.config/mimeapps.list behind your back -- Chromium claiming http/https is the
# usual culprit -- and fixing that should not require a full install run.
#
# mimeapps.list is deliberately NOT stowed. It is mutable state that xdg-mime,
# browsers and Plasma's settings rewrite by temp-file-and-rename, which silently
# replaces a stow symlink with a regular file and leaves the repo copy stale.
# Declaring the intent here and re-applying it is the robust half of that trade.
#
#   ./xdg-defaults.sh           apply (idempotent; only touches what differs)
#   ./xdg-defaults.sh --check   report drift, change nothing
set -uo pipefail

# about/unknown are in here because that is what a real "make Firefox default"
# writes: apps route odd URLs through them, and leaving them out lets another
# browser keep a foot in the door.
declare -A xdg_defaults=(
    [x-scheme-handler/http]=firefox.desktop
    [x-scheme-handler/https]=firefox.desktop
    [x-scheme-handler/about]=firefox.desktop
    [x-scheme-handler/unknown]=firefox.desktop
    [text/html]=firefox.desktop
    [application/pdf]=org.kde.okular.desktop
    [image/jpeg]=org.kde.gwenview.desktop
    [image/png]=org.kde.gwenview.desktop
    [image/webp]=org.kde.gwenview.desktop
    [image/gif]=org.kde.gwenview.desktop
    [application/x-synology-drive-doc]=synology-drive-open-file.desktop
    [application/x-synology-drive-sheet]=synology-drive-open-file.desktop
    [application/x-synology-drive-slides]=synology-drive-open-file.desktop
)

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

drift=0
for mime in $(printf '%s\n' "${!xdg_defaults[@]}" | sort); do
    desktop="${xdg_defaults[$mime]}"
    # xdg-mime rewrites mimeapps.list on every call, so only call it when the
    # value actually differs.
    current=$(xdg-mime query default "$mime" 2>/dev/null)
    [ "$current" = "$desktop" ] && continue
    drift=1
    if [ "$check_only" = 1 ]; then
        printf '%-42s is %-34s want %s\n' "$mime" "${current:-<unset>}" "$desktop"
    else
        echo "Setting $mime default to $desktop..."
        xdg-mime default "$desktop" "$mime"
    fi
done

if [ "$drift" = 0 ]; then
    echo "xdg defaults: all handlers already as declared"
fi
exit 0
