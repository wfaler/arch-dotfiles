# Quick setup of my dev environment
Contains my setup for:
* Neovim
* Kitty  (terminal)
* Fish-shell
* Esthetically customized [Hyprland](https://hyprland.org/)
* All dev runtimes i use: Node, Go, Python (with Poetry), Ruby, Rust
* All the apps I use, more or less, installed via `yay` in Arch
## Pre-requisites
Assumes an Arch-based system (EndeavourOS with KDE Plasma is the primary target) with the `yay` package-manager installed. KDE Plasma is kept as a separate session; Dolphin is used as the file manager in both environments.

## Setup on Arch Linux
Clone this repository into your home-folder, so you end up with `$HOME/dotfiles` and run the install script:
```bash
./install.sh
```
Reboot, pick Hyprland as your WM, and you're done!

See [hyprland.md](hyprland.md) for a full keybinding reference and guide to managing volume, WiFi, Bluetooth, screenshots, and more.

You might also want to open neovim with `nvim` and run `:Lazy install` to install all the plugins, followed by `:MasonInstallAll` to install all the mason plugins.

The `install.sh` script is idempotent, so can also be used for system updates, or if this gets updated, getting the latest setup

## Hardware detection
`install.sh` auto-detects CPU vendor (AMD/Intel) and GPU(s) (AMD/Intel/Nvidia) via `/proc/cpuinfo` and `lspci`, then appends the right packages:

- AMD CPU → `amd-ucode`; Intel CPU → `intel-ucode`
- AMD GPU → `vulkan-radeon`, `libva-mesa-driver`
- Intel GPU → `vulkan-intel`, `intel-media-driver`
- Nvidia GPU → `nvidia-dkms`, `nvidia-utils`, `libva-nvidia-driver`

It also generates `~/.config/hypr/hardware.conf` (gitignored) with vendor-specific Hyprland env vars -- mainly for Nvidia (`LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`, `ELECTRON_OZONE_PLATFORM_HINT`). The main `hyprland.conf` sources this fragment.

### Nvidia notes
Pick "proprietary Nvidia" in the EndeavourOS installer so mkinitcpio MODULES, `linux-headers`, and the `nvidia_drm.modeset=1` kernel cmdline are configured at OS install time. `install.sh` then becomes a no-op for the Nvidia stack itself; only the Hyprland env-var stanza in `hardware.conf` is added.

### Issues
**pop-up windows for auth etc are just a tiny address bar on Brave and Chrome**
navigate to [chrome://flags](chrome://flags) and set `--ozone-platform=wayland`, this should fix the issue.

## Using Fish-shell
If you want to use the fishline, you can install it with:
```
fisher install 0rax/fishline
```


## Default applications
`install.sh` sets MIME defaults via `xdg-mime` (idempotent -- only writes when the value differs):

| MIME / scheme | Default |
|---|---|
| `x-scheme-handler/http`, `x-scheme-handler/https`, `text/html` | `firefox.desktop` |
| `application/pdf` | `org.kde.okular.desktop` |
| `application/x-synology-drive-doc/sheet/slides` | `synology-drive-open-file.desktop` |

To customize, edit the `xdg_defaults` associative array in `install.sh`. To inspect current state: `xdg-mime query default <mime>`.

### KDE settings 
* Navigate desktops with meta-[n]
* meta-W does "expose" style show all windows, can move around.

