---
title: Flake
category: architecture
tags: [flake, inputs, checks, devshell, updates]
updated: 2026-10-24
---

# Flake

`flake.nix` is the only entry point. It declares the inputs, builds one system per
host and exposes helper packages, a formatter, a dev shell and checks.

## Inputs

| Input | Purpose | Follows nixpkgs |
| --- | --- | --- |
| `nixpkgs` | `nixos-unstable` | n/a |
| `nixpkgs-cuda` | second `nixos-unstable` pin, used only by the CUDA packages `chandra-ocr` and `ninfer` | n/a |
| `home-manager` | user environment, integrated as a NixOS module | yes |
| `disko` | declarative partitioning (install/recovery only) | yes |
| `agenix` | encrypted secrets | yes |
| `plasma-manager` | declarative Plasma settings, a Home Manager module (`sharedModules`) | yes, and `home-manager` |
| `chandra-src` | Chandra OCR source, non-flake | n/a |
| `chandra-model` | model revision and file hashes, non-flake metadata | n/a |
| `pve` | the private server repo, non-flake: the registry draba reads (the share, codex-lb, the Proxmox host) and the share's secret | n/a |

Exact revisions are pinned in `flake.lock`. Updates are deliberate, never
automatic ([Deployment → Updating](../deployment.md#update-packages)).

`nixpkgs-cuda` exists because the local CUDA packages carry sm_120 overrides that no binary
cache holds, so each bump recompiles them locally. `cix update draba` leaves it
alone; `cix update draba --cuda` moves it together with `nixpkgs`.

The server's guests, their inputs and their docs live in the private `pve` repo (`~/Repos/pve`).
cix reads only its registry, so `draba` builds without listing the server's names or addresses here.
`cix update draba` moves the `pve` input too; `cix update pve` updates the guests in that repo.

## Outputs

| Output | What |
| --- | --- |
| `nixosConfigurations.draba` | the workstation: the whole system, including Home Manager |
| `packages.x86_64-linux.<name>` | every package in `pkgs/default.nix`; the CUDA ones use `nixpkgs-cuda`, the rest draba's nixpkgs |
| `packages.x86_64-linux.{disko,agenix,age}` | locked recovery tools for `nix run .#<name>` |
| `formatter` | `nixfmt-tree` → `nix fmt` |
| `devShells.default` | `nixd`, `nixfmt`, `nixfmt-tree`, `nurl`, `nix-update`, `yq` |
| `checks` | see below |

Using the locked tools matters during recovery: `nix run .#disko` runs the
exact Disko version that matches the layout.

## Checks

`nix flake check` runs every check:

| Check | Verifies |
| --- | --- |
| `formatting` | every `.nix` file is `nixfmt`-clean |
| `cix-update` | update workflow confirmations, failure recovery, concurrency and specialisation handling with isolated command mocks |
| `docs-sources` | wiki frontmatter is valid, `wiki/_sources.yaml` covers every module and only existing paths, and docs contain no IPv4 addresses |

```sh
nix flake check
nix build .#checks.x86_64-linux.docs-sources -L   # run one check with logs
```

## Dev shell

```sh
nix develop      # nixd (LSP), nixfmt, nixfmt-tree, nurl, nix-update, yq
nix fmt          # format the whole repo
```

nixd needs to be configured in your editor separately.

## Common commands

```sh
nix flake metadata                       # inputs and their revisions
nix flake update nixpkgs home-manager    # update chosen inputs
nix eval --json .#nixosConfigurations --apply builtins.attrNames     # hosts
nix eval --raw ".#nixosConfigurations.$(hostname).pkgs.kdePackages.plasma-workspace.version"   # Plasma version
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `error: path '…' does not exist` for a file you just created | Git flakes ignore untracked files. `git add <file>` or use `path:.` |
| `formatting` check fails | `nix fmt`, review, re-run |
| `docs-sources` fails | the message names the missing page entry or path. Update `wiki/_sources.yaml` |
| Warning "Git tree is dirty" | informational. Uncommitted changes are included in the evaluation |

## Related

- [Architecture](index.md) · [Deployment](../deployment.md) · [Nix packaging](../dev/nix-packaging.md)
- memory: `flake-deliberate-updates`
