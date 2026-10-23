---
title: Deployment
category: overview
tags: [rebuild, workflow, updates, git, nixos-rebuild]
updated: 2026-10-24
---

# Deployment

The everyday loop is **edit → check → build → test → switch → commit**.
Live dotfiles skip most of it.

## Contents

1. [Add or remove an application](#add-or-remove-an-application)
2. [Build and apply](#build-and-apply)
3. [Live dotfiles](#live-dotfiles)
4. [Update packages](#update-packages)
5. [Update the guests on pve](#update-the-guests-on-pve)
6. [Save to GitHub](#save-to-github)
7. [Troubleshooting](#troubleshooting)

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

```sh
cix update draba
```

It updates the flake inputs (not the CUDA pin), runs checks, builds, shows the
changes from the previous boot configuration, then asks to install the build
for the next boot. It uses `nixos-rebuild boot`, so the desktop and its services
are not restarted during an update. Save your work and reboot yourself when
ready. When using HDMI, keep selecting `display-5090` in GRUB; the base entry
uses DisplayPort. Both entries are registered with the new generation.

Declining the installation keeps the build and updated lock file for review.
Use `--no-update` to retry without moving inputs again. Working-tree edits
require confirmation, and untracked files must be reviewed and staged first.
See [cix CLI](dev/cli.md#updating-safely) for logs and recovery details.

Before the inputs, it runs `cix backup --auto --check`: silent while every recovery key
has a verified 1Password copy. A failure stops the update; run `cix backup`
separately to resolve it
([Secrets](security/secrets.md#back-up-the-key-1password)).

| Command | Does |
| --- | --- |
| `cix update draba` | update everything except the CUDA pin, check, build, ask before preparing the next boot |
| `cix update draba --cuda` | also bump the CUDA pin (`nixpkgs-cuda`), which recompiles `chandra-ocr` and `ninfer` dependencies locally |
| `cix update draba --dry-run` | update, check and build only; no privileged commands |
| `cix update draba --no-update` | check and build the current lock file, then ask before preparing the next boot |
| `cix update` | list the targets; changes nothing |

The CUDA pin keeps the long local CUDA compile out of normal updates. Run
`cix update draba --cuda` only when you want a newer CUDA stack.

After reboot, check the affected apps, `systemctl --failed`, and
`systemctl --user --failed`. From
the desktop, `run0` replaces `sudo` for single commands (KDE's polkit agent shows
the password prompt). There is no separate `home-manager switch`. Changes to the
login manager should be applied from TTY2 ([Login](desktop/login.md#workflows)).
plasma-manager writes Plasma settings at activation; KWin and plasmashell pick
most of them up at the next login.

### Without cix update

For a config change with no input update, build and preview first. This is safe
in either entry:

```sh
cd ~/Repos/cix
nix fmt
nix flake check
cix_candidate=$(nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel" --no-link --print-out-paths --no-write-lock-file)
cix_before=$(readlink -f /run/current-system)
nix store diff-closures "$cix_before" "$cix_candidate"
```

Then check the entry you booted with `readlink -f /run/current-system`.

**Base entry:**

```sh
sudo nixos-rebuild dry-activate --store-path "$cix_candidate" --no-reexec
sudo nixos-rebuild test --store-path "$cix_candidate" --no-reexec
sudo nixos-rebuild switch --store-path "$cix_candidate" --no-reexec
```

Undo a `test` with `sudo nixos-rebuild test --store-path "$cix_before" --no-reexec`.

| Step | Meaning |
| --- | --- |
| `nix build` | builds in `/nix/store`, changes nothing |
| `dry-activate` | shows which services would restart |
| `test` | activates now, but a reboot returns to the previous generation |
| `switch` | activates and makes it the boot default (updates GRUB) |

### Booted into a specialisation

If the path contains `display-5090`, never activate the base closure: it switches
the display GPU, stops the login manager and locks the card behind your screen,
which leaves a dead screen. Never run `test` or `switch` with `$cix_candidate`.
Activate the specialisation's own closure instead:

```sh
sudo "$cix_candidate/specialisation/display-5090/bin/switch-to-configuration" dry-activate
sudo "$cix_candidate/specialisation/display-5090/bin/switch-to-configuration" test
sudo nix-env -p /nix/var/nix/profiles/system --set "$cix_candidate"
sudo "$cix_candidate/bin/switch-to-configuration" boot
readlink -f /nix/var/nix/profiles/system
```

Run `dry-activate` first: `plasmalogin` or `cix-desktop-gpu` among the units it
would stop or restart means the display GPU would change. A `plasmalogin`
under "would NOT stop" is only a rebuilt binary that takes effect at the next
reboot. The last line must end in the new nixpkgs revision. `switch-to-configuration boot`
alone only rebuilds GRUB from the registered generations, so without the
`nix-env --set` line the next reboot returns to the previous build. Both GRUB
entries belong to the same generation, so both pick up the update.

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

Start from a clean, committed tree, then:

```sh
cix update draba
```

It updates `nixpkgs`, `home-manager`, `plasma-manager`, `chandra-src` and
`chandra-model` (OCR code and model metadata), then follows the flow above.
`--cuda` also moves `nixpkgs-cuda`.
Review the lock afterwards with `git diff -- flake.lock`. Also check:

- **Kernel + NVIDIA** move together. Reboot and test DisplayPort, lock,
  and suspend/resume within a week: the weekly cleanup keeps only the last
  7 days of generations (never fewer than 5).
- **Brave**: check Wayland, window borders and hardware video decoding ([Browsers](apps/browsers.md)).
- **Plasma**: log out and in; check Krohnkite and the shortcuts ([Plasma](desktop/plasma.md)).
- Chandra: fetch the locked model with `cix ocr fetch` after switching,
  then verify a representative image/PDF ([Local OCR](dev/local-ocr.md)).
- Never bump `system.stateVersion` / `home.stateVersion`.

Commit the lock on its own: `chore(flake): update nixpkgs and home-manager`.

## Update the guests on pve

```sh
cix update pve       # every guest
cix update <guest>   # one guest
```

Runs from `draba` against the private pve repo (`~/Repos/pve`), which declares the guests and their
registry: machines, services, health checks and update settings. A new guest needs no change here.
In order:

1. **Health first.** Every health check in the registry passes, and no target has a failed unit.
   Otherwise it stops: an unhealthy start hides what the update breaks.
2. **Inputs and images.** It moves that repo's `nixpkgs-stable` (the NixOS base) and `nixpkgs-pve`
   (the apps), then follows each pinned container image's tag to its current digest and moves the pin.
3. **Checks and builds** from one snapshot of the tree, like `cix update draba`.
4. **One review**, per guest: the image versions, then the package versions that change. Major
   version jumps are listed again at the end. For `pve` it also shows the Proxmox host's pending
   apt updates and whether it needs a reboot; the host is yours to update.
5. **One question**, then the downloads: every build and image lands on the guests first, while the
   DNS still works.
6. **Deploys, stage by stage** (`update.stage`; the guest serving DNS last). After each guest every
   check must pass again and the guest must have no failed units within `update.settle` seconds, or
   the run stops and prints the command that returns that guest to its previous build. A guest with
   `update.autoRollback` returns to it by itself.

| Option | Does |
| --- | --- |
| `--dry-run` | update, check, build and review; deploy nothing |
| `--no-update` | deploy the current lock and pins, for a retry after a stop or a decline |
| `--no-images` | leave the container pins as they are |

The inputs are shared: `cix update <guest>` moves them for every guest, and the others take them at
their next deploy. A guest whose containers are `self-managed` is only reported. When the run is
done, commit `flake.lock` and the pins in the pve repo.

## Save to GitHub

```sh
git status --short
git diff
git add <paths>
git diff --cached --check
git commit -m "feat(apps): add signal-desktop"
git push origin main
```

Never `git add -A` blindly, and never keys or plaintext. Message format: `type(scope): description` (`feat`, `fix`, `refactor`, `chore`, `docs`).
Commit KWin display-config churn (`dotfiles/kwin/`) separately as `chore(kwin): …`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "path does not exist" for a new file | `git add` it (Git flakes skip untracked files) |
| "would be clobbered" during activation | an unmanaged file is in the way. Move it aside |
| Rebooted after a manual `test` and the change is gone | expected: `test` isn't persistent. Use `nixos-rebuild boot --store-path <candidate> --no-reexec` as root to prepare that build for the next boot |
| Update ended the desktop session or failed with a portal display error | live activation can restart the login manager and disrupt user services. `cix update` now prepares the next boot without live activation |
| Boot installation failed | follow the printed retry or previous-build recovery command before rebooting; a changed profile alone does not prove the boot menu was written |
| Rebooted after `boot` and still on the old build | the `nix-env --set` step was skipped. See [Booted into a specialisation](#booted-into-a-specialisation) |
| `cix update` build takes very long | something bumped CUDA (`--cuda`) and its unfree packages compile locally. Wait; it is a one-time cost per version |
| Dead screen right after `test`/`switch` | you were booted into a specialisation and activated the base. Power-cycle, pick the same GRUB entry, then see [Booted into a specialisation](#booted-into-a-specialisation) |
| Something broke after `switch` | `sudo nixos-rebuild switch --rollback --no-reexec`, or pick an older entry in GRUB |

## Related

- [Flake](architecture/flake.md) · [Constraints](constraints.md) · [Boot & recovery](system/boot.md)
- Agent skill: `nixos-change`
