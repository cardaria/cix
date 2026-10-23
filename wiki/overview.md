---
title: Overview
category: overview
tags: [overview, stack, quick-start]
updated: 2026-10-20
---

# Overview

`cix` is my personal NixOS configuration: each machine is a host in one
flake, sharing modules and a Home Manager user. One rebuild applies a host's
system and user environment together. The hosts are listed in the [README](../README.md#hosts).

## The stack

| Layer | Choice |
| --- | --- |
| OS | NixOS, `nixos-unstable`, pinned by `flake.lock`, updated deliberately |
| Kernel / boot (draba) | `linuxPackages_latest`, GRUB (EFI) with os-prober for Windows |
| Storage | Disko-managed btrfs (`@root`, `@home`, `@nix`), 16G swap |
| Graphics (draba) | RTX 5060 LP drives the desktop over DisplayPort; RTX 5090 is CUDA-only |
| GPU access | [5090 permissions](architecture/gpu-access.md) restrict compute use; System Monitor and `nvidia-smi` keep statistics |
| Desktop | [KDE Plasma 6](desktop/plasma.md) on Wayland: KWin with Krohnkite tiling, 150% fractional scaling |
| Login | [Plasma Login Manager](desktop/login.md); KWallet for secrets |
| Terminal / shell | [Ghostty](apps/terminal.md) + [zsh/fzf](desktop/shell.md); Zed is the default editor |
| Secrets | [agenix](security/secrets.md); the age key is backed up in [1Password](security/1password.md) |
| Local AI | Qwen3.8-27B on the 5090 via NInfer + llama-swap, used from OpenCode ([Local LLM](dev/local-llm.md)) |
| OCR | Chandra OCR 2 on the 5090; PDF/image extraction with `cix ocr` ([Local OCR](dev/local-ocr.md)) |
| ChatGPT desktop | Official Linux preview, managed through Home Manager ([Apps](apps/media.md)) |

## How the repo is organised

```text
flake.nix            entry point: inputs, one system per host, packages, checks
hosts/<host>/        one machine each: hardware, disks, GPUs, boot, mounts
modules/nixos/       shared system modules: desktop services, login, 1Password
home/cardaria/       the user and the explicit list of Home Manager modules
modules/home/        user programs, grouped: apps/, wayland/, llm/, ocr/, shell, development
dotfiles/<app>/      live native config files, symlinked into ~/.config
pkgs/                local packages and overrides
secrets/             agenix ciphertext + public recipients
wiki/                this manual; _sources.yaml maps pages ↔ code
.agents/skills/      workflows for coding agents
```

The details are in [Architecture](architecture/index.md).

## Three kinds of change

| You change… | Takes effect after… | Example |
| --- | --- | --- |
| a file in `dotfiles/` | the app's reload/restart, no rebuild | `dotfiles/zed/settings.json` (Zed reloads on save) |
| a `.nix` file | build → test → switch ([Deployment](deployment.md)) | adding a package, a Plasma shortcut |
| a Plasma GUI setting | immediately; kept across reinstalls only once declared in `plasma.nix` | the display mode is the exception: KWin saves it into `dotfiles/kwin/` |

Rebuilding *applies* configuration; committing and pushing *saves* it to GitHub.

## Quick start

```sh
cd ~/Repos/cix
nix flake check                         # formatting, configs, docs mapping
$EDITOR modules/home/apps/default.nix   # e.g. add a package
```

Then follow [Deployment](deployment.md#build-and-apply).

## What is *not* in Git

- Personal data, browser profiles, sign-ins and clipboard history.
- Wallpapers and purchased fonts (Berkeley Mono).
- Model weights in `~/AI`. The repo pins which file each one is ([Local LLM](dev/local-llm.md)).
- The private age key, which is backed up separately ([Secrets](security/secrets.md)).
- `memory/`, the local decision cards.

## Related

- [Architecture](architecture/index.md) · [Deployment](deployment.md) · [Constraints](constraints.md)
- [AGENTS.md](../AGENTS.md): the rules coding agents follow
