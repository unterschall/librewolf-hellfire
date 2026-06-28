#!/usr/bin/env bash
# Push librewolf-hellfire-git packaging to the AUR: sync the maintained files,
# regenerate .SRCINFO, and push — but only when something actually changed.
#
# This is a VCS (-git) package: its version is computed by pkgver() at build
# time, so we deliberately do NOT bump pkgver or run updpkgsums here. AUR policy
# forbids committing bare pkgver bumps for VCS packages, so this script pushes
# only on real packaging changes (PKGBUILD/.install/.desktop/.SRCINFO).
#
# Designed to run inside an archlinux:latest container in CI, but also works
# locally on Arch.
#
# Required env:
#   AUR_SSH_PRIVATE_KEY  private key registered with your AUR account
set -euo pipefail

: "${AUR_SSH_PRIVATE_KEY:?set AUR_SSH_PRIVATE_KEY}"

PKG=librewolf-hellfire-git

# makepkg refuses to run as root; create a build user when in a container.
if [ "$(id -u)" -eq 0 ]; then
  pacman -Sy --noconfirm --needed base-devel git openssh
  useradd -m builder || true
  printf 'builder ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/builder
  install -d -o builder -g builder /home/builder/work
  cp -rT "$PWD" /home/builder/work/repo
  chown -R builder:builder /home/builder/work
  # Preserve env (AUR_SSH_PRIVATE_KEY) but force HOME to builder's own, writable
  # home — GitHub sets HOME=/github/home, which builder cannot write.
  exec sudo -u builder -E env HOME=/home/builder bash "$0"
fi

# --- running as unprivileged user from here ---
WORK="${WORK:-$HOME/work/repo}"
cd "$WORK" 2>/dev/null || cd "$PWD"
git config --global --add safe.directory '*'
SRC_SHA="$(git -C "$WORK" rev-parse --short HEAD 2>/dev/null || echo unknown)"

mkdir -p "$HOME/.ssh"
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" >"$HOME/.ssh/aur"
chmod 600 "$HOME/.ssh/aur"
ssh-keyscan -H aur.archlinux.org >>"$HOME/.ssh/known_hosts" 2>/dev/null
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/aur -o IdentitiesOnly=yes"
git config --global user.name "${GIT_AUTHOR_NAME:-LibreWolf HellFire CI}"
git config --global user.email "${GIT_AUTHOR_EMAIL:-ci@example.invalid}"

# Clone the live AUR package so we update exactly what's published.
git clone "ssh://aur@aur.archlinux.org/${PKG}.git" aur
cd aur

# Bring in the maintained packaging files from this repo's copy.
cp -f "${WORK}/aur/${PKG}/PKGBUILD" PKGBUILD
cp -f "${WORK}/aur/${PKG}/${PKG}.install" "${PKG}.install" 2>/dev/null || true
cp -f "${WORK}/aur/${PKG}/librewolf-hellfire.desktop" librewolf-hellfire.desktop 2>/dev/null || true

# VCS package: no pkgver bump, no updpkgsums — just refresh metadata.
# (makepkg --printsrcinfo does not fetch sources, so pkgver() is not run; the
# placeholder pkgver from the PKGBUILD is emitted, which is expected for -git.)
makepkg --printsrcinfo >.SRCINFO

git add -A
if git diff --cached --quiet; then
  echo "No packaging changes to push."
  exit 0
fi
git commit -m "Update packaging (${SRC_SHA})"
# HEAD:master works whether the fresh clone's branch is master or main
# (matters for the first push that creates the package base).
git push origin HEAD:master
