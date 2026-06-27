#!/usr/bin/env bash
# Provision the arch-dev distrobox: AUR helper + IntelliJ Ultimate + AUR-only JVM
# tools. Called from distrobox.ini init_hooks (as root); re-execs as the box user
# because makepkg/paru refuse to run as root. Idempotent -- safe to re-run.
set -euo pipefail

# init_hooks runs us as root -> drop to the (non-root) box user.
if [ "$(id -u)" -eq 0 ]; then
    boxuser="$(getent passwd 1000 | cut -d: -f1)"
    exec su - "$boxuser" -c "bash '$(readlink -f "$0")'"
fi

# ---- from here on we are the box user (passwordless sudo provided by distrobox) ----

# Bootstrap paru (AUR helper) if absent. base-devel + git come from additional_packages.
if ! command -v paru >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
fi

# AUR packages not in the official repos. --needed makes re-runs no-ops.
paru -S --noconfirm --needed \
    intellij-idea-ultimate-edition \
    jdk21-temurin \
    coursier \
    sbt \
    claude-code
