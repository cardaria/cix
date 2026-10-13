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

```sh
cix-update
```

One command for everything: it updates the flake inputs, builds, shows what
changes, previews which units restart, then asks `Apply now?` (live, a reboot
undoes it) and `Keep after reboot?`. It checks `readlink -f /run/current-system`
itself and picks the right activation for the entry you booted, so you never
choose between the base and `display-5090` paths. It is defined in
`dotfiles/zsh/.zshrc`; answer `n` at either prompt to stop there. A `n` at the first prompt
leaves only `flake.lock` changed (`git checkout flake.lock` reverts it).

The first build after an input update can take long: unfree CUDA packages are
not in the binary cache and compile locally.

Check the affected apps and `systemctl --failed` (the function prints it). From
the desktop, `run0` replaces `sudo` for single commands (KDE's polkit agent shows
the password prompt). There is no separate `home-manager switch`. Changes to the
login manager should be applied from TTY2 ([Login](desktop/login.md#workflows)).
plasma-manager writes Plasma settings at activation; KWin and plasmashell pick
most of them up at the next login.

### Without cix-update

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
cix-update
```

It updates `nixpkgs`, `home-manager`, `plasma-manager`, `chandra-src` and
`chandra-model` (OCR code and model metadata), then follows the flow above.
Review the lock afterwards with `git diff -- flake.lock`. Also check:

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
| Rebooted after `test` and the change is gone | expected: `test` isn't persistent. Answer `y` to `Keep after reboot?` in `cix-update`, or use `switch` |
| Rebooted after `boot` and still on the old build | the `nix-env --set` step was skipped. See [Booted into a specialisation](#booted-into-a-specialisation) |
| `cix-update` build takes very long | unfree CUDA packages compile locally. Wait; it is a one-time cost per version |
| Dead screen right after `test`/`switch` | you were booted into a specialisation and activated the base. Power-cycle, pick the same GRUB entry, then see [Booted into a specialisation](#booted-into-a-specialisation) |
| Something broke after `switch` | `sudo nixos-rebuild switch --rollback --no-reexec`, or pick an older entry in GRUB |

## Related

- [Flake](architecture/flake.md) · [Constraints](constraints.md) · [Boot & recovery](system/boot.md)
- Agent skill: `nixos-change`
