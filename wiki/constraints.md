---
title: Constraints
category: overview
tags: [rules, conventions, safety, placement]
updated: 2026-10-24
---

# Constraints

The rules every change follows, for humans and agents alike. `AGENTS.md`
holds the agent-facing version of the same rules.

## Structure

| Rule | Detail |
| --- | --- |
| Explicit imports | every module is listed by hand in `flake.nix`, `hosts/<host>/default.nix` or `home/cardaria/default.nix`. No auto-discovery |
| No premature abstraction | no options/`mkEnableOption` or helper layer for something used once |
| One home per package | see the placement table in [Architecture](architecture/index.md#where-does-a-new-thing-go). Search before adding |
| No overlays | use `override`/`overrideAttrs`/`symlinkJoin` locally ([Nix packaging](dev/nix-packaging.md)) |
| Host values stay in `hosts/` | disk IDs, PCI IDs and monitor serials never go in shared modules |
| Prefer native options | NixOS/Home Manager options before hand-written files or generators |

## Config style

| Rule | Detail |
| --- | --- |
| Minimal comments | only a *why*, a gotcha or a cross-file link; one short fragment, no trailing period |
| Grouped lines | related settings together, one blank line between groups, never unrelated lines in one group |
| Section headers | `# --- Section ---` in long flat files only |

## Live dotfiles

| Rule | Detail |
| --- | --- |
| Use the `dotfile` helper | `dotfile "<app>"` links an absolute out-of-store path. A Nix path would copy into the store |
| Link directories for atomic writers | Micro, Zed, Spicetify replace files on save |
| Plasma settings that must survive a reinstall | declare them in `modules/home/wayland/plasma.nix` ([Plasma](desktop/plasma.md)) |

## Hardware and system

| Rule | Detail |
| --- | --- |
| Desktop on the RTX 5060 LP by default | the explicit [display-5090 boot entry](architecture/draba.md#two-gpus-two-jobs) uses the 5090 for the desktop. CUDA tools pin it by UUID; never select a GPU by card number |
| Displays matched by identity | EDID identity (with serial) in `kwinoutputconfig.json`, never by connector name (`DP-1`) |
| 150% UI size, Zed as editor | deliberate preferences. The size is KWin's fractional scale; no per-app scale flags or variables ([Plasma](desktop/plasma.md#display-and-scaling)) |
| Disks by identity | always `/dev/disk/by-id`, never `/dev/nvmeXnY` |
| Deliberate updates | no unattended upgrades; update inputs on purpose and review the lock |
| `stateVersion` frozen | never bump it during updates |

## Approval required (agents)

Get explicit, exact-scope approval before:

- destructive storage operations (Disko `destroy`/`format`, partitioning)
- EFI/bootloader changes, Secure Boot
- public exposure (open ports, sharing)
- key or secret operations, large deletions, Git history rewrites
- `nixos-rebuild test`/`switch`, or a reboot

Preparation is not approval, and an approval covers only the scope it was given for.

## Secrets

- Only `.age` ciphertext and `.pub` recipients in Git.
- Private keys: `~/.config/agenix/` and `/var/lib/agenix/` (0600), with a backup in 1Password.
- Don't rotate keys as part of a cleanup.

## Docs

- No private identifiers (IP addresses, serials, disk IDs) in docs; name the
  file that holds them. The docs check rejects IPv4 addresses.
- A change to `.nix` or user-visible behaviour updates its wiki page(s) in the same commit.
- `wiki/_sources.yaml` must list every module (checked by `nix flake check`).
- The *why* goes into local memory cards, not long inline explanations.

## Related

- [AGENTS.md](../AGENTS.md) · [Architecture](architecture/index.md) · [Deployment](deployment.md)
