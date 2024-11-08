# Quick setup of my dev environment
Contains my setup for:
* Neovim
* Kitty  (terminal)
* Fish-shell
* Esthetically customized [Hyprland](https://hyprland.org/)
* All dev runtimes i use: Node, Go, Python (with Poetry), Ruby, Rust
* All the apps I use, more or less, installed via `yay` in Arch
## Pre-requisites
Assumes an Arch-based system, with the `yay` package-manager installed, and KDE Plasma (even though it uses Hyprland, we have some KDE tools configured as defaults, such as Dolphin for file management)

## Setup on Arch Linux
Clone this repository into your home-folder, so you end up with `$HOME/dotfiles` and run the install script:
```bash
./install.sh
```
Reboot, pick Hyprland as your WM, and you're done!

You might also want to open neovim with `nvim` and run `:Lazy install` to install all the plugins, followed by `:MasonInstallAll` to install all the mason plugins.

The `install.sh` script is idempotent, so can also be used for system updates, or if this gets updated, getting the latest setup

## Nvidia systems
Uncomment the `nvidia-inst` line of the install script.
Run `nvidia-inst` after installation, to install all the nvidia-tools

### Issues
**pop-up windows for auth etc are just a tiny address bar on Brave and Chrome**
navigate to [chrome://flags](chrome://flags) and set `--ozone-platform=wayland`, this should fix the issue.

## Using Fish-shell
If you want to use the fishline, you can install it with:
```
fisher install 0rax/fishline
```
