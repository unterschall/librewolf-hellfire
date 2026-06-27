# LibreWolf HellFire — packaging

Packaging for **LibreWolf with the [HellFire](https://github.com/CYFARE/HellFire)
optimizations**, sourced from the integration repository
[`FailsafeDX/librewolf-hellfire`](https://codeberg.org/FailsafeDX/librewolf-hellfire)
(a fork of LibreWolf's `source` build system with HellFire's mozconfig — full
LTO, PGO, `-march`, sandbox, JXL, strip — already applied).

That integration repo is the single source of truth: it fetches the matching
Firefox release from `archive.mozilla.org`, applies the LibreWolf + HellFire
patch stack (`make dir`), and builds via `mach`. These packages drive that
machinery rather than re-combining the upstreams by hand.

This is a single repo (`unterschall/librewolf-hellfire`) that holds **both AUR
packages and the CI workflow**. The CI publishes its prebuilt binary as a GitHub
Release on this same repo, which the `-bin` package then downloads.

## What's here

| Path | What it is |
| --- | --- |
| [`aur/librewolf-hellfire-git/`](aur/librewolf-hellfire-git) | **AUR source package (VCS).** Tracks the integration repo's `main` branch and compiles locally. HellFire's `-march=native` ⇒ a binary tuned to *your* CPU. |
| [`aur/librewolf-hellfire-bin/`](aur/librewolf-hellfire-bin) | **AUR prebuilt package.** Installs a portable binary downloaded from this repo's GitHub Releases. |
| [`.github/workflows/build.yml`](.github/workflows/build.yml) | **CI.** Builds the portable binary (`-march=x86-64-v3`) and publishes it as a GitHub Release for the `-bin` package; optionally pushes the `-bin` update to the AUR. |
| [`scripts/bump-version.sh`](scripts/bump-version.sh) | Bump the `-bin` package to a new upstream tag (refreshes checksums + `.SRCINFO`). |
| [`scripts/update-aur-bin.sh`](scripts/update-aur-bin.sh) | Used by CI to push the updated `-bin` package to the AUR. |

## Version scheme

Upstream tags are `<firefox-version>-<librewolf-release>` (e.g. `152.0.2-1`).

- **`-git`** self-versions via `pkgver()`:
  `<firefox-version>_<release>.r<commit-count>` (e.g. `152.0.2_1.r1234`). No
  manual bumping; it always builds the latest commit.
- **`-bin`** is pinned per release. AUR `pkgver` cannot contain `-`, so the tag
  is encoded as `152.0.2_1` and translated back with `${pkgver/_/-}`.

## Getting started

### Source package (VCS)
```sh
cd aur/librewolf-hellfire-git
makepkg -si      # clones HEAD, fetches Firefox, multi-hour LTO+PGO build
```
No `updpkgsums` needed — checksums are `SKIP` (git source + local desktop file),
and the Firefox tarball is fetched + GPG-verified by the upstream Makefile.

### CI + prebuilt package
1. Push this repo to `github.com/unterschall/librewolf-hellfire` (public, so the
   `-bin` package can download release assets unauthenticated).
2. Actions → *Build & release LibreWolf HellFire* → **Run workflow** (or wait for
   the weekly cron) to cut a release.
3. `cd aur/librewolf-hellfire-bin && updpkgsums && makepkg --printsrcinfo > .SRCINFO`
4. Publish the `-bin` package to the AUR.

## CI details

The workflow (`.github/workflows/build.yml`):

1. Clones the integration repo (with submodules) and reads `version`/`release`
   to derive the tag, e.g. `152.0.2-1`.
2. Skips if a release for that tag already exists (override via the `force`
   input on manual dispatch).
3. Rewrites HellFire's `-march=native` to portable `-march=x86-64-v3`
   (≈ AVX2 + SSE4.2 + FMA) so the binary runs on any modern x86_64 machine.
4. `make fetch && make dir && make bootstrap && make build && make package`.
5. Uploads `librewolf-hellfire-<tag>-linux-x86_64.tar.xz` (+ `.sha256`) to a
   release tagged `<tag>`.
6. *(optional)* Bumps and pushes `librewolf-hellfire-bin` to the AUR.

Triggers: weekly cron, manual dispatch, and pushes that touch the workflow.

### Runner requirements ⚠️

This is a full Firefox source build with LTO and (by default) PGO. The free
`ubuntu-latest` runner is **marginal** — a disk-cleanup step frees ~40 GB and the
build can approach the 6 h job limit. For dependable runs use a **larger** or
**self-hosted** runner (adjust `runs-on:`), and/or disable PGO to roughly halve
build time by stripping `MOZ_PGO=1` in the `sed` step.

### Secrets

| Secret | Needed for | Notes |
| --- | --- | --- |
| `GITHUB_TOKEN` | creating releases | provided automatically |
| `AUR_SSH_PRIVATE_KEY` | `publish-aur` job (optional) | SSH key registered on your AUR account; without it the job no-ops |

## Publishing to the AUR

Each `aur/<pkg>/` directory maps 1:1 to an AUR git repo:

```sh
git clone ssh://aur@aur.archlinux.org/librewolf-hellfire-git.git
# copy PKGBUILD, .SRCINFO, *.install, *.desktop in, commit, push
```

Both packages `conflict` with each other and with `librewolf`/`librewolf-bin`,
since both install to `/usr/lib/librewolf` and provide the `librewolf` binary.

## Caveats / things to verify on a real Arch box

- **`-bin` checksums are `SKIP` placeholders.** Run `updpkgsums` (or
  `scripts/bump-version.sh`) before building/publishing it. (`-git` needs none.)
- The source build assumes the integration repo's `make dir` writes a clean
  `mozconfig` into the extracted tree; the PKGBUILD only *appends* Arch options.
- Run `namcap PKGBUILD` and a `makepkg` in a clean chroot (`extra-x86_64-build`)
  before submitting to the AUR.
