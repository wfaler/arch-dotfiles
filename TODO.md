# TODO

## LG 38WN95C blinking: new Thunderbolt cable

The LG 38WN95C (Thunderbolt 3, USB-C) blinks off/on as if replugged, in some sessions
every ~15 min, with nothing in the kernel or Hyprland logs: the laptop keeps sending,
the monitor drops the picture. Only this screen does it. Suspect the cable: the
Thunderbolt link trains at half speed, `20 Gb/s = 2 lanes * 10 Gb/s` (TB3 is 40).

Buying: Satechi Thunderbolt 4 Pro cable, 1 m, braided, 40 Gbps, 240 W, model
ST-YTB100K (digitec 38610725). Thunderbolt logo on the connector = Intel certified.

When it arrives:

- [ ] Swap it in between the laptop and the LG.
- [ ] `boltctl list` should now show `40 Gb/s = 2 lanes * 20 Gb/s`. Still 20? Try the
      other rear USB-C port before blaming the cable.
- [ ] `~/.config/hypr/scripts/link-snapshot.sh now` to record the new link.
- [ ] On any blink: `~/.config/hypr/scripts/link-snapshot.sh blink`. Blinks at 40 Gb/s
      point at the monitor rather than the cable (decisive test then: plain
      DisplayPort cable + separate charger, which bypasses Thunderbolt entirely).
- [ ] If it is stable for a few days: consider raising the LG above 75 Hz again
      (`STABLE_MODE` in `.config/hypr/scripts/monitors.sh`; 75 was chosen because of
      the 20 Gb/s link).
- [ ] Port suspicion: blinks felt more frequent on the top rear port (typec port0,
      Thunderbolt domain 0). Moved the LG to port3 (domain 1) on 2026-11-02 21:31. Still
      20 Gb/s there, so the half-speed link is not the port. If port3 blinks less:
      suspect the port0 bay or its expansion card; swap the USB-C cards between bays.
- [ ] Run `./install.sh` once first: the fixed `system/usr/local/bin/dp-link-state`
      fills in the DP link section of each snapshot (it was empty before).

## hyprlock 0.9.7 crashes (SIGABRT) around suspend/resume

Started with the upgrade 0.9.6 -> 0.9.7 on 2026-11-02 (no hyprlock crashes before).
Crashed three times that day: twice ~1 s after resume (outputs recreated, the LG came
back on a new DP connector) and once as suspend began (fprintd: "Cannot run while
suspended"). Crashing thread: a std::thread calling abort() directly.

- Upstream (checked 2026-11-03): this is hyprwm/hyprlock#1064, open. The Wayland
  poll thread asserts (`hyprlock.cpp:414`, "Disconnected from pollfd") when outputs
  are recreated; same stack as ours (std::thread -> abort, main thread on a condvar).
  Reported on 0.9.6 too, including AMD + s2idle, so NOT a 0.9.7 regression and
  downgrading won't help. Related: #1080 (open PR, output races), #1082.
- Our trigger is output hotplug while locked, not only resume: 23:04, 00:05 and 08:15
  crashes each hit at a DMUB HPD event / Thunderbolt disconnect of the LG, no suspend.
  Fixing the LG blinking (cable) should also cut the crashes.
- [ ] Workaround from #1064 is on (see below). Crashes still in `coredumpctl list
      hyprlock` after a week? Revert it. Comment on #1064 with our AMD + hotplug data.
- Mitigations in place: docked + powered laptops no longer sleep (`lid-hold.sh`), so
  the resume path is rarely hit; `lock-watchdog.sh` relaunches hyprlock whenever it
  dies while the session is locked (logged as `hyprlock-restore` in the journal);
  `quirks.skip_non_kms_dmabuf_formats = false` set 2026-11-03 (#1064 workaround);
  manual recovery from a TTY: `~/.config/hypr/scripts/restore-lock.sh`.

## Replace Shokz OpenMeet with Logitech Zone Wired 2 (wired USB-C headset)

Buying: Logitech Zone Wired 2, Teams version, off-white (981-001621), from digitec.

When it arrives:

- [ ] Plug it in and confirm it shows up as a USB audio device (`wpctl status`).
- [ ] Check the inline/Teams buttons don't emit odd key codes: `sudo evtest`, pick the
      Logitech device, press each button. If anything sends `KEY_POWER` (or similar),
      add a udev rule dropping the `power-switch` tag (see Background).
- [ ] Do a test recording with the kids playing nearby, to confirm the headset's AI mic
      noise suppression works without Logi Tune (Windows/macOS only). Fallback:
      EasyEffects with DeepFilterNet/RNNoise on the mic input. Within the return
      window, return it if it's not good enough.
- [ ] Set it as default sink/source in WirePlumber.
- [ ] Remove `.config/wireplumber/wireplumber.conf.d/51-shokz-headset-only.conf`
      (and unpair the Shokz from the laptop if it's no longer used here).

## Background (2026-10-07)

The Shokz OpenMeet (Bluetooth, `A8:F5:E1:F2:DD:D6`) kept dropping on the Framework 13's
MT7925 Bluetooth chip. Starting in A2DP and auto-switching to HFP for calls failed
("Failure in Bluetooth audio transport", "corrupted SCO packet"). Forcing HFP-only via
`51-shokz-headset-only.conf` removed the switch, but HFP uses SCO links, which are the
fragile part on this chip (Wi-Fi/Bluetooth coexistence, MediaTek firmware).

Options considered:

- **Separate USB mic + Shokz on A2DP only**: would avoid SCO, but a desk mic (including
  the RODE NT-USB Mini I already have) is too far away to reject kids' voices and
  keyboard noise. Kids talking is speech, which noise suppression keeps, so only a mic
  close to the mouth (boom) reliably rejects it.
- **Shokz Loop120 USB dongle (CL120C)**: compatible with the OpenMeet and works on Linux
  as USB audio, but the dongle (USB `3511:2f06`) sends phantom `KEY_POWER` events. With
  logind's default `HandlePowerKey=poweroff` this would likely shut the laptop down. It
  needs a udev rule, e.g. `/etc/udev/rules.d/71-shokz-loop120.rules`:
  `SUBSYSTEM=="input", ATTRS{idVendor}=="3511", ATTRS{idProduct}=="2f06|2ef2|2b1e", TAG-="power-switch"`
- **Wired USB headset with noise-cancelling boom mic**: chosen. No Bluetooth at all,
  mic close to the mouth, plus ANC for my own ears. Teams vs UC versions use the same
  hardware; the Teams button is just useless on Linux.
