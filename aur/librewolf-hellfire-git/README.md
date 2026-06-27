# librewolf-hellfire-git (AUR — source build, VCS)

Builds [LibreWolf](https://librewolf.net/) with the
[HellFire](https://github.com/CYFARE/HellFire) mozconfig optimizations **from
source**, always tracking the `main` branch of the integration repository
[FailsafeDX/librewolf-hellfire](https://codeberg.org/FailsafeDX/librewolf-hellfire).

Each build pulls the latest upstream commit, so you get new Firefox/LibreWolf
versions as soon as they land — no manual `pkgver` bump. Because HellFire
compiles with `-march=native`, the result is tuned to the CPU it is built on. For
a portable, prebuilt binary instead, use **`librewolf-hellfire-bin`**.

## How versioning works

This is a VCS package. `pkgver()` derives the version at build time from the
repo's `version` and `release` files plus the commit count, e.g.
`152.0.2_1.r1234`. The `pkgver` in the PKGBUILD/.SRCINFO is just a placeholder.

The matching Firefox source is **not** a declared makepkg source (its version
isn't known until HEAD is cloned); instead the upstream Makefile downloads and
GPG-verifies it during `prepare()`.

## Heads up

A complete Firefox/LibreWolf source build with full LTO **and PGO**. Budget for:

- a multi-hour compile,
- ~40 GB free disk space,
- a lot of RAM (8 GB realistic minimum; 16 GB+ recommended),
- network access during `prepare()` (Firefox source + the settings submodule).

## Build / install

```sh
makepkg -si
```

No `updpkgsums` step is needed — the only checksums are `SKIP` (git source and
the local desktop file). Rebuild any time to pick up upstream changes.

## Notes / customization

- HellFire's `-march=native` lives in the upstream `assets/mozconfig`. The
  PKGBUILD only appends Arch packaging options (`--prefix=/usr`,
  `--disable-bootstrap`, wasi sysroot, system clang); it does not touch the
  optimization flags.
- The package `provides=(librewolf librewolf-hellfire)` and installs to
  `/usr/lib/librewolf`, so it conflicts with the other librewolf packages.
- Want a reproducible, tagged build instead of HEAD-tracking? Pin the source to
  `git+...librewolf-hellfire.git#tag=<tag>`, declare the Firefox source tarball
  with a checksum, drop `pkgver()`, and set `pkgver=<ffver>_<release>`.
