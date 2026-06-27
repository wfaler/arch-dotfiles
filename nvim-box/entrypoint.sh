#!/usr/bin/env bash
# Seed the box's OWN writable copy of the nvim config from the read-only host
# mount (/seed/nvim), then run the given command. This way the box uses your real
# config + locked plugin versions but NEVER writes back to the host config or
# lazy-lock.json. Plugin/parser data persists separately in ~/.local/share (volume).
set -euo pipefail

if [ -d /seed/nvim ]; then
    mkdir -p "$HOME/.config/nvim"
    rsync -a --delete /seed/nvim/ "$HOME/.config/nvim/"
fi

exec "$@"
