---
title: Deployment
category: overview
tags: [rebuild, workflow, updates, git, nixos-rebuild]
updated: 2026-10-13
---

# Deployment

The everyday loop is **edit → check → build → test → switch → commit**.
Live dotfiles skip most of it.

## Contents

1. [Add or remove an application](#add-or-remove-an-application)
2. [Build and apply](#build-and-apply)
3. [Live dotfiles](#live-dotfiles)
4. [Update packages](#update-packages)
5. [Save to GitHub](#save-to-github)
6. [Troubleshooting](#troubleshooting)

## Add or remove an application

- **Package only:** add it to `home.packages` in `modules/home/apps/default.nix`
  (dev tools go in `development.nix`). Remove it from there to uninstall.
- **With config:** create `modules/home/apps/<app>.nix`, import it in
  `home/cardaria/default.nix`, and put native files in `dotfiles/<app>/`:

```nix
{ dotfile, pkgs, ... }:
{
  home.packages = [ pkgs.myapp ];
  xdg.configFile."myapp".source = dotfile "myapp";
}
```

- Move any existing `~/.config/myapp` aside first, because Home Manager refuses
  to overwrite unmanaged files.
- `git add` the new files before building: Git flakes skip untracked files.
- Register the module in `wiki/_sources.yaml` (otherwise `nix flake check` fails).
- Small permanent assets go in `dotfiles/<app>/assets/` with a credit (e.g. Plex's icon).

## Build and apply

> [!WARNING]
> Run `readlink -f /run/current-system` first. If it contains `display-5090`, you are
> booted into the specialisation: **do not run `test`/`switch` with `$cix_candidate`
> below**. That freezes the machine. Use
> [Booted into a specialisation](#booted-into-a-specialisation) instead.

```sh
cd ~/Repos/cix
nix fmt
nix flake check
cix_candidate=$(nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel" \
  --no-link --print-out-paths --no-write-lock-file)
cix_before=$(readlink -f /run/current-system)
nix store diff-closures "$cix_before" "$cix_candidate"     # what changes
sudo nixos-rebuild dry-activate --store-path "$cix_candidate" --no-reexec
sudo nixos-rebuild test         --store-path "$cix_candidate" --no-reexec
```

| Step | Meaning |
| --- | --- |
| `nix build` | builds in `/nix/store`, changes nothing |
| `dry-activate` | shows which services would restart |
| `test` | activates now, but a reboot returns to the previous generation |
| `switch` | activates and makes it the boot default (updates GRUB) |

Check the affected apps and `systemctl --failed`. Then either make it persistent or undo:

```sh
sudo nixos-rebuild switch --store-path "$cix_candidate" --no-reexec   # keep
sudo nixos-rebuild test   --store-path "$cix_before"    --no-reexec   # undo
```

From the desktop you can use `run0 /run/current-system/sw/bin/nixos-rebuild …`
(KDE's polkit agent shows the password prompt). On a plain TTY use `sudo`. There is no
separate `home-manager switch`. Changes to the login manager should be applied from
TTY2 ([Login](desktop/login.md#workflows)). plasma-manager writes Plasma
settings at activation; KWin and plasmashell pick most of them up at the
next login.

### Booted into a specialisation

`readlink -f /run/current-system` names the entry you booted (on draba the path
contains `display-5090`). Never activate the base closure from there: it
switches the display GPU, stops the login manager and locks the card behind
your screen, which leaves a dead screen. Activate the specialisation's own
closure instead:

```sh
sudo "$cix_candidate/specialisation/display-5090/bin/switch-to-configuration" test   # running session only
sudo "$cix_candidate/bin/switch-to-configuration" boot                               # base stays the GRUB default
```

Run `dry-activate` first: if it lists `plasmalogin` or `cix-desktop-gpu`, you
are about to change the display GPU.

## Live dotfiles

Edit `dotfiles/<app>/…`, then reload the app. No rebuild is needed:

| App | Reload |
| --- | --- |
| Zed | automatic on save |
| zsh | `source "$ZDOTDIR/.zshrc"` |
| KWin display config | written by System Settings → Display; don't hand-edit while Plasma runs |
| others | restart the app |

A rebuild is needed when you change packages, imports or link declarations.

## Update packages

Start from a clean, committed tree:

```sh
nix flake update nixpkgs home-manager plasma-manager     # or: nix flake update <input>
nix flake update chandra-src chandra-model  # OCR code and model metadata
git diff -- flake.lock
```

Then build/test/switch as above, and also check:

- **Kernel + NVIDIA** move together. Reboot and test DisplayPort, lock,
  and suspend/resume within a week: the weekly cleanup keeps only the last
  7 days of generations (never fewer than 5).
- **Brave**: check Wayland, window borders and hardware video decoding ([Browsers](apps/browsers.md)).
- **Plasma**: log out and in; check Krohnkite and the shortcuts ([Plasma](desktop/plasma.md)).
- Chandra: fetch the locked model with `cix-ocr fetch` after switching,
  then verify a representative image/PDF ([Local OCR](dev/local-ocr.md)).
- Never bump `system.stateVersion` / `home.stateVersion`.

Commit the lock on its own: `chore(flake): update nixpkgs and home-manager`.

## Save to GitHub

```sh
git status --short
git diff
git add <paths>              # never add -A blindly; never keys or plaintext
git diff --cached --check
git commit -m "feat(apps): add signal-desktop"
git push origin main
```

Message format: `type(scope): description` (`feat`, `fix`, `refactor`, `chore`, `docs`).
Commit KWin display-config churn (`dotfiles/kwin/`) separately as `chore(kwin): …`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "path does not exist" for a new file | `git add` it (Git flakes skip untracked files) |
| "would be clobbered" during activation | an unmanaged file is in the way. Move it aside |
| Rebooted after `test` and the change is gone | expected: `test` isn't persistent. Use `switch` |
| Dead screen right after `test`/`switch` | you were booted into a specialisation and activated the base. Power-cycle, pick the same GRUB entry, then see [Booted into a specialisation](#booted-into-a-specialisation) |
| Something broke after `switch` | `sudo nixos-rebuild switch --rollback --no-reexec`, or pick an older entry in GRUB |

## Related

- [Flake](architecture/flake.md) · [Constraints](constraints.md) · [Boot & recovery](system/boot.md)
- Agent skill: `nixos-change`
