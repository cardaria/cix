---
title: Plasma
category: desktop
tags: [plasma, kwin, krohnkite, plasma-manager, shortcuts, scaling, gpu]
updated: 2026-10-10
---

# Plasma

KDE Plasma 6 on Wayland is the desktop: KWin composites on the RTX 5060 LP,
Krohnkite tiles windows; KDE apps cover files, documents, images, video and screenshots.
Plasma settings use [plasma-manager](https://github.com/nix-community/plasma-manager); everything
else stays in Plasma's own GUI.

## Contents

- [Where things are](#where-things-are) · [Apps](#apps)
- [Tiling](#tiling-krohnkite)
- [Shortcuts](#shortcuts)
- [Panel](#panel)
- [Display and scaling](#display-and-scaling)
- [GPU selection](#gpu-selection)
- [Session variables](#session-variables)
- [Troubleshooting](#troubleshooting)

## Where things are

| Piece | File |
| --- | --- |
| Plasma, KDE apps, portals, KWallet | `modules/nixos/desktop.nix` (`services.desktopManager.plasma6`) |
| Login manager | `modules/nixos/login.nix` ([Login](login.md)) |
| Krohnkite, shortcuts, panel, keyboard, desktops | `modules/home/wayland/plasma.nix` (`programs.plasma`) |
| Monitor mode and scale | `dotfiles/kwin/draba/kwinoutputconfig.json` |
| KWin's GPU | `hosts/draba/graphics.nix` (`cix-desktop-gpu` service) |
| Fonts | `modules/home/wayland/appearance.nix` |

plasma-manager writes only the keys it declares, at activation. A setting
changed in System Settings survives until the next activation, unless Nix
declares the same key. `overrideConfig` is off, so undeclared settings are
never reset. To keep a GUI change across reinstalls, add it to
`plasma.nix`; `nix run github:nix-community/plasma-manager -- rc2nix` prints
the current Plasma config as plasma-manager options.
Saved appearance, animation speed, mouse actions and file views: [Preferences](preferences.md).

## Apps

`services.desktopManager.plasma6` installs Plasma's default apps: Dolphin,
Konsole, Kate, Okular, Gwenview, Ark, Elisa, Spectacle and Plasma System
Monitor. KRunner, Klipper (clipboard) and the screen locker are part of
Plasma itself. Haruna and KCalc come from `modules/home/apps/default.nix`.
Merkuro Calendar and its Akonadi backend use `programs.kde-pim` in the desktop
module; KMail, Kontact and Discover are disabled.

### Dolphin

Dolphin uses Details as the common display style for all folders, declared
in `plasma.nix`: `dolphinrc` enables `GlobalViewProps`, and the shared
`dolphin/view_properties/global/.directory` sets the view mode. Reopen
Dolphin after changing these settings. Special media-search results can
still use Dolphin's own layouts.

### System Monitor overview

`dotfiles/plasma-systemmonitor/overview.page` is the Overview page: four
headed rows of five gauges or graphs each, sized to fit one screen. CPU &
Memory (usage, frequency, temperature, RAM, swap); RTX 5090 and RTX 5060
(usage, frequency, temperature, power, VRAM); Storage & Network (both SSD
temperatures, Linux disk space, disk and network activity graphs without
axis labels). Colours are Breeze's highlight blue and its darker blue only.
`modules/home/apps/plasma-systemmonitor.nix` links the directory to
`~/.local/share/plasma-systemmonitor`, because System Monitor saves pages by
rename; edits made in the app land in the repo. Only `overview.page` is tracked;
the app's copies of other pages stay ignored.
GPU queries use the fixed `nvidia-smi` grant ([GPU access](../architecture/gpu-access.md)).

- Close System Monitor before editing the file by hand: it writes its loaded
  page back when it exits (the process is `.plasma-systemmonitor-wrapped`;
  `pgrep -f systemmonitor` finds it).
- `version=1` in `[page]` makes the file self-contained; without it the app
  layers it over its built-in default page.
- `gpu0` is the RTX 5090 and `gpu1` the RTX 5060 in ksystemstats' order; the
  titles name the cards. NVMe sensors and the disk entry are host-specific
  (`kstatsviewer --list` shows them).

## Tiling (Krohnkite)

Krohnkite is a KWin script, installed in the user profile and enabled through
`kwinrc` (`[Plugins] krohnkiteEnabled=true`), because plasma-manager has no
option for it. Gaps are `gap` = 8 logical px (12 physical at 150%) at the sides,
bottom and between windows, matching the floating panel's own margin. The top
gap follows the panel, set by `panelHeight`, `panelFloating` and `panelHiding`
in `plasma.nix`, which drive both the panel and `kwinrc` `[Script-krohnkite]`:

| `panelHiding` | Reserves | Top gap |
| --- | --- | --- |
| `windowsgobelow`, floating | nothing | `panelHeight + 2 * gap`, so windows clear the bar |
| `windowsgobelow`, not floating | nothing | `panelHeight + gap` |
| `normalpanel`, floating | the bar height | `2 * gap`, but Plasma un-floats this panel next to windows |
| `normalpanel`, not floating | the bar height | `gap` |
| `autohide`, `dodgewindows` | nothing, the panel overlays windows | `gap` |

Reserved areas were measured from KWin for `normalpanel` and `windowsgobelow`;
`autohide` and `dodgewindows` follow the Plasma source. Panel changes therefore
need no gap edits. Changing floating or hiding live in
Plasma is not followed; edit `plasma.nix`.
A lone tiled window is centered at 60% of the available width and 100% of
the available height (`soleWindowWidth=60`, `soleWindowHeight=100`), using
Krohnkite's built-in options. The local patch in `pkgs/krohnkite/` applies
the declared screen-edge gaps after sizing that window, keeping the
top and bottom padding. Multiple tiles keep their usual gaps. Monocle's
default maximize setting takes precedence, as does the sole-window "No
Gaps" option (leave it off to use percentages and padding).
A second patch re-tiles when the panel appears, so a window opened at
login before the panel exists is moved out from under it.

Other settings stay in System Settings → Window Management → KWin Scripts
→ Krohnkite → Options (including the Sole Window controls). After changing
settings or activating a rebuilt configuration, log out and back in so
Krohnkite reads the new values. Avoid toggling the script off and on:
upstream warns that it can start duplicate instances.

## Shortcuts

Declared in `plasma.nix`. Krohnkite's defaults that collide with these or
with Plasma's are unbound, and so are the Plasma defaults on the same keys.

| Key | Action |
| --- | --- |
| `Meta+Return` / `Ctrl+Alt+T` | Ghostty |
| `Meta+B` | Brave Origin |
| `Meta+A` / `Meta+E` | Dolphin |
| `Meta+D` / `Alt+Space` | KRunner |
| `Meta` | application launcher |
| `Meta+,` / `Meta+I` | System Settings |
| `Meta+Q` | close window |
| `Meta+F` | fullscreen |
| `Meta+Space` | toggle floating (Krohnkite) |
| `Meta+M` / `Meta+Shift+M` | next / previous tiling layout, through all of Krohnkite's layouts |
| `Meta+←/→/↑/↓` | focus window (Krohnkite) |
| `Meta+Shift+←/→/↑/↓` | move window in the layout (Krohnkite) |
| `Meta+-` / `Meta+Shift+0` | narrower / wider (Krohnkite) |
| `Meta+Tab` / `Meta+W` | Overview |
| `Meta+1…3` | switch to desktop 1–3 (one row, fade transition) |
| `Meta+Shift+1…3` | move window to desktop 1–3 |
| `Meta+V` | clipboard history (Klipper) |
| `Meta+L` | lock |
| `Meta+Escape` / `Meta+Shift+E` | log out dialog |
| `Print` / `Meta+Shift+S` | Spectacle (region) |
| `Ctrl+Print` / `Shift+Print` | full-screen screenshot |

KWin hands global shortcuts the symbol a key produces: on the Swedish layout
`Meta+Shift+1` arrives as `Meta+!`, so the move-to-desktop bindings are
declared as `Meta+!`, `Meta+"` and `Meta+#`.

## Panel

Top panel, 30 px high, floating, with Windows Go Below hiding: it stays floating
and visible, and Krohnkite keeps a fixed gap under it. Layout, spacers, tray
choices and rebuild behavior: [Preferences](preferences.md#panel).

## Display and scaling

The LG monitor runs at 3840×2160, 160 Hz, scale 150%, with KWin's own
fractional scaling. Wayland clients (Qt, GTK 4, Chromium/Electron) render at
1.5× natively; X11 clients follow System Settings → Display → Legacy
Applications. No app has its own scale flag or variable.

- `~/.config/kwinoutputconfig.json` is a live link to
  `dotfiles/kwin/draba/kwinoutputconfig.json`. KWin writes display changes
  from System Settings back into the repo, like any live dotfile.
- KWin finds the entry by the monitor's EDID identity (which contains its
  serial), never by connector name. A different monitor gets KWin's
  defaults, then its own entry once you change something.
- The greeter reads a store copy of the same file ([Login](login.md)).
- The kernel console runs at the same 160 Hz mode, so nothing switches modes
  from boot to the desktop ([draba](../architecture/draba.md#early-kms-and-console-mode)).

## GPU selection

At boot `cix-desktop-gpu` selects the RTX 5060 LP and writes
`/run/cix-desktop-gpu/kwin.env`: `KWIN_DRM_DEVICES` limits outputs to that card;
`KWIN_RENDER_NODES` limits rendering to its render node. The greeter reads a
unit drop-in; the session sources `/etc/xdg/plasma-workspace/env/cix-desktop-gpu.sh`.
If exactly one matching card isn't found, the service and login fail. See
[draba](../architecture/draba.md#two-gpus-two-jobs) for selection and
[GPU access](../architecture/gpu-access.md) for 5090 permissions.

```sh
systemctl status cix-desktop-gpu; cat /run/cix-desktop-gpu/kwin.env
qdbus org.kde.KWin /KWin org.kde.KWin.supportInformation | grep -iA3 'render\|gpu'
nvidia-smi
```

## Session variables

The login zsh loads `hm-session-vars.sh` through `dotfiles/zsh/.zshenv`.
Plasma inherits `EDITOR`/`VISUAL=zeditor --wait`, `BROWSER`, and `TERMINAL=ghostty`,
then copies the environment into the systemd user manager.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Shortcut does nothing | System Settings → Shortcuts: is it taken twice? The next activation rewrites declared keys |
| Krohnkite doesn't tile | `kreadconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled` should be `true`; `ls /etc/profiles/per-user/$USER/share/kwin/scripts` |
| Wrong scale or 60 Hz | `kscreen-doctor -o`; is `~/.config/kwinoutputconfig.json` a link into the repo? Does its `edidIdentifier` match `journalctl --user -b -g kwin_wayland`? |
| Desktop renders on the 5090 | `cat /run/cix-desktop-gpu/kwin.env`; `systemctl --user show-environment \| grep KWIN` |
| Login manager missing at boot | `journalctl -b -u cix-desktop-gpu` |
| Variable missing in apps | `systemctl --user show-environment`; log out and in after a switch |
| Screen sharing does nothing, no window list (TeamSpeak, Vesktop, gpu-screen-recorder) | the portal lacks KDE: `busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \| grep ScreenCast`. `systemctl --user restart xdg-desktop-portal`. Its unit only starts when `XDG_CURRENT_DESKTOP` is set, so a logout can't leave a GTK-only portal behind |
| System Monitor panel empty or "missing sensor" | the sensor ID changed (new disk, GPU order): `kstatsviewer --list`, then fix it in the app (Edit Page) or in `overview.page` |
| Panel reset after a rebuild | expected when the panel declaration changed |
| Monochrome or odd colours everywhere | a stale scheme baked into `~/.config/kdeglobals`: `plasma-apply-lookandfeel --apply org.kde.breeze.desktop` |

## Related

- [Login](login.md) · [Shell](shell.md) · [draba](../architecture/draba.md) · [Terminal](../apps/terminal.md)
- memory: `rtx5060-display-rtx5090-compute`, `plasma-kwin-gpu-env`, `kwin-output-config-dotfile`, `portal-needs-desktop-env`, `systemmonitor-overview-style`
