#!/bin/bash

# Strip user PATH (mise shims etc.) so AUR builds see /usr/bin/python, not a mise python missing setuptools/mesonbuild.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin"

# Update system first
yay -Syu --noconfirm

# List of packages to install
packages=(
    nvidia-inst # only for nvidia systems
    btop
    curl
    neovim
    ripgrep
    nerd-fonts
    rustup
    zsh
    stow
    docker
    docker-buildx
    docker-compose
    oh-my-zsh-git
    nerdfetch
    direnv
    jq
    yq
    clang
    wget
    wireguard-tools
    pipewire
    wireplumber
    cargo-nextest
    git-secret
    gnupg
    cloc
    tmux
    tailscale
    fish
    fisher
    ## HYPRLAND & RELATED TOOLS
    hyprland
    wlogout
    waybar
    wofi
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    swaync
    bluetuith
    cliphist
    brightnessctl
    pavucontrol
    wl-clipboard
    udiskie
    yazi
    grim
    slurp
    ## VARIOUS CLIENT APPS
    slack-desktop-wayland
    spotify
    synology-drive
    claude-code
    gemini-cli-git
    1password
    zoom
    #obs-studio
    obsidian
    #whatsie
    todoist-appimage
    beeper
   # bruno
    ib-tws
    #evolution
    #audacity
    protonmail-bridge
    proton-vpn-gtk-app
    darktable
    discord
    calibre
    okular
    google-chrome
    tailscale
    fish
    fisher
    libreoffice-fresh
    ## IntelliJ for JVM work
    jdk21-temurin
    coursier
    intellij-idea-ultimate-edition-jre
    intellij-idea-ultimate-edition
    gradle
)

is_installed() {
    pacman -Qi "$1" &> /dev/null
}

fail_log="install_fail.txt"

# Clear the fail log if it exists
> "$fail_log"

# Install packages if not already installed
for package in "${packages[@]}"; do
    if ! is_installed "$package"; then
        echo "Installing $package..."
        if ! yay -S --noconfirm "$package"; then
            echo "Failed to install $package. Logging and continuing..."
            echo "$package" >> "$fail_log"
        fi
    else
        echo "$package is already installed. Skipping."
    fi
done

# Remove unnecessary dependencies
yay -Yc --noconfirm

# Install Rust stable toolchain if rustup is installed
if is_installed "rustup"; then
    if rustup install stable && rustup default stable; then
        echo "Rust stable toolchain installed and set as default."
    else
        echo "Failed to install Rust stable toolchain. Logging and continuing..."
        echo "rustup_stable_toolchain" >> "$fail_log"
    fi
else
    echo "rustup is not installed. Skipping Rust toolchain installation."
fi

# Install Kitty last
if ! is_installed "kitty"; then
    echo "Installing kitty..."
    if ! yay -S --noconfirm kitty; then
        echo "Failed to install Kitty. Logging and continuing..."
        echo "Kitty" >> "$fail_log"
    fi
else
    echo "Kitty is already installed. Skipping."
fi
if ! is_installed "mise"; then
    echo "Installing mise..."
    if ! yay -S --noconfirm mise; then
        echo "Failed to install mise. Logging and continuing..."
        echo "mise" >> "$fail_log"
    fi
else
    echo "Mise is already installed. Skipping."
fi


echo "All packages have been checked/installed. Unnecessary dependencies have been removed."

if [ -s "$fail_log" ]; then
    echo "Some installations failed. Check $fail_log for details."
else
    echo "All installations completed successfully."
    rm "$fail_log"
fi
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    sudo usermod -aG docker $USER
    echo "User $USER added to the docker group."
else
    echo "User $USER is already in the docker group."
fi

# Inform the user about the need to log out and back in
echo "Please log out and back in for the changes to take effect."
echo "Alternatively, you can run 'newgrp docker' to apply the changes in the current shell session."


if systemctl is-enabled --quiet systemd-resolved; then
    echo "systemd-resolved is already enabled."
else
    sudo systemctl enable systemd-resolved
    echo "systemd-resolved has been enabled."
fi

# Check if systemd-resolved is running
if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved is already running."
else
    sudo systemctl start systemd-resolved
    echo "systemd-resolved has been started."
fi

stow .

# Deploy system-level configs (root-owned, mirrors paths under system/).
# Currently: logind drop-in for lid-close behavior. No-op on desktops.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$script_dir/system" ]; then
    while IFS= read -r -d '' src; do
        rel="${src#$script_dir/system/}"
        dest="/$rel"
        if ! sudo cmp -s "$src" "$dest" 2>/dev/null; then
            echo "Installing $dest..."
            sudo install -D -m 644 "$src" "$dest"
            case "$dest" in
                /etc/systemd/logind.conf.d/*) logind_changed=1 ;;
            esac
        fi
    done < <(find "$script_dir/system" -type f -print0)
    if [ "${logind_changed:-0}" = "1" ]; then
        echo "logind config changed -- reboot or run 'sudo systemctl restart systemd-logind' to apply (this ends the session)."
    fi
fi

# Default application handlers. xdg-mime rewrites mimeapps.list on every call --
# only call it when the value actually differs.
declare -A xdg_defaults=(
    [x-scheme-handler/http]=firefox.desktop
    [x-scheme-handler/https]=firefox.desktop
    [text/html]=firefox.desktop
    [application/pdf]=org.kde.okular.desktop
    [application/x-synology-drive-doc]=synology-drive-open-file.desktop
    [application/x-synology-drive-sheet]=synology-drive-open-file.desktop
    [application/x-synology-drive-slides]=synology-drive-open-file.desktop
)
for mime in "${!xdg_defaults[@]}"; do
    desktop="${xdg_defaults[$mime]}"
    if [ "$(xdg-mime query default "$mime" 2>/dev/null)" != "$desktop" ]; then
        echo "Setting $mime default to $desktop..."
        xdg-mime default "$desktop" "$mime"
    fi
done

# Install mise-managed toolchains from ~/.config/mise/config.toml (now stowed)
if is_installed "mise"; then
    mise install
    # Install rig. GOBIN forces output to ~/go/bin (fish PATH includes it).
    GOBIN="$HOME/go/bin" mise exec -- go install github.com/wfaler/rig@latest
fi
