# librewolf-hellfire-bin (AUR — prebuilt binary)

Installs a **prebuilt** LibreWolf + HellFire binary instead of compiling it
locally. The binary is produced by this repo's CI workflow
([`.github/workflows/build.yml`](../../.github/workflows/build.yml)), which builds
with a portable baseline (`-march=x86-64-v3` ≈ AVX2 + SSE4.2 + FMA) and publishes
the package tarball as a GitHub Release.

This is the right choice if you don't want a multi-hour Firefox compile. For a
binary tuned to your exact CPU, use the source package `librewolf-hellfire-git`.

## Before you publish this package

1. Run the CI workflow at least once so it cuts a release. Releases are tagged to
   match upstream, e.g. `152.0.2-1`.
2. Confirm `_ghrepo` in `PKGBUILD` points at your GitHub `user/repo`
   (default: `unterschall/librewolf-hellfire`).
3. Refresh checksums and metadata:

   ```sh
   updpkgsums
   makepkg --printsrcinfo > .SRCINFO
   ```

## Install

```sh
makepkg -si
```

## How it maps to the release

- Tarball asset: `librewolf-hellfire-<tag>-linux-x86_64.tar.xz`
  (a `mach package` artifact whose top-level directory is `librewolf/`).
- Branding icons are pulled from the integration repo at the matching git tag,
  so no binary blobs need to live in this AUR repo.

`provides=(librewolf librewolf-hellfire)` and it conflicts with the other
librewolf packages, so it's a drop-in replacement.
