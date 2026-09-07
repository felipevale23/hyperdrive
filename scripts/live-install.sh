#!/usr/bin/env bash
# hyperdrive guided installer — run in the LIVE ISO as root.
#
#   hyperdrive-install
#
# Partitions ONE disk (GPT/UEFI), lays out btrfs @ subvolumes, pacstraps a
# minimal base with GRUB + NetworkManager, creates your user, and copies the
# hyperdrive tree into the new system so `hyperdrive-setup` can finish the
# desktop on first boot.
#
# For encryption, RAID, BIOS/MBR, or manual partitioning, use `archinstall`
# instead and copy /usr/local/share/hyperdrive to /mnt yourself.
set -euo pipefail

SHARE="/usr/local/share/hyperdrive"
MNT="/mnt"

die() { printf '\n\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
msg() { printf '\n\033[1;35m:: %s\033[0m\n' "$*"; }
ask() { local p="$1" d="${2:-}" r; read -rp "$p${d:+ [$d]}: " r; printf '%s' "${r:-$d}"; }
askpw() {
    # prompts + newlines go to stderr so only the password lands on stdout
    local label="$1" a b
    while :; do
        read -rsp "$label: " a; echo >&2
        read -rsp "repeat: "  b; echo >&2
        [[ -n "$a" && "$a" == "$b" ]] && { printf '%s' "$a"; return; }
        echo "  empty or mismatch — try again" >&2
    done
}

cleanup() { umount -R "$MNT" 2>/dev/null || true; }
trap 'echo; echo "aborted."; cleanup; exit 1' INT
trap cleanup EXIT

# --- preflight -------------------------------------------------------------
[[ $EUID -eq 0 ]]                  || die "run as root"
[[ -d /sys/firmware/efi/efivars ]] || die "not booted in UEFI mode — use archinstall for BIOS/MBR"
[[ -d /run/archiso ]]              || echo "warning: this does not look like the hyperdrive live ISO"
for c in sgdisk pacstrap arch-chroot genfstab mkfs.btrfs mkfs.fat wipefs partprobe curl; do
    command -v "$c" >/dev/null || die "missing required tool: $c"
done
curl -fsS --max-time 8 -o /dev/null https://archlinux.org \
    || die "no network — run 'hyperdrive-wifi' (or nmtui / iwctl), then re-run"

# --- target disk ----------------------------------------------------------
msg "available disks"
lsblk -dpno NAME,SIZE,MODEL | grep -vE 'loop|/dev/sr' || true
DISK="$(ask 'Disk to ERASE (e.g. /dev/nvme0n1 or /dev/sda)')"
[[ -b "$DISK" ]] || die "$DISK is not a block device"

part() { case "$1" in *[0-9]) echo "${1}p${2}";; *) echo "${1}${2}";; esac; }
ESP="$(part "$DISK" 1)"
ROOT="$(part "$DISK" 2)"

echo
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$DISK"
printf '\n\033[1;31mEVERYTHING ON %s WILL BE DESTROYED.\033[0m\n' "$DISK"
[[ "$(ask 'Type ERASE to confirm')" == "ERASE" ]] || die "cancelled"

# --- system identity ----------------------------------------------------
msg "system identity"
HOSTNAME="$(ask 'Hostname' 'hyperdrive')"
USERNAME="$(ask 'Your username')"
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid username"
TIMEZONE="$(ask 'Timezone' "$(curl -fsS --max-time 4 https://ipapi.co/timezone 2>/dev/null || echo UTC)")"
[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "unknown timezone: $TIMEZONE"
LOCALE="$(ask 'Locale' 'en_US.UTF-8')"
KEYMAP="$(ask 'Console keymap' 'us')"

USERPW="$(askpw "Password for $USERNAME")"
if [[ "$(ask 'Set a separate root password? (otherwise root is locked, sudo only)' 'no')" =~ ^[Yy] ]]; then
    ROOTPW="$(askpw 'Root password')"
else
    ROOTPW=""
fi

USE_ZRAM=yes
[[ "$(ask 'Enable zram swap (recommended)?' 'yes')" =~ ^[Nn] ]] && USE_ZRAM=no

UCODE=""
if   grep -q GenuineIntel /proc/cpuinfo; then UCODE="intel-ucode"
elif grep -q AuthenticAMD /proc/cpuinfo; then UCODE="amd-ucode"
fi

cat <<EOF

  ────────────────────────────────────────────────────────────
   disk        $DISK   (ESP $ESP, root $ROOT)
   hostname    $HOSTNAME
   user        $USERNAME   (wheel, login shell zsh)
   root        $([[ -n "$ROOTPW" ]] && echo 'password set' || echo 'locked (sudo only)')
   timezone    $TIMEZONE
   locale      $LOCALE   keymap $KEYMAP
   zram swap   $USE_ZRAM
   microcode   ${UCODE:-none detected}
   layout      GPT/UEFI · btrfs @ @home @log @pkg @snapshots · GRUB
  ────────────────────────────────────────────────────────────
EOF
[[ "$(ask 'Proceed and WIPE the disk now?' 'no')" =~ ^[Yy] ]] || die "cancelled"

# --- partition ----------------------------------------------------------
msg "partitioning $DISK"
swapoff -a || true
umount -R "$MNT" 2>/dev/null || true
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1GiB -t1:ef00 -c1:EFI        "$DISK"
sgdisk -n2:0:0     -t2:8300 -c2:hyperdrive "$DISK"
partprobe "$DISK"; sleep 1

msg "formatting"
mkfs.fat -F32 -n EFI "$ESP"
mkfs.btrfs -f -L hyperdrive "$ROOT"

msg "btrfs subvolumes"
mount "$ROOT" "$MNT"
for sv in @ @home @log @pkg @snapshots; do btrfs subvolume create "$MNT/$sv"; done
umount "$MNT"

O="noatime,compress=zstd:1,ssd,space_cache=v2,discard=async"
mount -o "$O,subvol=@" "$ROOT" "$MNT"
mkdir -p "$MNT"/{home,var/log,var/cache/pacman/pkg,.snapshots,boot}
mount -o "$O,subvol=@home"      "$ROOT" "$MNT/home"
mount -o "$O,subvol=@log"       "$ROOT" "$MNT/var/log"
mount -o "$O,subvol=@pkg"       "$ROOT" "$MNT/var/cache/pacman/pkg"
mount -o "$O,subvol=@snapshots" "$ROOT" "$MNT/.snapshots"
mount "$ESP" "$MNT/boot"

# --- base system ------------------------------------------------------
msg "ranking mirrors"
reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist 2>/dev/null || true

msg "pacstrap base system (this takes a while)"
# shellcheck disable=SC2046
pacstrap -K "$MNT" \
    base base-devel linux-lts linux-firmware mkinitcpio $UCODE \
    btrfs-progs grub efibootmgr \
    networkmanager sudo zsh git vim \
    $([[ "$USE_ZRAM" == yes ]] && echo zram-generator)

msg "fstab"
genfstab -U "$MNT" >> "$MNT/etc/fstab"

# --- ship the hyperdrive tree into the target -----------------------
msg "copying the hyperdrive tree into the new system"
if [[ -d "$SHARE" ]]; then
    mkdir -p "$MNT/usr/local/share"
    cp -a "$SHARE" "$MNT/usr/local/share/"
    install -Dm755 "$SHARE/postinstall.sh"    "$MNT/usr/local/bin/hyperdrive-setup"
    install -Dm755 "$SHARE/apply-dotfiles.sh" "$MNT/usr/local/bin/hyperdrive-apply-dotfiles"
else
    echo "warning: $SHARE missing — clone the repo after boot and run scripts/postinstall.sh"
fi

# --- configure inside the chroot -----------------------------------
msg "configuring the new system"
cat > "$MNT/root/hyperdrive-chroot.sh" <<'CHROOT'
#!/usr/bin/env bash
set -euo pipefail

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "/^#${LOCALE} /s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE"   > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# btrfs module in the initramfs
sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
mkinitcpio -P

# user + sudo for the wheel group
useradd -m -G wheel -s /usr/bin/zsh "$USERNAME"
echo "$USERNAME:$USERPW" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel
if [[ -n "${ROOTPW:-}" ]]; then echo "root:$ROOTPW" | chpasswd; else passwd -l root; fi

# bootloader — ESP at /boot, matching system/etc/pacman.d/hooks/95-grub-efi.hook
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager systemd-timesyncd fstrim.timer

if [[ "$USE_ZRAM" == yes ]]; then
    cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF
fi

# first-boot nudge (shell-agnostic; hyperdrive-setup clears it when it finishes)
if [[ -x /usr/local/bin/hyperdrive-setup ]]; then
    cat > /etc/motd <<'EOF'

hyperdrive base system installed. Log in as your user and run:

    hyperdrive-setup

to install the end-4 desktop, patches, dotfiles and services.

EOF
fi
CHROOT

chmod +x "$MNT/root/hyperdrive-chroot.sh"
arch-chroot "$MNT" env \
    TIMEZONE="$TIMEZONE" LOCALE="$LOCALE" KEYMAP="$KEYMAP" HOSTNAME="$HOSTNAME" \
    USERNAME="$USERNAME" USERPW="$USERPW" ROOTPW="$ROOTPW" USE_ZRAM="$USE_ZRAM" \
    bash /root/hyperdrive-chroot.sh
rm -f "$MNT/root/hyperdrive-chroot.sh"

# --- done -----------------------------------------------------------
msg "unmounting"
umount -R "$MNT"
trap - EXIT

cat <<EOF

  hyperdrive base system installed on $DISK.

  Next:
    1. reboot and remove the USB
    2. log in as '$USERNAME'
    3. run:  hyperdrive-setup      # end-4 desktop + patches + dotfiles + services
    4. add your tokens to ~/.zshrc_secrets (see the .example), then reboot

EOF
[[ "$(ask 'Reboot now?' 'no')" =~ ^[Yy] ]] && reboot
