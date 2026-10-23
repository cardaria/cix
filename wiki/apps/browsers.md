---
title: Browsers
category: apps
tags: [brave, brave-origin, firefox, wayland, override, vaapi]
updated: 2026-10-10
---

# Browsers

Brave Origin is the default browser (`$BROWSER`, `http(s)`, `mailto`, HTML).
Firefox is installed as an alternative with its built-in look. Profiles are
never in Git.

## Brave Origin

`modules/home/apps/brave-origin.nix` uses the locked nixpkgs package with three adjustments:

| Adjustment | Why / what |
| --- | --- |
| `--ozone-platform=wayland` | native Wayland |
| `--enable-features` | adds `VaapiOnNvidiaGPUs` so video decodes on the NVIDIA desktop GPU instead of the CPU. It repeats the wrapper's features, because Chromium keeps only the last `--enable-features` |
| `postInstall` | installs `initial_preferences` |

### Window frame workaround

With Brave's own window frame, Brave Origin could launch with its content
shifted left inside the window border until focus moved (seen under a
wlroots compositor). Disabling the custom frame fixed it. If KWin doesn't
show the offset, the workaround can go.

- New profiles get this from `dotfiles/brave-origin/initial_preferences.json`
  (`browser.custom_chrome_frame = false`), which Chromium reads only on first run.
- For an existing profile, enable **Use system title bar and borders**, or
  with Brave fully closed, set that JSON key in
  `~/.config/BraveSoftware/Brave-Origin/Default/Preferences` (back it up first).
- Set it back to `true` to undo.

### Updates

Brave's version follows the locked nixpkgs input. Update it through
[Deployment](../deployment.md#update-packages), then check video decoding
and the window-frame workaround again. Inspect the locked version with:

```sh
nix eval --raw ".#nixosConfigurations.$(hostname).pkgs.brave-origin.version"
```

Only add a temporary release override when a specific newer version is
needed; use a version guard and remove it once nixpkgs catches up
([Nix packaging](../dev/nix-packaging.md#self-expiring-overrides)).

## Scaling

Brave runs as a native Wayland client and follows KWin's 150% scale through
fractional-scale-v1; it has no scale flag ([Plasma](../desktop/plasma.md#display-and-scaling)).

## Firefox

Installed from nixpkgs (`modules/home/apps/default.nix`) with no managed config.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Blurry text or double-sized UI | `brave://gpu` → Ozone platform must be Wayland; no `--force-device-scale-factor` in `ps -o args -C brave` |
| Content offset inside the border | the custom frame is still on in this profile. See above |
| X11/XWayland blurry window | check `brave://gpu` → Ozone platform should be Wayland |
| High CPU while playing video | `brave://media-internals` → the playing video → `kVideoDecoderName`. `VaapiVideoDecoder` is hardware; `VpxVideoDecoder`/`Dav1dVideoDecoder` is the CPU. |

## Related

- [Plasma](../desktop/plasma.md) · [Nix packaging](../dev/nix-packaging.md)
- memory: `brave-vaapi-nvidia`
