---
title: Nix packaging
category: dev
tags: [packaging, override, overrideAttrs, symlinkJoin, patches, ninfer, chandra, cuda, fluxer, appimage]
updated: 2026-10-10
---

# Nix packaging

How packages are customised or added in this repo, from the lightest touch to
a full vendored package. Coding agents follow the `nix-packaging` skill.

## Pick the lightest tool

| Need | Tool | Example in this repo |
| --- | --- | --- |
| Use as-is | add to a package list | `apps/default.nix` |
| Change build flags / plugins | `pkg.override { … }` | Brave (`commandLineArgs`) |
| Patch an upstream package | `pkgs/<name>/` + `overrideAttrs` + `patches` | Krohnkite sole-window gaps, NVIDIA VA-API multi-GPU |
| Different icon / `.desktop` | `symlinkJoin` + `postBuild` | Plex |
| Not in nixpkgs yet | `pkgs/<name>/` + `callPackage` | NInfer, Chandra OCR, Fluxer Canary |

No overlays: none of these changes need to be seen by other packages.

## Search first

```sh
nix search nixpkgs#<name>                                          # unstable
nix eval --raw ".#nixosConfigurations.$(hostname).pkgs.<name>.version"     # your locked nixpkgs
gh pr list -R NixOS/nixpkgs --search "<name> in:title" --state open
```

## Vendored packages (`pkgs/<name>/`)

```text
pkgs/<name>/
  default.nix                 nixpkgs by-name style (finalAttrs, meta, tests)
  <concern>.patch             one concern per patch
  README.md                   provenance + removal condition (required)
```

Each package is a flake output and builds on its own:

```sh
nix build .#ninfer -L --no-link --print-out-paths
```

Flake outputs use the host's nixpkgs instance, which allows unfree packages,
so CUDA packages such as NInfer evaluate there too. Modules take them as
`cixPkgs.<name>`: `modules/nixos/packages.nix` builds `pkgs/default.nix` once
with the system's nixpkgs and passes it to NixOS and Home Manager modules, so
there is one definition per package and no relative imports.

Helpful tools: `nix develop` provides `nurl` and `nix-update`; `nix-init` via `nix shell nixpkgs#nix-init`.

| Tool | Does |
| --- | --- |
| `nurl <url> <rev>` | prints a fetcher with the right hash |
| `nix-init` | drafts a package from a URL |
| `nix-update --flake <name>` | bumps version and hashes |

## NInfer

A CUDA inference engine with no releases and no install target, built from a
pinned master commit with `cudaPackages_13` for `sm_120a` only. There are no
patches. Bumps, the fallback commit and the removal condition are in
`pkgs/ninfer/README.md`. Runtime use: [Local LLM](local-llm.md).

```sh
nix build .#ninfer -L --no-link
```

## Chandra OCR

Chandra OCR uses a source flake input and nixpkgs' native CUDA 13 Python
dependencies. Model metadata is another locked input, with weights fetched
outside the Nix store. Provenance and local adjustments:
`pkgs/chandra-ocr/README.md`; usage: [Local OCR](local-ocr.md).

```sh
nix build .#chandra-ocr -L --no-link
```

## Fluxer Canary

Upstream's canary AppImage in `appimageTools.wrapType2`, after the open
nixpkgs PR #552820; a source build would need the whole pnpm and Cargo
monorepo. The version and hash come from upstream's `latest.json`; the
commands, the desktop-entry and icon fixes and the removal condition are in
`pkgs/fluxer-canary/README.md`. Usage: [Media](../apps/media.md).

```sh
nix build .#fluxer-canary -L --no-link
```

## Krohnkite

`pkgs/krohnkite/default.nix` overrides nixpkgs' KWin script with one patch
to keep screen-edge padding when sole-window percentages are set. The
same definition is used by Plasma and the standalone flake output.
Provenance and removal condition: `pkgs/krohnkite/README.md`.

```sh
nix build .#krohnkite --no-link
```

## NVIDIA VA-API driver

`pkgs/nvidia-vaapi-driver/default.nix` overrides nixpkgs' driver with one
patch, so video decodes on the card behind the render node it is given
instead of always on the first GPU. `hosts/draba/graphics.nix` installs it
through `hardware.graphics.extraPackages`, with `videoAcceleration` off so the
stock copy stays out. Provenance and removal condition:
`pkgs/nvidia-vaapi-driver/README.md`.

```sh
nix build .#nvidia-vaapi-driver --no-link
```

## Self-expiring overrides

Write temporary overrides so they switch off by themselves:

```nix
// lib.optionalAttrs (lib.versionOlder previous.version "1.2.3") { version = "1.2.3"; src = …; }
```

Once nixpkgs is newer, the block is dead code. Delete it during the next cleanup.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `hash mismatch` | copy the "got:" hash. Never commit `lib.fakeHash` |
| Patch fails after bump | rebase the patch on the new tag, or drop it if upstream fixed it (note it in the README) |
| Tests fail only in the sandbox | read the log (`-L`); fix with a test patch rather than `doCheck = false` |
| `attribute 'man' missing` after wrapping a package | `symlinkJoin` drops extra outputs Home Manager installs; use `overrideAttrs` |

## Related

- [Local LLM](local-llm.md) · [Local OCR](local-ocr.md) · [Browsers](../apps/browsers.md) · [Flake](../architecture/flake.md)
