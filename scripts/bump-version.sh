#!/usr/bin/env bash
# Bump the librewolf-hellfire-bin package to the current upstream version and
# refresh checksums + .SRCINFO. Run on Arch (needs makepkg/updpkgsums). Pass a
# tag to pin, or let it read the latest from the integration repo.
#
# The librewolf-hellfire-git package self-versions via pkgver() and needs no
# bumping, so it is intentionally not touched here.
#
#   ./scripts/bump-version.sh            # detect latest tag from upstream
#   ./scripts/bump-version.sh 152.0.2-1  # pin to a specific tag
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM=https://codeberg.org/FailsafeDX/librewolf-hellfire

tag="${1:-}"
if [ -z "$tag" ]; then
  ver=$(curl -fsSL "${UPSTREAM}/raw/branch/main/version")
  rel=$(curl -fsSL "${UPSTREAM}/raw/branch/main/release")
  tag="${ver}-${rel}"
fi
pkgver="${tag/-/_}" # 152.0.2-1 -> 152.0.2_1
echo "Bumping to tag=${tag} (pkgver=${pkgver})"

for pkg in librewolf-hellfire-bin; do
  dir="${ROOT}/aur/${pkg}"
  [ -d "$dir" ] || { echo "skip: $dir not found"; continue; }
  ( cd "$dir"
    sed -i -E "s/^pkgver=.*/pkgver=${pkgver}/" PKGBUILD
    sed -i -E "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
    updpkgsums
    makepkg --printsrcinfo > .SRCINFO
    echo "updated ${pkg}" )
done

echo "Done. Review diffs, then commit/push each aur/ package to the AUR."
