#!/bin/bash

# Update system first
yay -Syu --noconfirm

# List of packages to install
packages=(
    # nvidia-inst # only for nvidia systems
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
    kubectl
    kubectx
    helm
    tmux
    tailscale
    fish
    fisher
    ## HYPRLAND & RELATED TOOLS
    hyprland
    wlogout
    waybar
    wofi
    xwaylandvideobridge
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    hyprpaper
    hyprlock
    blueman
    network-manager-applet
    wl-clipboard
    udiskie
    yazi
    dunst
    grim
    slurp
    swayidle
    ## VARIOUS CLIENT APPS
    slack-desktop-wayland
    spotify
    dropbox 
    1password
    zoom
    obs-studio
    obsidian
    whatsie
    todoist-appimage
    bruno
    evolution
    audacity
    protonmail-bridge
    proton-vpn-gtk-app
    signal-desktop
    darktable
    discord
    calibre
    google-chrome
    tailscale
    fish
    fisher
    ## IntelliJ for JVM work
    jdk21-temurin
    coursier
    intellij-idea-ultimate-edition-jre
    intellij-idea-ultimate-edition
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

# Install Alacritty last
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
