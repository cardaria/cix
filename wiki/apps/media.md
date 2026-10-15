---
title: Media and documents
category: apps
tags: [haruna, merkuro, okular, gwenview, elisa, plex, spotify, spicetify, mimeapps, signal, teamspeak, vesktop, fluxer, obsidian, steam]
updated: 2026-10-15
---

# Media and documents

Viewers, players, calendar and chat apps, plus the table of default applications.

## Default applications

`dotfiles/mimeapps/mimeapps.list` (live-linked to `~/.config/mimeapps.list`):

| Type | Opens with |
| --- | --- |
| Folders | Dolphin |
| Web links, HTML, `mailto:` | Brave Origin |
| PDF | Brave Origin |
| Images (png, jpg, webp, avif, heic, jxl, svg, …) | Gwenview |
| Plain text, Markdown, JSON, YAML, TOML, source files | Zed |
| `spotify:` links | Spotify |
| `discord:` links | Vesktop |
| `fluxer:` links | Fluxer |
| `claude-cli:` links | Claude Code |

Edit the file in the repo; it applies at once while the link is intact.
KDE (System Settings → Default Applications, or an app registering itself
through `xdg-settings`) saves by replacing the file, which breaks the link;
the next activation puts the link back (`force = true`) and drops those
changes. Copy anything worth keeping from `~/.config/mimeapps.list` into the
repo first.

## Apps

| App | Module | Notes |
| --- | --- | --- |
| **Okular**, **Gwenview**, **Elisa**, **Ark**, **Spectacle** | Plasma (`modules/nixos/desktop.nix`) | documents, images, music, archives, screenshots ([Plasma](../desktop/plasma.md#apps)) |
| **Haruna**, **KCalc** | `apps/default.nix` | video player (mpv-based, MPRIS), calculator |
| **Merkuro Calendar** | `modules/nixos/desktop.nix` | Kalendar's current name; native KDE PIM integration supplies Akonadi and calendar resources |
| **Plex Desktop** | `apps/plex.nix` | custom icon from `dotfiles/plex/assets/plex.png`, referenced by absolute path so it is independent of the icon theme; launcher subtitle "Media Player"; the launcher runs Mesa's GL on the desktop GPU through Zink and pins the video decoder to it (see below) |
| **Spotify** | `apps/spotify.nix` | official client, run from a writable copy so Spicetify can patch it; `dotfiles/spicetify/` linked; Spicetify Marketplace for themes and extensions |
| **Obsidian** | `apps/obsidian.nix` | opens the `lepidium` vault on the cloud share ([Network share](../system/network-share.md)) |
| Signal | `apps/default.nix` | plain package; Electron follows KWin's scale on Wayland |
| **TeamSpeak 6** | `apps/teamspeak.nix` | `hotkey_helper` (global hotkeys) loads libX11/libXi at runtime; the override adds them to its runpath, without which it crashes at start. It reads keys through Xwayland, so global hotkeys may only fire while an X11 window has focus |
| **Vesktop** | `apps/vesktop.nix` | package plus autostart: `~/.config/autostart/vesktop.desktop` runs the wrapped `vesktop --start-minimized` at login |
| **Fluxer** | `apps/fluxer.nix` | local package `pkgs/fluxer/` (upstream stable AppImage, not in nixpkgs) plus autostart: `~/.config/autostart/app.fluxer.FluxerDesktop.desktop` runs the wrapped `fluxer --autostart` at login |
| **Steam** | `modules/nixos/desktop.nix` | `programs.steam`: FHS runtime, 32-bit graphics, controller rules (see below) |
| nvtop, gpu-screen-recorder, wl-clipboard | `apps/default.nix` | package-only |

## Notes per app

**Merkuro Calendar:** launch it from the application menu or with
`merkuro-calendar`. [Kalendar was renamed Merkuro](https://kde.org/announcements/gear/23.08.0/).
It supports local calendars and online accounts such as CalDAV. Calendars,
accounts and events are user data, outside Git. KMail and Kontact remain disabled.

**Obsidian:** Home Manager registers the vault in `~/.config/obsidian/obsidian.json`
and writes nothing inside it; the notes and the vault's `.obsidian/` settings
stay on the share. Changes made from other devices appear after reopening the
vault, since SMB doesn't report remote edits to file watchers. Updates come with
the flake, so Obsidian's own updater is off.

**Spotify:** the `spotify` command copies the store's Spotify to
`~/.local/share/spotify-spicetify` on first launch and whenever the Spotify,
Spicetify or Marketplace package changes, clears Spicetify's old backup, then runs
`spicetify backup apply` on the copy. The store is read-only, so Spicetify
can't patch it in place. Clearing matters: backing up an already-patched copy
patches the JS twice and Spotify falls back to its built-in code, whose class
names no longer match the patched CSS (the whole layout stacks vertically).
The copy's `spotify` script is replaced with the wrapper, so restarts that
Spicetify triggers also run the patched copy. Accounts and caches stay outside Git.

**Spicetify:** [Marketplace](https://github.com/spicetify/marketplace) is
installed as a custom app (pinned release in `apps/spotify.nix`), with its
placeholder theme as `current_theme = marketplace`. Themes, extensions and
snippets are then picked inside Spotify (Marketplace in the sidebar) and stored
in Spotify's own profile, not in Git. The [adblock](https://github.com/rxri/spicetify-extensions/tree/main/adblock)
extension (pinned in `apps/spotify.nix`, `extensions = adblock.js`) hides
sponsored shelves, home-page takeovers and upsell popups. Home Manager can't place links inside the
out-of-store `~/.config/spicetify`, so the launcher links
`CustomApps/marketplace`, `Themes/marketplace` and `Extensions/adblock.js` on every start;
`Themes/`, `Extensions/` and `CustomApps/` are gitignored. After editing
`config-xpui.ini` by hand, run `spicetify apply`.
Keep `expose_apis` and `home_config` on: with Spotify's
V8-snapshot builds, Spicetify only injects the patched `xpui-modules.js` when
a helper or extension is enabled.

**Vesktop:** Home Manager owns its autostart entry. Vesktop's own "Start with
system" writes the raw `electron-unwrapped` path into that file, skipping the
Nix wrappers, and that Electron crashes (SIGILL) at login. Leave the toggle
alone; the entry already exists, so Vesktop shows it as on.

**Fluxer:** the stable channel. The desktop shell updates with the
package (bumping is in `pkgs/fluxer/README.md`); the app's UI modules update
themselves into `~/.config/fluxer/modules`. Home Manager owns its autostart entry, as
with Vesktop: Fluxer's own entry runs the unwrapped binary, which fails
outside the AppImage's FHS environment. Leave the in-app autostart
toggle alone. On start the app registers itself for `fluxer:` links with
`xdg-mime` unless it already is the handler, which would replace the
`mimeapps.list` link; the repo's list names it so that never runs.
Home Manager writes `~/.config/fluxer-flags.conf` with the same
VA-API features as Brave, so video decodes on the GPU.

**Steam:** the nixpkgs package is only the bootstrap. The client updates
itself into `~/.local/share/Steam`, and the games live there too, outside Git.
Remote Play and LAN transfer ports stay closed. Games render on the 5060,
because the [GPU access policy](../architecture/gpu-access.md) denies desktop
processes the 5090. To play on the 5090, boot the `display-5090` entry
([draba](../architecture/draba.md)).

**Plex:** to change the icon, replace `dotfiles/plex/assets/plex.png` (keep
the credit in its README) and rebuild. Assets are copied into the store.

Plex is a Qt 5 app in an FHS sandbox that only has Mesa's OpenGL, and Mesa has
no driver for NVIDIA cards. Without help it fell back to `llvmpipe`: a laggy
interface and a black or striped picture (audio and subtitles still work). The
`plex-desktop` launcher therefore asks the desktop GPU's PCI IDs from
`cix-desktop-gpu` and sets up Mesa's Zink driver (OpenGL on NVIDIA's Vulkan
driver) for that card: `MESA_LOADER_DRIVER_OVERRIDE`, `MESA_VK_DEVICE_SELECT`
and `VK_DRIVER_FILES`. Plex logs `OpenGL VENDOR: Mesa RENDERER: zink Vulkan …
RTX 5060` when it works.

Its player uses `vaapi-copy`; `dotfiles/plex/draba/mpv.conf` is live-linked to
`~/.local/share/plex/mpv.conf`. It selects the desktop card through
`vaapi-device=/dev/dri/cix-desktop-render`, a link udev creates for the
5060's render node from its PCI IDs (`hosts/draba/graphics.nix`), so bus
renumbering can't move it. Without that setting,
mpv opens the first render node, which is the 5090 on this machine, even
when Zink draws the interface on the 5060. Plex reads this config before
each playback; quit and reopen Plex to release an existing decoder context.
If that device cannot decode, mpv falls back to software decoding.

The system's NVIDIA VA-API driver is
patched to decode on the card behind the render node it is given
([draba](../architecture/draba.md)); the stock driver used the 5090 and Plex's
mpv crashed in `vaGetImage`. Don't set `CUDA_VISIBLE_DEVICES` for Plex: it renumbers
the CUDA devices under the driver. No card IDs live in the Plex module.
The central [GPU access policy](../architecture/gpu-access.md) also denies
the desktop process access to the 5090, independently of these preferences.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| File opens in the wrong app | `xdg-mime query default <mime/type>`; edit `mimeapps.list` |
| Repo edit to `mimeapps.list` has no effect | `ls -l ~/.config/mimeapps.list` is a regular file: KDE replaced the link. Copy its changes into the repo, delete the file, then switch (Home Manager leaves an identical regular file in place) |
| Media keys don't control a player | `playerctl -l` lists MPRIS players; Plasma's media controller uses the same |
| Plex window appears, then quits after seconds | `coredumpctl info Plex`: `nvGetImage` / `vaGetImage` in the stack means the video decoder is on the wrong GPU (is the patched `nvidia-vaapi-driver` in `/run/opengl-driver/lib/dri`? `NVD_LOG=1 plex-desktop` should log `Using /dev/nvidia1`); a stack without `DISPLAY` means KWin's Xwayland isn't running |
| Plex is laggy and the video is black or striped | `grep 'OpenGL VENDOR' ~/.local/share/plex/Logs/Plex.log`: `llvmpipe` means software rendering, so the launcher's Zink settings aren't applied (start it with `plex-desktop` from the launcher, not the raw binary) |
| Plex allocates memory or decodes on the 5090 | check that `~/.local/share/plex/mpv.conf` resolves to the repo's host config and sets `hwdec=vaapi-copy` plus `vaapi-device`, and that `/dev/dri/cix-desktop-render` exists; restart Plex, then check its row in `nvidia-smi` while playing |
| Spotify has the stock look, or its panels stack vertically | quit Spotify, delete `~/.local/share/spotify-spicetify/.store`, start it again (rebuilds the copy and the backup) |
| Fluxer doesn't start at login | is `~/.config/autostart/app.fluxer.FluxerDesktop.desktop` a link into the store? A regular file means Fluxer rewrote it with the unwrapped path: delete it and switch again |
| Fluxer warns that a screen share uses software decoding | quit it from the tray and start it from the launcher: its own restart keeps the old FHS environment |
| Vesktop doesn't start at login | `systemctl --user status app-vesktop@autostart`; is `~/.config/autostart/vesktop.desktop` a link into the store? A regular file means Vesktop rewrote it: delete it and switch again |

## Related

- [Plasma](../desktop/plasma.md) · [Browsers](browsers.md)
- memory: `vesktop-autostart-wrapped`, `plex-vaapi-desktop-gpu`, `speechd-for-electron`, `spicetify-marketplace-choice`
