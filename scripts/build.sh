#!/usr/bin/env bash
# Build the hyperdrive ISO with mkarchiso.
#
#   sudo ./scripts/build.sh
#
# Requirements: archiso, and run as root (mkarchiso needs loop devices).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${REPO_ROOT}/build/profile"
WORK="${REPO_ROOT}/build/work"
OUT="${REPO_ROOT}/dist"

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
command -v mkarchiso >/dev/null || { echo "install 'archiso' first"; exit 1; }

echo ":: assembling profile from releng + iso/"
rm -rf "${PROFILE}"
cp -r /usr/share/archiso/configs/releng "${PROFILE}"

# our overrides
cp "${REPO_ROOT}/iso/profiledef.sh"   "${PROFILE}/profiledef.sh"
cp "${REPO_ROOT}/iso/pacman.conf"     "${PROFILE}/pacman.conf"
cp "${REPO_ROOT}/iso/packages.x86_64" "${PROFILE}/packages.x86_64"

# airootfs overlay (live-env only)
if [[ -d "${REPO_ROOT}/iso/airootfs" ]]; then
    cp -rT "${REPO_ROOT}/iso/airootfs" "${PROFILE}/airootfs"
fi

# ship the installed-system material inside the ISO so the installer can pull it
install -d "${PROFILE}/airootfs/usr/local/share/hyperdrive"
cp -rT "${REPO_ROOT}/dotfiles" "${PROFILE}/airootfs/usr/local/share/hyperdrive/dotfiles"
cp -rT "${REPO_ROOT}/system"   "${PROFILE}/airootfs/usr/local/share/hyperdrive/system"
cp -rT "${REPO_ROOT}/patches"  "${PROFILE}/airootfs/usr/local/share/hyperdrive/patches"
install -Dm755 "${REPO_ROOT}/scripts/postinstall.sh"   "${PROFILE}/airootfs/usr/local/bin/hyperdrive-install"
install -Dm755 "${REPO_ROOT}/scripts/apply-dotfiles.sh" "${PROFILE}/airootfs/usr/local/share/hyperdrive/apply-dotfiles.sh"

echo ":: mkarchiso"
rm -rf "${WORK}"
mkdir -p "${OUT}"
mkarchiso -v -w "${WORK}" -o "${OUT}" "${PROFILE}"

echo ":: done -> ${OUT}"
ls -lh "${OUT}"/*.iso
