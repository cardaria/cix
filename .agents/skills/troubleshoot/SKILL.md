---
name: troubleshoot
description: >
  Diagnose and fix something broken on a cix host. Use when the user says
  "X doesn't work", "X broke after the update", "why is X slow", "this
  crashes", "fix this error" or pastes an error from an app, service, build
  or boot. Covers triage, evidence from logs and generation diffs, one
  change at a time, the fix through nixos-change, and recording the symptom
  in the wiki.
---

# Troubleshoot

**IRON LAW: evidence before changes. Find what changed and what the logs
say, change one thing at a time, and call it fixed only when the user
confirms it at runtime.**

## Step 0: stabilize

- System unusable: switch to TTY2 (`Ctrl+Alt+F2`), or roll back first
  (`nixos-change` → *Rollback*) and debug from a working generation.
- Pin down the symptom: exact error text, when it started, and whether it
  follows a switch, an input update, a reboot or nothing obvious.

## Step 1: check what's known

1. `wiki/troubleshooting.md` routes symptoms to pages; `wiki/_sources.yaml`
   maps the component's files to its page.
2. Read that page's `## Troubleshooting` table, and the memory cards it cites
   (`memory/cards/<slug>.md`, local).
3. Known fix: apply it and go to Step 4.

## Step 2: gather evidence

```sh
systemctl --failed; systemctl --user --failed
journalctl -b -p warning -u <unit>          # --user for user units; -b -1 for the previous boot
```

What changed:

```sh
ls -lt /nix/var/nix/profiles/ | head -4                                   # recent generations
nix store diff-closures /nix/var/nix/profiles/system-<N-1>-link /nix/var/nix/profiles/system-<N>-link
git log --oneline --since="<when it last worked>"
git diff -- dotfiles/                                                     # live dotfiles change without a rebuild
```

What is actually configured:

```sh
nix eval .#nixosConfigurations.<host>.config.<option>
nix eval .#nixosConfigurations.<host>.config.home-manager.users.<user>.<option>
readlink -f ~/.config/<file>       # /nix/store: Home Manager owns it; ~/Repos/cix/dotfiles: live dotfile
```

Upstream, when a version bump is the suspect:
`gh issue list -R <owner>/<repo> --search "<error>" --state all`.

## Step 3: fix

- State the hypothesis and the evidence for it before changing anything.
- One change at a time; revert changes that didn't help before trying the next.
- Fix it at the source, in the repo: never edit `/etc`, store paths or
  HM-generated files by hand.
- Apply with `nixos-change` (Nix changes) or the app's reload (dotfiles).
- Upstream bug: prefer the smallest local workaround with a removal
  condition (`nix-packaging`), and link the upstream issue.

## Step 4: confirm and record

- The user confirms the symptom is gone (L6), and reboots if it's a boot,
  kernel or driver fix (L7).
- Add the symptom and fix as a row in the page's `## Troubleshooting` table
  (`wiki-maintainer`). A new symptom category also gets a row in `wiki/troubleshooting.md`.
- Non-obvious root cause someone might "simplify" away later: propose a memory card.
- Commit through `project-commit` when the user asks.

## Report

```markdown
**Symptom:** <what the user saw>
**Cause:** <root cause + evidence> / unknown (<what was ruled out>)
**Fix:** <change, file> — applied at L<n>
**Confirmed:** user confirmed / pending: <check>
**Recorded:** <wiki row, card> / nothing new
```

## Forbidden

- Several speculative changes at once, or leaving failed attempts in place.
- Editing generated files, `/etc` or the store directly.
- Disabling a check, test or security feature to make an error go away without the user's agreement.
- Calling it fixed from a build alone.
