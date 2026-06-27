# SAVEGAME — dotfiles overhaul (handoff)

_Last updated: 2026-06-27_

Working dir: `~/dotfiles` (this repo). Host is Arch-family (Hyprland/Wayland, fish,
rootless podman). Current machine is a **desktop** (single 3840x1600 monitor on
`HDMI-A-1`, no battery). Target machines also include a **Framework 13 (AMD)** laptop
and possibly an **Nvidia desktop**.

## Big picture / architecture

Three "lanes" for development, by isolation level:

| Lane | Tool | Sees | Used for |
|------|------|------|----------|
| Host | native pacman | everything | quick edits, native GUI apps, lazygit |
| `arch-dev` | **distrobox** | `$HOME` + display/GPU | **IntelliJ Ultimate**, JVM/Scala/Kotlin, general toolchains |
| `nvim-box` | **podman** | only nvim config (ro) + cwd | strict-isolation TUI neovim editing |

Key decision: **distrobox = integration (GUI apps, shares home); podman = isolation.**
distrobox cannot restrict mounts, so the isolated nvim uses raw rootless podman.
Containers are **Arch-based on purpose** so glibc matches the host (treesitter parser /
binary ABI compatibility).

Python: **uv** everywhere (not pip) — saved as a preference in agent memory.

---

## What's DONE and VERIFIED ✅

### nvim-box (podman, isolated neovim) — built & smoke-tested end to end
Files: `nvim-box/Containerfile`, `nvim-box/nvim-box` (launcher), `nvim-box/entrypoint.sh`.

- Image `localhost/nvim-box:latest` builds clean (~5.1 GB), launcher installed to
  `~/.local/bin/nvim-box` by install.sh; `~/.local/bin` added to fish PATH.
- **Isolation model (final design):** host `~/.config/nvim` is mounted **read-only as a
  seed at `/seed/nvim`**; the entrypoint `rsync`s it into the box's own writable copy in a
  persistent named volume `nvim-box-home` (mounted at `/home/dev`). The box therefore uses
  your real config + **your locked plugin versions** but **never writes back** to the host
  config or `lazy-lock.json`. cwd is mounted at `/work`. `--userns=keep-id` so files are
  owned by you.
- One home volume holds plugins, treesitter parsers, Mason, AND all language caches
  (cargo/go/coursier/sbt/npm/uv) — persists across runs, isolated from host home.
- **Claude auto-login:** only `~/.claude/.credentials.json` is mounted (not all of
  `~/.claude`), so `claude` is logged in while projects/sessions stay isolated.
- Verified: 43 plugins install, a treesitter parser compiles (gcc present), nvim-treesitter
  is at the **locked `master` commit cf12346** (NOT the broken `main` rewrite), and the host
  `lazy-lock.json` stays **clean/untouched**. `claude` 2.1.193 logged in. Config read-only.
- Toolchain present & on PATH: nvim, Go(gopls/goimports), Rust(rust-analyzer/cargo),
  Python(pyright/ruff/uv), Lua(lua-ls/stylua), TS/Vue(ts_ls/prettier), JVM(jdk/kotlinc/
  **sbt**/coursier/**google-java-format**/Metals-via-coursier), lazygit, ripgrep, fd, claude.

Usage: `nvim-box [file]` from any project dir.

### install.sh — cleaned up and hardened
- **AUR helper indirection**: auto-detects `yay`→`paru`, override with `AUR_HELPER=paru`
  (so it runs on Arch/Endeavour AND CachyOS, which ships paru).
- Removed dead code (old rust-toolchain block, mise install blocks, mise/rig tail block).
- Added packages: `socat` (hypr monitor hotplug), `lazygit`, `distrobox`.
- **Laptop detection block** (battery under `/sys/class/power_supply/BAT*`): installs
  `brightnessctl upower fwupd fprintd libfprint` (and `thermald` only if Intel CPU). AMD
  uses in-kernel amd_pstate via power-profiles-daemon — no extra pkg. `brightnessctl` moved
  out of the Hyprland section into this gate. Service enablement added for thermald +
  fwupd-refresh.timer (gated by is_installed → desktop skips).
- Builds the nvim-box image (idempotent) and assembles the arch-dev distrobox (idempotent,
  skipped if it exists).
- Commented-out packages in the array were intentionally kept (per user). `rustup` is
  currently commented out.

### Hyprland dynamic monitors — works on current desktop
Files: `.config/hypr/scripts/monitors.sh`, `.config/hypr/scripts/monitor-watch.sh`;
wired via `exec-once` in `.config/hypr/hyprland.conf` (catch-all `monitor=,preferred,auto,
auto` kept as a safety net).

- Logic: external **3840x1600** or **4K (3840x2160)** → drive at native res, **laptop panel
  OFF**; otherwise (no external / unknown res) → **laptop panel ON**. Desktop (no eDP) just
  drives its monitor. **Every** monitor uses its **highest advertised refresh rate**.
- `monitor-watch.sh` listens on Hyprland's socket2 (via `socat`) and re-runs the layout on
  hotplug. Both are started by `exec-once`.
- Verified live on this desktop: `HDMI-A-1` driven at `3840x1600@75Hz`, exit 0.
- Bugs fixed during testing: `set -e` + non-matching grep aborting the script; non-zero exit
  on the no-eDP path.

### Lid / power (logind) — confirmed correct (reasoned, not yet tested on hardware)
- `system/etc/systemd/logind.conf.d/99-lid.conf`: `HandleLidSwitch=suspend`,
  `HandleLidSwitchExternalPower=suspend`, `HandleLidSwitchDocked=ignore`. So undocked lid
  close → suspend; docked (external connected) → ignore (and monitors.sh turns the panel
  off). Wake on lid open is firmware-default. hypridle locks before sleep (`loginctl
  lock-session`) and dpms-on after. No competing lid binding in hyprland.conf.
- This file is deployed to `/etc` by install.sh's `sudo install -D` block (NOT by stow), and
  needs `sudo systemctl restart systemd-logind` or reboot to take effect.

### Stow hygiene
- Added `.stow-local-ignore` (replaces stow's built-in default list, so git/editor defaults
  are re-included). Ignores: `system`, `nvim-box`, `distrobox`, `install.sh`,
  `docker_to_podman.sh`, `hyprland.md`, `VIM.md`, `README.md`, `SAVEGAME.md`.
- Removed the stray `~/system`, `~/install.sh`, `~/hyprland.md`, `~/VIM.md`,
  `~/docker_to_podman.sh` symlinks stow had created.

---

## What's BUILT BUT NOT YET TESTED ⚠️

### arch-dev distrobox (GUI/JVM + IntelliJ) — files written, NOT assembled/run
Files: `distrobox/distrobox.ini`, `distrobox/setup.sh`.

- Arch box. `additional_packages`: base-devel, git, gradle, kotlin, scala? (NO — see
  gotchas; uses kotlin + the AUR pieces), maven, rustup, go, node/npm, **uv**, ripgrep, fd,
  fonts. `init_hooks` runs `setup.sh` as the box user (uid 1000) which bootstraps **paru**
  then installs AUR: `intellij-idea-ultimate-edition`, `jdk21-temurin`, `coursier`, `sbt`,
  `claude-code`. `exported_apps=intellij-idea-ultimate-edition`.
- **Not built yet.** Build with:
  `distrobox assemble create --file ~/dotfiles/distrobox/distrobox.ini`
- Risks to verify on first build: (1) paru bootstrap as user in init_hooks (makepkg can't run
  as root — setup.sh re-execs as the uid-1000 user); (2) the `exported_apps` desktop-file
  name — if IntelliJ doesn't appear in the host launcher, the .desktop is named differently;
  fix with `distrobox-export --app <name>` from inside the box.
- `nvidia=false` in the ini — **flip to true on the Nvidia desktop.**

---

## OPEN TODO / next steps

1. **Build & test arch-dev distrobox** (the paru/IntelliJ/export path is unverified).
2. **kotlin-lsp in nvim-box**: not installed (no stable public URL). Rebuild with
   `--build-arg KOTLIN_LSP_URL=<zip>` when a URL is known. Everything else Kotlin works.
   (Alternative: switch config to the community `kotlin-language-server` — different binary
   name, one-line change in `lspconfig.lua`.)
3. **Framework 13 validation** (on the actual laptop): lid suspend/resume; confirm internal
   panel enumerates as `eDP-*` (monitors.sh matches the prefix); confirm laptop power pkgs
   install (battery detection).
4. **Nvidia desktop**: set `nvidia=true` in `distrobox/distrobox.ini`; nvidia-dkms needs
   matching kernel headers (esp. on CachyOS: `linux-cachyos-headers`).
5. **Hyprland config gaps** (pre-existing, flagged):
   - `$fileManager = dolphin` (Mod+E) but dolphin isn't installed → either add `dolphin` or
     repoint to `kitty -e yazi` (yazi IS installed but currently unused).
   - `nmtui` (Mod+W, waybar network) needs `networkmanager` — not in package list.
   - `power-profiles-daemon` sits in the Hyprland section but is a system service (cosmetic).
6. Optional: fingerprint PAM wiring (fprintd installed but enrollment/PAM not configured).
7. Run full `install.sh` on a target machine to validate end-to-end.

---

## Key learnings / gotchas (so we don't relitigate)

- **There is no `scala` package** on Arch. Scala = JDK + sbt (sbt bootstraps the per-project
  Scala version); Metals self-installs via coursier. `sbt` and `kotlin` ARE in official repos;
  `coursier`, `scala`, `intellij-idea-ultimate-edition`, `jdk21-temurin` are AUR.
- **RO-mounting the nvim config breaks lazy.nvim** (can't write lazy-lock.json → aborts
  plugin install). Solution = seed-copy into a writable volume via the entrypoint; never
  bind the lockfile RW (that silently rewrote the host lock and bumped nvim-treesitter to the
  breaking `main` branch — reverted).
- **`--userns=keep-id` is required** both to own files in `/work` and to read the
  `nvim-box-home` volume; verification commands that omit it get "permission denied" and
  falsely report empty.
- distrobox shares the whole `$HOME` + `/run/host`; it cannot be restricted to a minimal
  mount set — that's why isolation uses podman.
- When backgrounding a build, don't pipe podman through `tee|tail` — the reported exit code
  becomes tail's, masking build failures. Run podman directly, redirect to a log.

## Map of files changed/created in this effort
- `install.sh` (AUR helper, laptop block, dead-code removal, box build/assemble)
- `.stow-local-ignore` (new)
- `.config/hypr/hyprland.conf` (monitor exec-once)
- `.config/hypr/scripts/monitors.sh`, `monitor-watch.sh` (new)
- `.config/fish/config.fish` (`~/.local/bin` on PATH)
- `nvim-box/Containerfile`, `nvim-box/nvim-box`, `nvim-box/entrypoint.sh` (new)
- `distrobox/distrobox.ini`, `distrobox/setup.sh` (new)
- agent memory: `python-uv-preference`
