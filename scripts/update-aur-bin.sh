#!/usr/bin/env bash
# Bump librewolf-hellfire-bin to $TAG, refresh checksums + .SRCINFO, and push to
# the AUR. Designed to run inside an archlinux:latest container in CI, but also
# works locally on Arch.
#
# Required env:
#   TAG                  upstream tag, e.g. 152.0.2-1
#   AUR_SSH_PRIVATE_KEY  private key registered with your AUR account
set -euo pipefail

: "${TAG:?set TAG, e.g. 152.0.2-1}"
: "${AUR_SSH_PRIVATE_KEY:?set AUR_SSH_PRIVATE_KEY}"

PKG=librewolf-hellfire-bin
PKGVER="${TAG/-/_}" # AUR pkgver: 152.0.2-1 -> 152.0.2_1

# makepkg refuses to run as root; create a build user when in a container.
if [ "$(id -u)" -eq 0 ]; then
  pacman -Sy --noconfirm --needed base-devel git openssh pacman-contrib
  useradd -m builder || true
  printf 'builder ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/builder
  install -d -o builder -g builder /home/builder/work
  cp -rT "$PWD" /home/builder/work/repo
  chown -R builder:builder /home/builder/work
  # Preserve env (AUR_SSH_PRIVATE_KEY, TAG) but force HOME to builder's own,
  # writable home — GitHub sets HOME=/github/home, which builder cannot write.
  exec sudo -u builder -E env HOME=/home/builder bash "$0"
fi

# --- running as unprivileged user from here ---
WORK="${WORK:-$HOME/work/repo}"
cd "$WORK" 2>/dev/null || cd "$PWD"

mkdir -p "$HOME/.ssh"
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" >"$HOME/.ssh/aur"
chmod 600 "$HOME/.ssh/aur"
ssh-keyscan -H aur.archlinux.org >>"$HOME/.ssh/known_hosts" 2>/dev/null
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/aur -o IdentitiesOnly=yes"
git config --global user.name "${GIT_AUTHOR_NAME:-LibreWolf HellFire CI}"
git config --global user.email "${GIT_AUTHOR_EMAIL:-ci@example.invalid}"

# Clone the live AUR package so we update exactly what's published. Use a path
# outside the repo, since the repo itself already contains an aur/ directory.
CLONE="$HOME/aur-pkg"
rm -rf "$CLONE"
git clone "ssh://aur@aur.archlinux.org/${PKG}.git" "$CLONE"
cd "$CLONE"

# Bring in the maintained packaging files from this repo's copy.
cp -f "${WORK}/aur/${PKG}/PKGBUILD" PKGBUILD
cp -f "${WORK}/aur/${PKG}/${PKG}.install" "${PKG}.install" 2>/dev/null || true
cp -f "${WORK}/aur/${PKG}/librewolf-hellfire.desktop" librewolf-hellfire.desktop 2>/dev/null || true

# Pin to this release and refresh checksums + metadata.
sed -i -E "s/^pkgver=.*/pkgver=${PKGVER}/" PKGBUILD
sed -i -E "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
updpkgsums
makepkg --printsrcinfo >.SRCINFO

git add -A
if git diff --cached --quiet; then
  echo "No changes to push."
  exit 0
fi
git commit -m "Update to ${TAG}"
# HEAD:master works whether the fresh clone's branch is master or main
# (matters for the first push that creates the package base).
git push origin HEAD:master
