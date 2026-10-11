---
title: Preferences
category: desktop
tags: [plasma, kde, preferences, appearance, input, panel]
updated: 2026-10-10
---

# Preferences

The current KDE preferences are declared in `modules/home/wayland/plasma.nix`;
device-specific mouse settings live in `hosts/draba/input.nix`.

Committing saves these declarations. A GUI change alone stays in `~/.config`
and does not update the repo. Undeclared keys survive a normal rebuild because
plasma-manager's `overrideConfig` is off, but need a home-directory backup or
an explicit declaration to survive a reinstall.

## Appearance and animations

| Preference | Saved value |
| --- | --- |
| Colour scheme | Breeze Light |
| Icons, widgets, window decorations | Breeze |
| Cursor theme | Breeze cursors |
| Animation duration | 0.5× the default duration |
| Smooth scrolling | off |
| Contrast / frame contrast | 4 / 0.2 |
| System bell | on |
| Cursor shake effect | off |
| Desktop transition | fade |

The selected wallpaper is referenced by its path under `Pictures/Wallpapers`.
The image itself is outside Git; restore Pictures from backup on a new
installation. Purchased fonts also remain outside Git ([Terminal](../apps/terminal.md)).

## Windows and mouse actions

| Preference | Saved value |
| --- | --- |
| Snap to screen edge | off (`BorderSnapZone=0`) |
| Snap to other windows | off (`WindowSnapZone=0`) |
| Focus delay | 0 ms |
| Window-action modifier | Meta |
| Meta + middle mouse button | minimize the window |
| Meta + wheel | previous/next desktop, taking the window under the pointer along |

The wheel setting is KDE's native Window Behavior → Window Actions option,
stored as `CommandAllWheel=Previous/Next Desktop`. It moves the window and
switches the desktop together; there is no custom scroll script.

## Panel

One top panel spans the screen, with a height of 30 logical px, floating style,
adaptive opacity and Windows Go Below hiding. Plasma un-floats an always-visible
panel whenever a window touches it; this mode never does.

The widget order is launcher, 20 px spacer, pager, 20 px spacer, icon-only
task manager, 20 px spacer, margins separator, system tray, clock and
show-desktop. The task manager pins the preferred file manager and browser.
Clicking the current desktop in the pager shows the desktop.

1Password, Spotify, Bluetooth and brightness icons stay in the tray popup.
The currently enabled built-in tray widgets are declared too.

Changing the panel declaration rebuilds it on the next Plasma login. The
wallpaper declaration reapplies the selected image; other desktop widgets
need their own declarations before changing the layout.

## Input

| Device | Saved preference |
| --- | --- |
| G-Wolves mouse | speed −0.3, flat acceleration |
| MonsGeek keyboard's mouse interface | speed 0 |
| Keyboard | Swedish (`se`) |

Device names and vendor/product IDs are in the host module rather than the
shared Plasma module. Changing to another device requires its own entry.

## File views

Dolphin uses Details for all folders, hides its menu bar and fixes Places
icons at 22 px. The common KDE file chooser uses a detailed tree, sorts by
name with directories first, hides hidden files, uses breadcrumb navigation
and keeps inline previews enabled with the separate preview pane off.

## Changing a preference

For a declared setting, edit `plasma.nix` (or the host input module), then
build and switch using [Deployment](../deployment.md#build-and-apply).
Log out and back in after panel or appearance changes.

After experimenting in System Settings, read the corresponding key before
capturing it in Nix. For example:

```sh
kreadconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor
kreadconfig6 --file kwinrc --group MouseBindings --key CommandAllWheel
```

Use a native plasma-manager option where available, and `configFile` for
unsupported settings. Update this page and commit the declaration together.
Timestamps, update history, dialog sizes and device layout IDs are runtime
state and are not copied into the configuration.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| A GUI preference returns to its old value | the same key is declared in Nix; update that declaration |
| A preference is missing after reinstall | check whether it was declared or only saved in the old home directory |
| Wallpaper is missing | restore the selected image under Pictures/Wallpapers |
| Mouse settings have no effect | compare the device name and IDs with `hosts/draba/input.nix` |

## Related

- [Plasma](plasma.md) · [draba](../architecture/draba.md) · [Deployment](../deployment.md)
