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
- **Shell** — zsh (ML4W loader + zinit + oh-my-posh), `~/.zshrc_custom`, secrets in
  `~/.zshrc_secrets` (never committed)
- **Terminal** — kitty, Windows-style `Ctrl+C`/`Ctrl+V` (still SIGINT with no selection)
- **Containers** — Docker CE, `overlay2` pinned (btrfs root)
- **Custom patches** (`patches/quickshell/`):
  - media-controls popup anchors under the bar widget
  - `overviewWorkspacesOpen` global shortcut
  - month calendar in the clock hover popup
  - media widget moved to the right of the bar
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

1. Boot the ISO, connect network (`nmtui` or `iwctl`).
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
   # GPU is autodetected; force it with e.g. HYPERDRIVE_GPU=nvidia hyperdrive-setup
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
