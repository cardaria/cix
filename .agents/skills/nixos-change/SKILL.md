---
name: nixos-change
description: >
  Build, preview, test, switch or roll back a host configuration in
  ~/Repos/cix, and update flake inputs. Use when the user says "rebuild",
  "apply this", "switch", "test the config", "dry-activate", "update the
  flake", "update nixpkgs", "roll back" or asks whether a change is live.
  Enforces the evidence ladder and leaves privileged and reboot steps to the
  user unless explicitly authorized.
---

# NixOS change

**IRON LAW: every claim names its evidence level. A build is not an
activation, `test` is not persistent, `switch` is not a reboot, and none of
them prove the feature works. Privileged steps run only with explicit
authorization for that exact step.**

## Evidence ladder

| Level | Proves | How |
| --- | --- | --- |
| L1 eval | modules type-check, checks pass | `nix flake check` |
| L2 build | the closure builds | `nix build …toplevel` |
| L3 preview | which units activation would touch | `nixos-rebuild dry-activate --store-path` |
| L4 test | running now; a reboot returns to the old generation | `nixos-rebuild test --store-path` |
| L5 switch | persistent; the boot default | `nixos-rebuild switch --store-path` |
| L6 runtime | the feature works | user checks, `systemctl --failed` empty |
| L7 boot | kernel, driver, initrd, bootloader, login and GPU changes work | user reboots |

## Step 0: scope

```sh
cd ~/Repos/cix
git status --short
hostname                                                      # the host being changed, unless the user names another
nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'
```

- New files must be staged (or use `path:.`); never stage unrelated work.
- Live-dotfile-only changes need no rebuild, only the app's reload
  (`wiki/deployment.md` → *Live dotfiles*).
- plasma-manager and other HM settings need a rebuild; Plasma picks most up at the next login.

## Step 1: L1–L2 (agent)

```sh
nix fmt
nix flake check
candidate=$(nix build ".#nixosConfigurations.<host>.config.system.build.toplevel" \
  --no-link --print-out-paths --no-write-lock-file)
echo "$candidate"
nix store diff-closures /run/current-system "$candidate"
```

Summarize the closure diff: version bumps, added or removed packages, size.
Flag anything unexpected (kernel or driver bump, mass rebuild, a package
that should not have changed) before going further. Shell variables don't
survive between tool calls: hand the user the literal store path.

## Step 2: L3–L5 (user, or agent with exact authorization)

```sh
run0 /run/current-system/sw/bin/nixos-rebuild dry-activate --store-path <out> --no-reexec
run0 /run/current-system/sw/bin/nixos-rebuild test         --store-path <out> --no-reexec
# check the affected apps, then: systemctl --failed; systemctl --user --failed
run0 /run/current-system/sw/bin/nixos-rebuild switch       --store-path <out> --no-reexec
```

- `run0` prompts through polkit on the desktop; use `sudo` on a TTY.
- Changes to the login manager restart it and end the session: apply from
  TTY2 after saving work.
- Undo a bad `test`: `test --store-path "$(readlink -f /nix/var/nix/profiles/system)"`.
- Another host: build here, then `nixos-rebuild switch --flake .#<host>
  --target-host <ssh-target> --sudo` (or `--build-host` to build there).

## Step 3: L6–L7

Ask the user to confirm the concrete behaviour. For L7 changes the user
reboots, then checks the host page's post-reboot list
(`wiki/architecture/<host>.md`) plus `systemctl --failed`. Report open checks
in the handoff; the repo keeps no backlog.

## Updating inputs

Updates are deliberate, never unattended.

```sh
git status --short                                    # start clean
nix flake update <input> [<input>…]                   # or no names for all
git diff -- flake.lock
```

Then Steps 1–3. Before switching:

- Read upstream news for what the closure diff bumped: the NixOS release
  notes for unstable, Home Manager and plasma-manager changelogs, kernel
  and driver versions.
- Re-check everything this repo pins or patches:
  `rg -l 'versionOlder|overrideAttrs|override \{|patches' modules pkgs hosts`.
  Self-expiring overrides should now be dead code; patches must still apply.
- Follow the post-update checklist in `wiki/deployment.md` → *Update packages*.
- Never bump `system.stateVersion` or `home.stateVersion`.

Commit `flake.lock` alone: `chore(flake): update <inputs>`.

## Rollback

- Working system: `run0 …/nixos-rebuild switch --rollback --no-reexec`.
- Doesn't boot: pick an older generation in GRUB.
- Then revert the source change in Git separately. A rollback doesn't revert
  live dotfiles or user data.
- Old generations are collected by the `nh-clean` timer, which keeps a
  minimum (`programs.nh.clean` in the host config). Manual cleanup only on request.

## Report

```markdown
**Host:** <host>   **Candidate:** /nix/store/…
**L1 check:** pass/fail   **L2 build:** pass/fail
**Closure diff:** <notable changes>
**L3–L5:** not run (user) / dry-activate ok / test active / switched
**L6–L7:** unverified / user confirmed <what>
**Next step:** …
```

## Forbidden

- Running `test`, `switch`, `boot`, a reboot or remote deploys without authorization for that step.
- Calling something "applied" after a build, or "persistent" after `test`.
- Deleting generations or running GC outside the timer without a request.
- Unattended input updates; bumping `stateVersion`.
