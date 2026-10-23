---
title: Troubleshooting
category: overview
tags: [troubleshooting, index, recovery]
updated: 2026-10-22
---

# Troubleshooting

This page only points to other pages: each one ends with its own troubleshooting
section. Start with the symptom.

## First moves

```sh
systemctl --failed; systemctl --user --failed
journalctl -b -p err                       # this boot's errors
journalctl --user -b -u plasma-kwin_wayland -u plasma-plasmashell
```

If the desktop is unusable, switch to **TTY2** (`Ctrl+Alt+F2`) and log in there.

## By symptom

| Symptom | Go to |
| --- | --- |
| Doesn't boot / Windows missing | [Boot & recovery](system/boot.md#troubleshooting) |
| Bad generation after switch | [Deployment](deployment.md#troubleshooting) |
| Update logged out the desktop, portal activation failed, or boot installation failed | [Deployment](deployment.md#troubleshooting) |
| Build/eval error, check fails | [Flake](architecture/flake.md#troubleshooting) |
| Activation "would be clobbered" | [Architecture](architecture/index.md#troubleshooting) |
| Black screen, greeter missing | [Login](desktop/login.md#troubleshooting), [draba](architecture/draba.md#troubleshooting) |
| Session crashes, Baloo crashes, wrong scale, wrong GPU, shortcuts, tiling | [Plasma](desktop/plasma.md#troubleshooting) |
| zsh/fzf problems | [Shell](desktop/shell.md#troubleshooting) |
| Font, Ghostty, Konsole | [Terminal](apps/terminal.md#troubleshooting) |
| Brave offset, scale, video decoding | [Browsers](apps/browsers.md#troubleshooting) |
| Local model won't load, slow, VRAM held | [Local LLM](dev/local-llm.md#troubleshooting) |
| OCR model, downloads or PDF/image extraction | [Local OCR](dev/local-ocr.md#troubleshooting) |
| Wrong default app | [Media & documents](apps/media.md#troubleshooting) |
| Package hash or patch failures | [Nix packaging](dev/nix-packaging.md#troubleshooting) |
| Secret not decrypted | [Secrets](security/secrets.md#troubleshooting) |
| `op` CLI not connected | [1Password](security/1password.md#troubleshooting) |
| SMB share hangs | [Network share](system/network-share.md#troubleshooting) |
| GPU/CUDA/suspend | [draba](architecture/draba.md#troubleshooting) |
| GPU permissions or missing statistics | [GPU access](architecture/gpu-access.md#troubleshooting) |

## Related

- [Overview](overview.md) · [Deployment](deployment.md)
