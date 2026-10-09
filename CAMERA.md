# Webcam Settings

How webcam image settings (sharpness, brightness, etc.) are tuned and persisted in this dotfiles repo, and how to add another camera.

## Background

On Linux, browsers (Meet, etc.) get the camera's raw image with factory-default controls. Windows/macOS apply extra processing, so the same camera can look washed out or soft here. The fix is to tune the camera's own controls.

Webcams don't store these settings: they reset on every replug and reboot. `cameractrlsd` (from the `cameractrls` package) watches for cameras and re-applies a saved preset whenever one connects.

## How it's wired up

| File (in repo) | Purpose |
|---|---|
| `.config/hu.irl.cameractrls/<camera-id>.ini` | One preset file per camera. `[preset_1]` is applied on connect. |
| `.config/systemd/user/cameractrlsd.service` | User service running the restore daemon. Starts at login (`default.target`). |
| `install.sh` | Installs `cameractrls`, pre-creates `~/.config/systemd/user`, stows, enables the service. |

Current presets:

| Camera | File | Settings |
|---|---|---|
| Logitech BRIO | `usb-046d_Logitech_BRIO_639E2A1F-video-index0.ini` | brightness 111, sharpness 231 |
| Logitech C922 Pro Stream | `usb-046d_C922_Pro_Stream_Webcam_C6C9E0BF-video-index0.ini` | brightness 130, sharpness 231 |
| Framework Laptop Webcam (2nd Gen) | `usb-Framework_Laptop_Webcam_Module__2nd_Gen__FRANJBCHA1551503GH-video-index0.ini` | brightness 85, sharpness 7 (max) |

`~/.config/hu.irl.cameractrls` is a stow symlink into the repo, so presets saved from the GUI land in the repo and show up in `git diff`.

## Adding another camera

### 1. Find the camera and its controls

```fish
v4l2-ctl --list-devices
v4l2-ctl -d /dev/videoN --list-ctrls-menus
```

Use the first `/dev/videoN` listed under the camera. The control names (`brightness`, `sharpness`, `backlight_compensation`, ...) are the keys you'll use in the preset.

### 2. Tune it live

Open a Meet preview (or any camera app) and adjust until it looks right, either with the GUI:

```fish
/usr/bin/python3 /usr/bin/cameractrlsgtk4
```

or from the shell (changes apply live):

```fish
v4l2-ctl -d /dev/videoN -c sharpness=200 -c brightness=120
```

Things worth trying first: `sharpness`, `backlight_compensation=0` (it often washes the image out), `contrast`, `saturation`. Leave `power_line_frequency=1` (50 Hz) to avoid flicker under artificial light.

### 3. Find the preset file name

The file is named after the camera's stable `/dev/v4l/by-id/` entry (includes the serial, so it works on any port):

```fish
ls /dev/v4l/by-id/
```

Use the `...-video-index0` entry for the camera, e.g. `usb-046d_Logitech_BRIO_639E2A1F-video-index0` → `usb-046d_Logitech_BRIO_639E2A1F-video-index0.ini`.

### 4. Write the preset

Either list only the controls you changed (everything else stays at camera defaults):

```fish
printf '[preset_1]\nbrightness = 111\nsharpness = 231\n' > ~/dotfiles/.config/hu.irl.cameractrls/<camera-id>.ini
```

or, in the GUI, pick the camera and use **Save 1** in the presets menu. Note that GUI save writes *every* current control into the preset and replaces whatever `[preset_1]` was there.

### 5. Apply and verify

```fish
systemctl --user restart cameractrlsd
v4l2-ctl -d /dev/v4l/by-id/<camera-id> -C brightness,sharpness
```

Then unplug/replug the camera and check again. Logs: `journalctl --user -u cameractrlsd`.

### 6. Commit

Commit the new `.ini` and add it to the presets table above. No `stow` needed: the folder is already a symlink into the repo.

## Gotchas

- **Never `systemctl --user disable` or `reenable` cameractrlsd.** systemd treats the stowed unit as a "linked" unit and deletes the symlink. If that happens: `cd ~/dotfiles && stow . && systemctl --user enable cameractrlsd`.
- **Don't use the GUI's "Start with Systemd" toggle.** It overwrites the unit with one that waits for `graphical-session.target` (never reached under this Hyprland setup) and runs via `/usr/bin/env python3`.
- **mise shadows the system Python.** `cameractrlsgtk4` fails with `No module named 'gi'` if launched directly, so start it with `/usr/bin/python3` as above. The service already does this.
- **Fresh machines:** `~/.config/systemd/user` must exist before `stow .`, or stow folds `~/.config/systemd` into a repo symlink and `systemctl enable` writes `.wants/` links into the repo. `install.sh` handles this.
- **USB bandwidth:** a camera on a USB 2 link or a shared hub may only offer low resolutions in MJPEG. Check with `cat /sys/bus/usb/devices/*/speed` (480 = USB 2, 5000+ = USB 3) and `v4l2-ctl -d /dev/videoN --list-formats-ext`. USB 2 still gives the BRIO 1080p30 MJPEG, which is enough for Meet.
