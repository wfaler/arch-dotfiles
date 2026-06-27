#!/bin/bash

# Strip user PATH (mise shims etc.) so AUR builds see /usr/bin/python, not a mise python missing setuptools/mesonbuild.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin"

# AUR helper: Arch/EndeavourOS default to yay, CachyOS ships paru. Override with
# AUR_HELPER=paru; otherwise auto-detect (prefer yay). Flags below (-Syu/-S/-Yc)
# are identical between the two.
if [ -n "$AUR_HELPER" ]; then
    aur="$AUR_HELPER"
elif command -v yay >/dev/null 2>&1; then
    aur="yay"
elif command -v paru >/dev/null 2>&1; then
    aur="paru"
else
    echo "No AUR helper found (need yay or paru). Install one or set AUR_HELPER." >&2
    exit 1
fi

# Update system first
"$aur" -Syu --noconfirm

# List of packages to install
packages=(
    btop
    curl
    neovim
    ripgrep
    nerd-fonts
#    rustup
    stow
    podman
    podman-compose
    podman-docker
    distrobox
    direnv
    jq
    yq
    lazygit
    clang
    wget
    wireguard-tools
    pipewire
    wireplumber
 #   cargo-nextest
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
    pavucontrol
    wl-clipboard
    udiskie
    dex
    power-profiles-daemon
    yazi
    grim
    slurp
    socat
    ## VARIOUS CLIENT APPS
    slack-desktop-wayland
    spotify
    synology-drive
 #   claude-code
    1password
 #   zoom
    #obs-studio
    obsidian
    ib-tws
    #audacity
    protonmail-bridge
    proton-vpn-gtk-app
    darktable
    discord
    calibre
    okular
    gwenview
    google-chrome
    tailscale
    fish
    fisher
    libreoffice-fresh
    remmina
    freerdp
    vlc
    ffmpeg
    vlc-plugin-x264
    vlc-plugin-ffmpeg
    yt-dlp
    ## IntelliJ for JVM work
  #  jdk21-temurin
#    coursier
  #  intellij-idea-ultimate-edition-jre
  #  intellij-idea-ultimate-edition
  #  gradle
)

is_installed() {
    pacman -Qi "$1" &> /dev/null
}

# Hardware-specific package detection: append microcode + GPU userspace stack
# (vulkan/VA-API drivers + nvidia tools if a discrete Nvidia GPU is present).
# gpu_info is reused later to generate ~/.config/hypr/hardware.conf.
cpu_vendor=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
case "$cpu_vendor" in
    GenuineIntel) packages+=(intel-ucode) ;;
    AuthenticAMD) packages+=(amd-ucode) ;;
esac

gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display')
echo "$gpu_info" | grep -qiE 'amd|ati|advanced micro' && packages+=(vulkan-radeon libva-mesa-driver)
echo "$gpu_info" | grep -qi  intel                    && packages+=(vulkan-intel intel-media-driver)
echo "$gpu_info" | grep -qi  nvidia                   && packages+=(nvidia-dkms nvidia-utils libva-nvidia-driver)

# Laptop detection: a battery under /sys/class/power_supply means this is a laptop
# (same signal hypridle uses for its on-battery listeners). Append power-management
# + laptop-only userspace. thermald is Intel-only; AMD uses the in-kernel amd_pstate
# driver via power-profiles-daemon, so it needs no extra package.
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
    echo "Laptop detected -- adding laptop power-management packages."
    #   brightnessctl: internal-panel backlight (useless on a desktop)
    #   upower:        battery state for the waybar battery module + tooling
    #   fwupd:         firmware/BIOS updates via LVFS (Framework recommends)
    #   fprintd/libfprint: fingerprint reader
    packages+=(brightnessctl upower fwupd fprintd libfprint)
    if [ "$cpu_vendor" = "GenuineIntel" ]; then
        echo "Intel laptop -- adding thermald."
        packages+=(thermald)
    fi
fi

fail_log="install_fail.txt"

# Clear the fail log if it exists
> "$fail_log"

# Install packages if not already installed
for package in "${packages[@]}"; do
    if ! is_installed "$package"; then
        echo "Installing $package..."
        if ! "$aur" -S --noconfirm "$package"; then
            echo "Failed to install $package. Logging and continuing..."
            echo "$package" >> "$fail_log"
        fi
    else
        echo "$package is already installed. Skipping."
    fi
done

# Remove unnecessary dependencies
"$aur" -Yc --noconfirm

# Install Kitty last
if ! is_installed "kitty"; then
    echo "Installing kitty..."
    if ! "$aur" -S --noconfirm kitty; then
        echo "Failed to install Kitty. Logging and continuing..."
        echo "Kitty" >> "$fail_log"
    fi
else
    echo "Kitty is already installed. Skipping."
fi

echo "All packages have been checked/installed. Unnecessary dependencies have been removed."

if [ -s "$fail_log" ]; then
    echo "Some installations failed. Check $fail_log for details."
else
    echo "All installations completed successfully."
    rm "$fail_log"
fi
# Rootless Podman setup: subuid/subgid map, user-level socket, lingering.
if is_installed "podman"; then
    needs_relogin=0
    if ! grep -q "^$USER:" /etc/subuid 2>/dev/null; then
        sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
        echo "subuid/subgid assigned to $USER for rootless containers."
        needs_relogin=1
    fi
    if ! systemctl --user is-enabled --quiet podman.socket 2>/dev/null; then
        systemctl --user enable --now podman.socket \
            || echo "Could not enable user podman.socket -- run 'systemctl --user enable --now podman.socket' after next login."
    fi
    if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        sudo loginctl enable-linger "$USER"
        echo "Lingering enabled for $USER (rootless podman socket survives logout)."
    fi
    if [ "$needs_relogin" = "1" ]; then
        echo "Log out and back in for subuid/subgid changes to take effect."
    fi
fi


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

# Enable power-profiles-daemon (auto CPU governor scaling on AC/battery transitions).
if is_installed "power-profiles-daemon"; then
    if ! systemctl is-enabled --quiet power-profiles-daemon.service; then
        sudo systemctl enable --now power-profiles-daemon.service
        echo "power-profiles-daemon enabled and started."
    fi
fi

# Laptop power services. Only installed on laptops, so is_installed gates them;
# fprintd and upower are D-Bus/socket-activated and need no explicit enable.
if is_installed "thermald"; then
    if ! systemctl is-enabled --quiet thermald.service; then
        sudo systemctl enable --now thermald.service
        echo "thermald enabled and started."
    fi
fi
if is_installed "fwupd"; then
    # Periodic LVFS metadata refresh (the fwupd service itself is socket-activated).
    if ! systemctl is-enabled --quiet fwupd-refresh.timer; then
        sudo systemctl enable --now fwupd-refresh.timer
        echo "fwupd-refresh.timer enabled."
    fi
fi

# Set fish as the login shell (so Ghostty / SSH / tmux pick it up via $SHELL).
fish_path="$(command -v fish)"
if [ -n "$fish_path" ]; then
    if ! grep -qxF "$fish_path" /etc/shells; then
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$current_shell" != "$fish_path" ]; then
        sudo chsh -s "$fish_path" "$USER"
        echo "Login shell changed to $fish_path -- log out and back in to take effect."
    fi
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

# Generate ~/.config/hypr/hardware.conf based on detected GPU.
# hyprland.conf sources this; we always write the file (even if empty body)
# so the `source =` directive doesn't error.
hardware_conf="$HOME/.config/hypr/hardware.conf"
mkdir -p "$(dirname "$hardware_conf")"
{
    echo "# AUTO-GENERATED by install.sh -- do not edit by hand."
    echo "# Detected: cpu=$cpu_vendor"
    echo "$gpu_info" | sed 's/^/# gpu: /'
    echo
    if echo "$gpu_info" | grep -qi nvidia; then
        cat <<'EOF'
# Nvidia-specific Hyprland settings (driver >= 555 recommended).
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = ELECTRON_OZONE_PLATFORM_HINT,auto
# Uncomment if cursor flickers on older Nvidia drivers:
#cursor {
#    no_hardware_cursors = true
#}
EOF
    fi
} > "$hardware_conf"

# Default application handlers. xdg-mime rewrites mimeapps.list on every call --
# only call it when the value actually differs.
declare -A xdg_defaults=(
    [x-scheme-handler/http]=firefox.desktop
    [x-scheme-handler/https]=firefox.desktop
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
for mime in "${!xdg_defaults[@]}"; do
    desktop="${xdg_defaults[$mime]}"
    if [ "$(xdg-mime query default "$mime" 2>/dev/null)" != "$desktop" ]; then
        echo "Setting $mime default to $desktop..."
        xdg-mime default "$desktop" "$mime"
    fi
done

# Trigger user XDG autostart now so first-install brings up 1Password / Synology Drive
# without requiring a logout. Subsequent logins go through hyprland's exec-once.
if is_installed "dex"; then
    dex -a -s ~/.config/autostart >/dev/null 2>&1 || true
fi

# Isolated Neovim container: build the image (idempotent) and install the launcher.
# Strict "only the nvim config + cwd" isolation needs rootless podman, not distrobox
# (distrobox always shares $HOME); see nvim-box/.
if is_installed "podman" && [ -d "$script_dir/nvim-box" ]; then
    if ! podman image exists localhost/nvim-box:latest; then
        echo "Building nvim-box container image (first build, may take a while)..."
        podman build --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
            -t nvim-box "$script_dir/nvim-box" \
            || echo "nvim-box build failed -- run 'podman build -t nvim-box $script_dir/nvim-box' later."
    fi
    install -D -m 755 "$script_dir/nvim-box/nvim-box" "$HOME/.local/bin/nvim-box"
    echo "nvim-box launcher installed to ~/.local/bin/nvim-box"
fi

# Integrated GUI/JVM distrobox (IntelliJ Ultimate + Scala/Kotlin/Java toolchain).
# Shares $HOME + display so GUI apps work. Heavy first build (downloads IntelliJ);
# skipped if the container already exists.
if is_installed "distrobox" && [ -f "$script_dir/distrobox/distrobox.ini" ]; then
    if ! distrobox list 2>/dev/null | grep -q "arch-dev"; then
        echo "Assembling arch-dev distrobox (downloads IntelliJ + toolchain; may take a while)..."
        distrobox assemble create --file "$script_dir/distrobox/distrobox.ini" \
            || echo "distrobox assemble failed -- run 'distrobox assemble create --file $script_dir/distrobox/distrobox.ini' later."
    fi
fi
