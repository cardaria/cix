---
title: Terminal
category: apps
tags: [konsole, ghostty, terminal, font, berkeley-mono, fastfetch]
updated: 2026-10-10
---

# Terminal

Ghostty is the default terminal, with GitHub Light High Contrast and zsh
([Shell](../desktop/shell.md)). Konsole is also installed with Plasma; its
profiles are configured in the app.

## Ghostty

Ghostty is installed by Home Manager through `modules/home/apps/ghostty.nix`.
Launch it with `Meta+Return`, `Ctrl+Alt+T`, the application menu or `ghostty`.
Its version follows the repo's locked nixpkgs input.

`modules/home/wayland/plasma.nix` sets `$TERMINAL=ghostty`, KDE's preferred
terminal (`TerminalApplication` and `TerminalService` in `kdeglobals`) and
both launch shortcuts. It clears Konsole's launch keys to avoid conflicts.
The session variable takes effect in new login sessions; KDE defaults are
read from its configuration.

The live config is `dotfiles/ghostty/config.ghostty`, linked to
`~/.config/ghostty/config.ghostty`. It sets the bundled theme and the font:

```ini
theme = GitHub Light High Contrast
font-family = Berkeley Mono

confirm-close-surface = false
app-notifications = no-clipboard-copy,no-config-reload
```

| Action | Shortcut |
| --- | --- |
| Edit config | `Ctrl+,` |
| Reload config | `Ctrl+Shift+,` |
| New window | `Ctrl+Shift+N` |

Edit the live config and reload it to change the theme without rebuilding.
Check its syntax with:

```sh
ghostty +validate-config
```

## Berkeley Mono (purchased font)

Ghostty, Konsole, Zed and VS Code use Berkeley Mono. The font is not in Git; install it
once per machine:

```sh
mkdir -p ~/.local/share/fonts/berkeley-mono
# copy the purchased TTF files (and their license notices) there, then:
fc-cache -f ~/.local/share/fonts/berkeley-mono
fc-match 'Berkeley Mono'
```

`dotfiles/fontconfig/berkeley-mono.conf` is linked to
`~/.config/fontconfig/conf.d/90-berkeley-mono.conf` by
`modules/home/wayland/appearance.nix`. It marks every Berkeley Mono face as
monospace, because some faces lack the flag, so terminals find bold and
italic. Without the font, apps fall back to Hack.

## Fastfetch

`fastfetch` prints a minimal system summary (braille-art NixOS logo, OS, kernel, WM, shell, terminal, CPU, motherboard, both GPUs, RAM, root disk usage).
Config is live in `dotfiles/fastfetch/config.jsonc`; it uses terminal palette colours, so it follows
the active terminal's colour scheme. Sizes are binary (GiB/TiB), so RAM shows the 94 GiB the kernel
makes usable of the installed 96 GB.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Wrong font / no bold | `fc-match 'Berkeley Mono:bold'`; re-run `fc-cache`; `readlink ~/.config/fontconfig/conf.d/90-berkeley-mono.conf` |
| `$TERMINAL` empty | log out and in; see [Plasma](../desktop/plasma.md#session-variables) |
| Ghostty theme hasn't changed | `readlink -f ~/.config/ghostty/config.ghostty`, then `Ctrl+Shift+,`; run `ghostty +validate-config` for errors |

## Related

- [Shell](../desktop/shell.md) · [Plasma](../desktop/plasma.md) · [Developer tools](../dev/tools.md)
