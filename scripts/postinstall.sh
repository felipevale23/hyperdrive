#!/usr/bin/env bash
# hyperdrive post-install — run ONCE on the freshly installed target system as
# the normal user (it uses sudo where needed).
#
#   hyperdrive-install            # from the live ISO's installer, or
#   /usr/local/share/hyperdrive/postinstall.sh
set -euo pipefail

SHARE="/usr/local/share/hyperdrive"
END4_REF="2026.05.11-133-g97c5bc65"   # pin: patches in patches/quickshell/ are against this

[[ $EUID -ne 0 ]] || { echo "run as your normal user, not root"; exit 1; }

msg() { printf '\n\033[1;35m:: %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
msg "base packages"
sudo pacman -S --needed --noconfirm \
    base-devel git rsync \
    hyprland sddm kitty pipewire pipewire-pulse wireplumber wl-clipboard \
    docker docker-buildx docker-compose \
    grub efibootmgr \
    zsh zoxide eza bat fzf bottom btop jq neovim \
    ttf-fira-code ttf-firacode-nerd ttf-meslo-nerd ttf-nerd-fonts-symbols \
    noto-fonts noto-fonts-emoji ttf-liberation \
    qt5-declarative qt5-graphicaleffects qt5-quickcontrols2 qt5-svg \
    python

# ---------------------------------------------------------------------------
msg "AUR helper (paru) + AUR packages"
if ! command -v paru >/dev/null; then
    tmp="$(mktemp -d)"; git clone https://aur.archlinux.org/paru-bin.git "$tmp"
    ( cd "$tmp" && makepkg -si --noconfirm ); rm -rf "$tmp"
fi
paru -S --needed --noconfirm sddm-sugar-dark oh-my-posh-bin lazyvim || true

# ---------------------------------------------------------------------------
msg "end-4 illogical-impulse (Hyprland shell + Quickshell)"
if [[ ! -d "$HOME/dots-hyprland" ]]; then
    git clone https://github.com/end-4/dots-hyprland "$HOME/dots-hyprland"
fi
git -C "$HOME/dots-hyprland" fetch --tags
git -C "$HOME/dots-hyprland" checkout "$END4_REF"
( cd "$HOME/dots-hyprland" && ./install.sh )   # interactive; follow prompts

# ---------------------------------------------------------------------------
msg "apply hyperdrive quickshell patches"
QSDIR="$HOME/.config/quickshell/ii"
if [[ -d "$QSDIR" ]]; then
    for p in "$SHARE"/patches/quickshell/*.patch; do
        if patch -d "$QSDIR" -p1 --forward --dry-run < "$p" >/dev/null 2>&1; then
            patch -d "$QSDIR" -p1 --forward < "$p"
            echo "  applied $(basename "$p")"
        else
            echo "  SKIP  $(basename "$p") (already applied or upstream moved)"
        fi
    done
fi

# ---------------------------------------------------------------------------
msg "dotfiles + system config"
"$SHARE/apply-dotfiles.sh"

sudo install -Dm644 "$SHARE/system/etc/docker/daemon.json"              /etc/docker/daemon.json
sudo install -Dm644 "$SHARE/system/etc/sddm.conf.d/10-theme.conf"       /etc/sddm.conf.d/10-theme.conf
sudo install -Dm644 "$SHARE/system/etc/pacman.d/hooks/95-grub-efi.hook" /etc/pacman.d/hooks/95-grub-efi.hook
sudo install -Dm644 "$SHARE/system/etc/default/grub"                    /etc/default/grub

# ---------------------------------------------------------------------------
msg "GRUB theme (Elegant / mojave)"
if [[ ! -d /usr/share/grub/themes/Elegant-mojave-window-left-dark ]]; then
    tmp="$(mktemp -d)"
    git clone --depth 1 https://github.com/vinceliuice/Elegant-grub2-themes "$tmp"
    sudo "$tmp"/install.sh -t mojave -p window -i left -c dark -s 1080p
    rm -rf "$tmp"
fi
sudo grub-mkconfig -o /boot/grub/grub.cfg

# ---------------------------------------------------------------------------
msg "services"
sudo systemctl enable --now docker
sudo systemctl enable sddm
# docker: rootless-equivalent socket access. input: raw /dev/input/event* reads
# for the Alt-Tab watcher (dotfiles/.config/hypr/custom/scripts/alt-release-watch.py).
sudo usermod -aG docker,input "$USER"

msg "done — log out/in (or reboot) so the docker+input groups take effect."
echo "     Add your tokens to ~/.zshrc_secrets (see ~/.zshrc_secrets.example)."
