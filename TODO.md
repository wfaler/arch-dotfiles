# TODO

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
