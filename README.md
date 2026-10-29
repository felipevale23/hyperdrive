<h1 align="center">hyperdrive</h1>

<p align="center">
  Zero-to-Hyprland Arch spin. A custom archiso + installer that lands you on a
  fully configured <a href="https://github.com/end-4/dots-hyprland">end-4</a>
  desktop — Dracula, GRUB (Elegant/mojave), Docker, and a set of Quickshell &
  keybind patches.
</p>

---

## What you get

- **Session** — Hyprland (end-4 *illogical-impulse* Lua config) + Quickshell shell
- **GPU** — `hyperdrive-setup` autodetects via `lspci`: Mesa + Vulkan for
  AMD/Intel; `nvidia-lts` + DRM modeset, initramfs modules, a rebuild hook and
  Wayland env vars for NVIDIA (incl. hybrid). Override with
  `HYPERDRIVE_GPU=amd|intel|nvidia|none` (space-separate for hybrids)
- **Login** — SDDM, `sugar-dark` theme
- **Boot** — GRUB with the Elegant *mojave / window / left / dark* theme, btrfs `@`
  subvol layout, `linux-lts` + microcode, a pacman hook that keeps `grubx64.efi` current
- **Shell** — zsh (ML4W loader + zinit + oh-my-posh), `spaceship.omp.toml` prompt with
  Konsole-only icon padding, `~/.zshrc_custom`, secrets in `~/.zshrc_secrets` (never committed)
- **Terminal** — kitty, Windows-style `Ctrl+C`/`Ctrl+V` (still SIGINT with no selection);
  Konsole styled to match (same Dracula colors, font, padding, beam cursor, no scrollbar)
- **CLI** — zoxide, eza, bat, fzf, fd, ripgrep, jq, bottom, btop, zinit (pre-seeded)
- **Dev** — nodejs/npm/yarn, python + pip/pipx, rustup (stable toolchain),
  `asdf-vm` for per-project versions, neovim + LunarVim (`lvim`)
- **TeX** (opt-in, `HYPERDRIVE_TEX=1`) — TeX Live (XeLaTeX + biblatex/biber +
  latexmk), zathura, and [`texflow`](https://github.com/felipevale23/texflow)
- **Apps** — Dolphin (default file manager, `Super+E`; nautilus kept as fallback),
  Konsole, kcalc, KDE Connect (autostarts via `custom/execs.lua`)
- **Window title bars** — `hyprbars` (AUR `hyprland-plugin-hyprbars`) with
  minimize / maximize / close; maximized windows drop theirs (`custom/rules.lua`)
- **Global app menu** — the focused Qt/KDE app's menus (File, Edit, View…) in the
  top bar, macOS-style. Hyprland lacks KDE's appmenu protocol, so
  `~/.local/bin/appmenu` stands in a `com.canonical.AppMenu.Registrar` and reads the
  menus over DBus. Qt/KDE apps only; apps started before it need a restart
- **Dock** — unpinned: hidden until you hover the bottom edge
- **Containers** — Docker CE, `overlay2` pinned (btrfs root)
- **Custom patches** (`patches/quickshell/`):
  - media-controls popup anchors under the bar widget
  - `overviewWorkspacesOpen` global shortcut
  - month calendar in the clock hover popup
  - media widget moved to the right of the bar
  - bar window title fixed on single/non-zero-id monitors (was always "Desktop")
  - hover the window title to swap in macOS-style close / minimize / maximize
    buttons; the app menu sits beside it
- **Custom keybind** — Windows-style `Alt+Tab` workspace switcher (`dotfiles/.config/hypr/custom/`):
  tap = flip to previous workspace; hold Alt + tab = overview picker cycling only
  non-empty workspaces; an evdev watcher closes it on Alt release

## Layout

```
iso/          archiso profile (profiledef, pacman.conf, packages.x86_64, airootfs/)
dotfiles/     config tree deployed into $HOME by the installer (NOT baked into airootfs)
system/       files that go to / on the installed system (grub, docker, sddm, hooks)
patches/      diffs against a pinned end-4 (see postinstall.sh: END4_REF)
packages/     PKGBUILDs — hyperdrive-desktop (meta) + hyperdrive-dotfiles
scripts/      build.sh (mkarchiso), live-install.sh (guided ISO installer =
              hyperdrive-install), postinstall.sh (= hyperdrive-setup), apply-dotfiles.sh
```

## Build the ISO

```sh
sudo pacman -S --needed archiso grub
sudo ./scripts/build.sh            # -> dist/hyperdrive-YYYY.MM.DD-x86_64.iso
```

CI builds it weekly + on push (`.github/workflows/build-iso.yml`, privileged
Arch container). Tagged pushes attach the ISO to a GitHub Release.

## Install

1. Boot the ISO. Live helpers: `hyperdrive-wifi` (Wi-Fi), `hyperdrive-keymap`
   (console layout), `hyperdrive-locale`. Get online before step 2.
2. Run the guided installer:
   ```sh
   hyperdrive-install
   ```
   It wipes **one** disk (GPT/UEFI), lays out btrfs `@ @home @log @pkg
   @snapshots`, pacstraps a minimal base with GRUB + NetworkManager, creates
   your user, and copies the hyperdrive tree into the new system. For
   encryption, RAID, BIOS/MBR, or manual partitioning, use `archinstall`
   instead and copy `/usr/local/share/hyperdrive` to `/mnt` yourself.
3. Reboot, log in as your user, then:
   ```sh
   hyperdrive-setup         # end-4 + patches + dotfiles + GPU + GRUB theme + services
   # GPU is autodetected; override with e.g. HYPERDRIVE_GPU=nvidia hyperdrive-setup
   # add the TeX Live + texflow stack with HYPERDRIVE_TEX=1 hyperdrive-setup
   ```
4. Put your tokens in `~/.zshrc_secrets` (see `~/.zshrc_secrets.example`), reboot.

## Updating against upstream end-4

`patches/quickshell/*.patch` are `-p1` diffs against `END4_REF` in
`scripts/postinstall.sh`. When bumping end-4:

```sh
git -C ~/dots-hyprland checkout <new-ref>
cd ~/.config/quickshell/ii
for p in patches/quickshell/*.patch; do patch -p1 --dry-run < "$p"; done   # check
# regenerate any that fail, bump END4_REF
```

Upstreamable bits (shrink the patch set): the media-popup anchor fix, the
`overviewWorkspacesOpen` shortcut, the clock-popup calendar.

## Security

See [SECURITY.md](SECURITY.md). No secrets, no default passwords, no machine
identity in this repo — run the secret scan before every push.

## Status

`v0` scaffold. TODO: `[hyperdrive]` signed pacman repo from CI, QEMU smoke-boot
test, disk-encryption (LUKS) option in the guided installer.

## License

MIT. Built on [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland),
[vinceliuice/Elegant-grub2-themes](https://github.com/vinceliuice/Elegant-grub2-themes),
[MarianArlt/sddm-sugar-dark](https://github.com/MarianArlt/sddm-sugar-dark).
