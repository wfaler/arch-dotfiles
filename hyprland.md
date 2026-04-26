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

Volume is managed via PipeWire/WirePlumber using `wpctl`. You can also click the volume icon in waybar to open `pavucontrol` for detailed audio routing.

## Brightness

| Key | Action |
|---|---|
| `XF86MonBrightnessUp` | Brightness up 10% |
| `XF86MonBrightnessDown` | Brightness down 10% |

Managed via `brightnessctl`. Affects laptop backlight only -- external monitors don't respond to these keys (use the OSD or `ddcutil`).

`hypridle` also drops the backlight to 30% after 60s idle when on battery, restoring to the previous value on activity. No-op on AC and on desktops without a battery.

## Power Management

`power-profiles-daemon` runs as a system service and switches the CPU governor automatically on AC/battery transitions (balanced ↔ power-saver). Inspect or override manually with `powerprofilesctl list` / `powerprofilesctl set <profile>`.

If `powerprofilesctl` errors with `ModuleNotFoundError: No module named 'gi'`, mise's Python 3 is shadowing the system one in PATH. Workaround: `/usr/bin/python3 /usr/bin/powerprofilesctl ...`. The daemon itself works regardless of CLI status -- it's only the helper that's affected.

## Autostart

User-level XDG autostart entries in `~/.config/autostart/*.desktop` are launched at login via `dex -a -s ~/.config/autostart` (an `exec-once` in `hyprland.conf`). Apps like 1Password and Synology Drive drop their own entries there on install, so they come up automatically without further config.

System-wide entries in `/etc/xdg/autostart` are intentionally ignored, so KDE Plasma autostart files (kdeconnect, kwallet, plasma welcome, print applet, etc.) don't fire under Hyprland.

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

| Timeout | Action | Condition |
|---|---|---|
| 60 seconds | Dim backlight to 30% (saved → restored on resume) | Only on battery |
| 5 minutes | Lock screen (hyprlock) | Always |
| 5.5 minutes | Turn off display | Always |
| 10 minutes | `systemctl suspend` | Only on battery |

Moving the mouse or pressing a key wakes the display. The lock screen shows the time and accepts your user password.

The 10-minute suspend is gated on AC status by reading `/sys/class/power_supply/A*/online` -- if the value is `0` (on battery) the system suspends, otherwise nothing happens. On a desktop (no battery) AC is always reported as online, so the listener is effectively a no-op. On a laptop it kicks in only when unplugged.

### Suspend vs hibernate

We currently use plain `systemctl suspend` (suspend-to-RAM): fast resume, but still drains battery slowly and loses state if the battery dies. To upgrade to `systemctl hibernate` or `systemctl suspend-then-hibernate` later, the system needs a working resume target -- typically a swap partition or swapfile sized >= RAM, plus the `resume=` kernel parameter. Once that's set up, replace `systemctl suspend` in `~/.config/hypr/hypridle.conf` with the preferred command. `suspend-then-hibernate` is generally the best fit for a laptop since it gives quick resume on short idle and falls back to hibernate after a configurable delay (`HibernateDelaySec` in `/etc/systemd/sleep.conf`).

### Lid-close behavior

Lid-close is handled by `systemd-logind`, not Hyprland or hypridle. The repo tracks a drop-in at `system/etc/systemd/logind.conf.d/99-lid.conf` which `install.sh` deploys to `/etc/systemd/logind.conf.d/99-lid.conf` via `sudo install`:

```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
```

`install.sh` only copies when the file differs and prints a notice to reboot or run `sudo systemctl restart systemd-logind` to apply (the restart ends the current session). On a desktop these settings are no-ops since no lid-switch event ever fires. Adjust as desired -- e.g. set `HandleLidSwitchExternalPower=lock` if you'd rather have the laptop stay awake on AC and only lock the screen.

### Framework 13 migration checklist

Pre-flight checks before relying on the idle/suspend setup on the Framework 13:

1. **Sleep type**: `cat /sys/power/mem_sleep` should show `[s2idle]`. Framework 13 only supports modern standby; this is expected, not a problem.
2. **Power-supply paths**: `ls /sys/class/power_supply/` -- expect `ACAD` and `BAT1` (or similar). The `A*` glob in the hypridle listener matches `ACAD`.
3. **AC detection**: `cat /sys/class/power_supply/A*/online` returns `1` plugged in, `0` on battery. Test both states.
4. **Manual suspend works**: `systemctl suspend` from a terminal -- machine should suspend and resume cleanly via lid open / power button / keypress.
5. **Polkit suspend permission**: as your user, `systemctl suspend` should not prompt for a password (default for active sessions on EndeavourOS).
6. **Idle suspend fires on battery**: unplug, leave idle for 10 minutes, confirm it suspends.
7. **Idle suspend does NOT fire on AC**: plug in, leave idle past 10 minutes, confirm it stays awake (display will still turn off at 5.5 min -- that's expected).
8. **Lid-close config**: `systemctl show systemd-logind | grep HandleLidSwitch` shows the values from the drop-in file.
9. **Suspend drain**: suspend for ~1 hour on battery, check % drop. Anything above ~5%/hour suggests a firmware/kernel issue worth investigating (not a config problem).

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
