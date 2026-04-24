# Hyprland Quick Reference

This documents all keybindings and common operations for the Hyprland setup in this dotfiles repo.

`Super` refers to the Meta/Windows key.

## Window Management

| Keybinding | Action |
|---|---|
| `Super + Q` | Close focused window |
| `Super + V` | Toggle floating for focused window |
| `Super + P` | Toggle pseudotile (dwindle) |
| `Super + J` | Toggle split orientation (dwindle) |
| `Super + Arrow keys` | Move focus (left/right/up/down) |
| `Super + LMB drag` | Move window |
| `Super + RMB drag` | Resize window |

Windows can also be resized by dragging borders (enabled via `resize_on_border`).

## Workspaces

| Keybinding | Action |
|---|---|
| `Super + 1-9, 0` | Switch to workspace 1-10 |
| `Super + Shift + 1-9, 0` | Move focused window to workspace 1-10 |
| `Super + Mouse scroll` | Scroll through workspaces |
| `Super + S` | (unbound -- available) |

## Launching Apps

| Keybinding | Action |
|---|---|
| `Super + D` | App launcher (wofi) |
| `Super + TAB` | Window switcher (wofi) |
| `Super + E` | File manager (Dolphin) |
| `Super + M` | Power/logout menu (wlogout) |

## Volume

Hardware media keys work out of the box:

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up 5% |
| `XF86AudioLowerVolume` | Volume down 5% |
| `XF86AudioMute` | Toggle mute (speakers) |
| `XF86AudioMicMute` | Toggle mute (microphone) |

Volume is managed via PipeWire/WirePlumber using `wpctl`. You can also click the volume icon in waybar to open `pwvucontrol` for detailed audio routing.

## Brightness

| Key | Action |
|---|---|
| `XF86MonBrightnessUp` | Brightness up 10% |
| `XF86MonBrightnessDown` | Brightness down 10% |

Managed via `brightnessctl`.

## WiFi

| Keybinding | Action |
|---|---|
| `Super + W` | Open WiFi TUI (nmtui in kitty) |
| Click network icon in waybar | Same as above |

`nmtui` lets you connect to networks, edit connections, and set hostname. Use arrow keys to navigate, Enter to select.

## Bluetooth

| Keybinding | Action |
|---|---|
| `Super + B` | Open Bluetooth TUI (bluetuith in kitty) |
| Click bluetooth icon in waybar | Same as above |

`bluetuith` lets you scan, pair, connect, and manage Bluetooth devices. Use arrow keys and Enter to navigate.

## Screenshots

| Keybinding | Action |
|---|---|
| `Print` | Screenshot full screen to clipboard |
| `Super + Shift + S` | Screenshot selected region to clipboard |

Uses `grim` (capture) and `slurp` (region select). Images are copied to clipboard via `wl-copy` -- paste into any app.

## Clipboard History

| Keybinding | Action |
|---|---|
| `Super + Shift + V` | Browse clipboard history (wofi picker) |

Clipboard history is automatically tracked for both text and images via `cliphist`.

## Notifications

| Keybinding | Action |
|---|---|
| `Super + N` | Toggle notification center drawer |

Managed by SwayNotificationCenter (`swaync`).

## Screen Lock and Idle

Handled by `hypridle` and `hyprlock`:

| Timeout | Action |
|---|---|
| 5 minutes | Lock screen (hyprlock) |
| 5.5 minutes | Turn off display |
| 10 minutes | Suspend |

Moving the mouse or pressing a key wakes the display. The lock screen shows the time and accepts your user password.

The wlogout menu (`Super + M`) also provides manual lock, suspend, logout, reboot, and shutdown:

| Key | Action |
|---|---|
| `l` | Lock |
| `s` | Suspend/sleep |
| `e` | Exit/logout Hyprland |
| `p` | Power off |
| `r` | Reboot |

## Keyboard Layout

The keyboard is configured with US and Swedish layouts. Toggle between them with `Super + Space`.

## Waybar Modules

The status bar (waybar) shows, left to right:
- **Left**: App launcher, quick links, active window title
- **Center**: Workspace indicators (click to switch)
- **Right**: Volume, Network, Bluetooth, CPU, Memory, Keyboard state, Battery, Clock, System tray, Power menu
