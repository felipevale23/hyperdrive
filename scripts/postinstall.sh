#!/usr/bin/env bash
# hyperdrive post-install — run ONCE on the freshly installed target system as
# the normal user (it uses sudo where needed).
#
#   hyperdrive-setup             # installed there by the guided installer, or
#   /usr/local/share/hyperdrive/postinstall.sh
set -euo pipefail

SHARE="/usr/local/share/hyperdrive"
END4_REF="2026.05.11-133-g97c5bc65"   # pin: patches in patches/quickshell/ are against this

[[ $EUID -ne 0 ]] || { echo "run as your normal user, not root"; exit 1; }

msg() { printf '\n\033[1;35m:: %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
msg "base packages"
sudo pacman -S --needed --noconfirm \
    base-devel git rsync pciutils \
    hyprland sddm kitty pipewire pipewire-pulse wireplumber wl-clipboard \
    docker docker-buildx docker-compose \
    grub efibootmgr \
    zsh zoxide eza bat fzf bottom btop jq neovim \
    ttf-fira-code ttf-firacode-nerd ttf-jetbrains-mono-nerd \
    ttf-meslo-nerd ttf-nerd-fonts-symbols \
    noto-fonts noto-fonts-emoji ttf-liberation \
    qt5-declarative qt5-graphicaleffects qt5-quickcontrols2 qt5-svg \
    python

# ---------------------------------------------------------------------------
msg "GPU drivers"
# autodetected from lspci; override with HYPERDRIVE_GPU=amd|intel|nvidia|none
# (space-separate for hybrids, e.g. HYPERDRIVE_GPU="intel nvidia")
gpu_info="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible controller|3d controller|display controller' || true)"
printf '%s\n' "$gpu_info"

sel="${HYPERDRIVE_GPU:-auto}"
if [[ "$sel" == auto ]]; then
    sel=""
    # match on PCI vendor IDs (reliable): NVIDIA 10de, AMD/ATI 1002/1022, Intel 8086
    grep -qiE '\[10de:'                            <<<"$gpu_info" && sel+=" nvidia"
    grep -qiE '\[1002:|\[1022:'                    <<<"$gpu_info" && sel+=" amd"
    grep -qiE '\[8086:'                            <<<"$gpu_info" && sel+=" intel"
    grep -qiE 'virtio|qxl|vmware|cirrus|bochs|\[1234:|\[1af4:|\[15ad:' <<<"$gpu_info" && sel+=" vm"
    [[ -z "${sel// /}" ]] && sel="vm"
fi
echo ":: GPU: ${sel# }"

nvidia=""
gpu_pkgs=(vulkan-icd-loader)
case "$sel" in
  *none*) gpu_pkgs=() ;;
  *)
    gpu_pkgs+=(mesa)
    [[ "$sel" == *nvidia* ]] && { gpu_pkgs+=(nvidia-lts nvidia-utils libva-nvidia-driver egl-wayland); nvidia=1; }
    [[ "$sel" == *amd*    ]] && gpu_pkgs+=(vulkan-radeon libva-mesa-driver)
    [[ "$sel" == *intel*  ]] && gpu_pkgs+=(vulkan-intel intel-media-driver)
    [[ "$sel" == *vm*     ]] && gpu_pkgs+=(vulkan-swrast)
    ;;
esac

if [[ -n "${gpu_pkgs[*]:-}" ]]; then
    mapfile -t gpu_pkgs < <(printf '%s\n' "${gpu_pkgs[@]}" | awk '!seen[$0]++')
    echo ":: installing ${gpu_pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${gpu_pkgs[@]}"
fi

if [[ -n "$nvidia" ]]; then
    msg "NVIDIA: DRM modeset + initramfs + Wayland env"
    printf 'options nvidia_drm modeset=1 fbdev=1\noptions nvidia NVreg_PreserveVideoMemoryAllocations=1\n' \
        | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

    grep -q nvidia_drm /etc/mkinitcpio.conf || sudo sed -i \
        's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    # pure NVIDIA -> keep nouveau out of early KMS; hybrid -> keep kms for the iGPU
    [[ "$sel" == *amd* || "$sel" == *intel* ]] || sudo sed -i '/^HOOKS=/ s/ kms//' /etc/mkinitcpio.conf

    sudo tee /etc/pacman.d/hooks/95-nvidia.hook >/dev/null <<'HOOK'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-lts
Target=linux-lts
[Action]
Description=Rebuilding initramfs (NVIDIA)...
When=PostTransaction
Exec=/usr/bin/sh -c 'mkinitcpio -P'
HOOK

    grep -q LIBVA_DRIVER_NAME /etc/environment 2>/dev/null || printf \
        '\n# hyperdrive: NVIDIA on Wayland\nLIBVA_DRIVER_NAME=nvidia\n__GLX_VENDOR_LIBRARY_NAME=nvidia\nNVD_BACKEND=direct\n' \
        | sudo tee -a /etc/environment >/dev/null

    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service || true
    sudo mkinitcpio -P
    echo ":: nvidia-lts is pinned to the linux-lts kernel — if you add mainline"
    echo "   'linux' later, also install 'nvidia'."
fi

# ---------------------------------------------------------------------------
msg "developer toolchain"
sudo pacman -S --needed --noconfirm \
    nodejs npm yarn \
    python-pip python-pipx \
    rustup \
    ripgrep fd unzip wget

# rust: pull the stable toolchain (harmless if one is already the default)
rustup show active-toolchain >/dev/null 2>&1 || rustup default stable \
    || echo "  rustup: run 'rustup default stable' once you're online"

# zinit — the .zshrc_custom loads it; pre-seed so the first shell is instant
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ -d "$ZINIT_HOME" ]] || git clone --depth 1 \
    https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"

# ---------------------------------------------------------------------------
msg "extra apps (KDE utils, Dolphin, Konsole, KDE Connect)"
sudo pacman -S --needed --noconfirm \
    xdg-utils \
    dolphin dolphin-plugins ark kio-extras kdegraphics-thumbnailers \
    konsole kcalc \
    kdeconnect sshfs \
    python-gobject   # ~/.local/bin/appmenu (global app menu in the top bar)

# Dolphin as the default file manager (end-4 ships nautilus — kept as fallback)
xdg-mime default org.kde.dolphin.desktop inode/directory || true

# ---------------------------------------------------------------------------
# TeX Live + TeXFlow — opt in with:  HYPERDRIVE_TEX=1 hyperdrive-setup
if [[ -n "${HYPERDRIVE_TEX:-}" ]]; then
    msg "TeX Live + TeXFlow (HYPERDRIVE_TEX set)"
    sudo pacman -S --needed --noconfirm \
        texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra \
        texlive-xetex texlive-fontsrecommended texlive-fontsextra \
        texlive-bibtexextra texlive-binextra texlive-plaingeneric \
        biber uv zathura zathura-pdf-mupdf

    if ! command -v texflow >/dev/null; then
        # 1) prebuilt binary — the project's recommended install
        if curl -fL --retry 2 -o /tmp/texflow \
            https://github.com/felipevale23/texflow/releases/latest/download/texflow-linux-x86_64 \
            && [[ -s /tmp/texflow ]]; then
            sudo install -Dm755 /tmp/texflow /usr/local/bin/texflow
            rm -f /tmp/texflow
        else
            # 2) fall back to a from-source install with uv
            rm -f /tmp/texflow
            uv tool install --python 3.12 git+https://github.com/felipevale23/texflow.git \
                || echo "  TeXFlow install failed — see github.com/felipevale23/texflow"
        fi
    fi
    command -v texflow >/dev/null \
        && echo "  texflow -> $(command -v texflow)" \
        || echo "  texflow not on PATH yet — restart your shell"
fi

# ---------------------------------------------------------------------------
msg "AUR helper (paru) + AUR packages"
if ! command -v paru >/dev/null; then
    tmp="$(mktemp -d)"; git clone https://aur.archlinux.org/paru-bin.git "$tmp"
    ( cd "$tmp" && makepkg -si --noconfirm ); rm -rf "$tmp"
fi
# hyprland-plugin-hyprbars: window title bars (loaded in custom/execs.lua); it
# pins the Hyprland minor version, so rebuild it after Hyprland updates
paru -S --needed --noconfirm sddm-sugar-dark oh-my-posh-bin asdf-vm hyprland-plugin-hyprbars || true

# ---------------------------------------------------------------------------
msg "LunarVim (lvim — the dotfiles set EDITOR=lvim, alias vim=lvim)"
if ! command -v lvim >/dev/null; then
    LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -fsSL \
        https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) \
        --no-install-dependencies --yes \
        || echo "  LunarVim install failed — 'lvim' will be missing. Upstream is
  unmaintained; consider LazyVim / kickstart.nvim and updating the dotfiles."
fi

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
msg "end-4 settings"
# dock hides until hovered (end-4 default pins it open)
II_CONF="$HOME/.config/illogical-impulse/config.json"
if [[ -f "$II_CONF" ]]; then
    tmp="$(mktemp)"
    jq '.dock.pinnedOnStartup = false' "$II_CONF" > "$tmp" && cat "$tmp" > "$II_CONF"
    rm -f "$tmp"
fi
# keep Konsole on the dotfiles' Kitty colorscheme: kde-material-you-colors
# otherwise rewrites the profile's ColorScheme on every wallpaper change
KMYC_CONF="$HOME/.config/kde-material-you-colors/config.conf"
if [[ -f "$KMYC_CONF" ]]; then
    if grep -qE '^[#[:space:]]*disable_konsole[[:space:]]*=' "$KMYC_CONF"; then
        sed -i -E 's/^[#[:space:]]*disable_konsole[[:space:]]*=.*/disable_konsole = True/' "$KMYC_CONF"
    else
        printf '\ndisable_konsole = True\n' >> "$KMYC_CONF"
    fi
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

# the guided installer leaves a first-boot hint in /etc/motd; clear it now
sudo rm -f /etc/motd

msg "done — log out/in (or reboot) so the docker+input groups take effect."
echo "     Add your tokens to ~/.zshrc_secrets (see ~/.zshrc_secrets.example)."
