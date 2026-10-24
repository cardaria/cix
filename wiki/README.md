---
title: Wiki home
category: overview
tags: [index, moc]
updated: 2026-10-24
---

# cix wiki

This is the operations manual for the cix hosts. It answers **how to use and fix
things**. The **why** behind non-obvious choices lives in local decision cards
(`memory/`, not in Git). The code itself is the authority on **what** is
configured.

- Every page starts with frontmatter (`title`, `category`, `tags`, `updated`);
  component pages end with `## Troubleshooting` and `## Related`.
- [`_sources.yaml`](_sources.yaml) binds each page to the files it documents.
  `nix flake check` fails when a module has no page or a listed source has
  disappeared.

## Start here

| Page | Content |
| --- | --- |
| [Overview](overview.md) | What this repo is and how it is organised |
| [Deployment](deployment.md) | Everyday workflow: edit → build → test → switch → commit; updates |
| [Constraints](constraints.md) | Rules every change follows (placement, live dotfiles, safety) |
| [Troubleshooting](troubleshooting.md) | Index of every page's troubleshooting section |

## architecture/

| Page | Content |
| --- | --- |
| [Architecture](architecture/index.md) | How the flake, host, NixOS and Home Manager modules fit together |
| [Flake](architecture/flake.md) | Inputs, outputs, checks, dev shell, updating the lock |
| [draba](architecture/draba.md) | The machine: dual GPU, GPU tuning (Green Curve), disks, input devices, kernel, hardware quirks |
| [GPU access](architecture/gpu-access.md) | 5090 device permissions and explicit LLM/OCR access |

## desktop/

| Page | Content |
| --- | --- |
| [Plasma](desktop/plasma.md) | KDE Plasma, KWin, Krohnkite, shortcuts, panel, scaling, GPU selection |
| [Preferences](desktop/preferences.md) | Saved KDE appearance, animation speed, window behavior, panel, mouse and file views |
| [Login](desktop/login.md) | Plasma Login Manager, KWallet unlock, recovery |
| [Shell](desktop/shell.md) | Zsh, fzf search, history |

## apps/

| Page | Content |
| --- | --- |
| [Terminal](apps/terminal.md) | Ghostty defaults, Konsole, Berkeley Mono, fastfetch |
| [Browsers](apps/browsers.md) | Brave Origin (override, VA-API, frame workaround), Firefox |
| [Media & documents](apps/media.md) | KDE viewers, Merkuro Calendar, Haruna, Plex, Spotify, ChatGPT, Vesktop, Fluxer, Steam, default apps |

## dev/

| Page | Content |
| --- | --- |
| [cix CLI](dev/cli.md) | `cix update`, `cix rollback`, `cix llm`, `cix ocr` and how to add a command |
| [Developer tools](dev/tools.md) | Zed, Micro, Lazygit, nixd/nixfmt, AI CLIs, nvtop |
| [Local LLM](dev/local-llm.md) | Qwen3.8-27B on the 5090: NInfer, llama-swap, OpenCode profiles, `~/AI` |
| [Local OCR](dev/local-ocr.md) | Chandra OCR 2 on the 5090: PDFs, images, verified weights in `~/AI` |
| [Nix packaging](dev/nix-packaging.md) | `pkgs/`, overrides, patches, updating Anki, NInfer, Chandra, Fluxer and Green Curve |

## security/

| Page | Content |
| --- | --- |
| [Secrets](security/secrets.md) | agenix workflow, the age key, backup and restore |
| [1Password](security/1password.md) | GUI/CLI integration |

## system/

| Page | Content |
| --- | --- |
| [Boot & recovery](system/boot.md) | GRUB + Windows, rollback, live-ISO recovery, fresh install |
| [Network share](system/network-share.md) | SMB cloud share, mounted from boot |

## Agent skills

Workflows for coding agents live in [`.agents/skills/`](../.agents/skills/).
[AGENTS.md](../AGENTS.md#skill-routing) says which one handles which task.
