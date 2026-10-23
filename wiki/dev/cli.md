---
title: cix CLI
category: dev
tags: [cli, cix, update, backup, llm, ocr]
updated: 2026-10-24
---

# cix CLI

One command, `cix`, for everything this repo adds to the shell. Every level
has `--help`:

```sh
cix --help
cix llm --help
```

## Commands

| Command | Does | Details |
| --- | --- | --- |
| `cix update draba` | update inputs, validate and build, prepare the next boot; without a target it lists the targets | [Deployment](../deployment.md#build-and-apply) |
| `cix update pve` | update, review and deploy every guest on pve, stage by stage; `cix update <guest>` for one | [Deployment](../deployment.md#update-the-guests-on-pve) |
| `cix backup` | back up and verify the host's recovery keys in 1Password | [Secrets](../security/secrets.md#back-up-the-key-1password) |
| `cix repos` | mirror every GitHub repository to the share and to GitLab | [Repository backups](#repository-backups) |
| `cix llm` | status, unload, logs, tps, fetch, ui of the local LLM | [Local LLM](local-llm.md) |
| `cix ocr` | convert PDFs and images, fetch and verify the model | [Local OCR](local-ocr.md) |

`cix help <command>` is the same as `cix <command> --help`.

## Updating safely

`cix update draba` asks before installing a build for the next boot. It does not
activate services in the running desktop. Reboot yourself when ready, then
check the applications and both `systemctl --failed` and
`systemctl --user --failed`. A build cannot verify login or GPU behavior.

- `--no-update` uses the existing lock file for a retry or a configuration edit.
- `--dry-run` still updates inputs and builds, but never invokes `sudo`.
- `--cuda` additionally updates the deliberately separate CUDA pin.

`cix update pve` asks once, after one review of every guest. It deploys only if every
check passes first, and stops at the first guest that doesn't pass them afterwards; logs
and the review stay in `~/.local/state/cix/updates`.

The command rejects concurrent runs and untracked files, and asks before
including working-tree edits. Checks and the build use the same immutable
source snapshot. Recovery-key verification must succeed; run `cix backup`
separately when a key needs uploading.

Before installation, the candidate's `nvidia-smi --help` must start successfully
when present. This catches executable/loader failures without requiring the
new driver to be loaded; it does not replace a reboot test.

Each attempt retains logs in `${XDG_STATE_HOME:-~/.local/state}/cix/updates/run.*`.
A `result` symlink protects the candidate from garbage collection until boot
installation succeeds, when the system generation protects it instead.
Dry runs, declined installations and failed attempts keep that extra root;
remove their obsolete run directories manually when they are no longer needed.

Boot installation errors can leave the system profile changed before the boot
menu is complete. The command reports failure and prints exact retry and
previous-build recovery commands. Retrying still writes the boot menu even
when the profile already names the candidate.

`modules/home/cix/test-update.py` exercises the workflow with fake Nix and sudo
commands in temporary directories; `nix flake check` runs it automatically.

## Repository backups

`cix repos backup` keeps a bare mirror of every GitHub repository of the account (forks excluded; the list
comes from GitHub, so repositories that are not cloned here are included) in `~/Shares/Cloud/Backups/git`,
then pushes branches and tags to GitLab, where a missing project is created as a **private** one. The nightly
run is the job of the server, which is always on (the private pve repo describes it); this command is the
manual version (for example right after pushing). `cix repos status` shows the last run and
the age of each mirror.

- **Two copies, two reasons.** GitLab protects against losing the GitHub account; the mirrors on the share are
  copied by the share's rsync jobs to two more disks with seven days of history.
- **History is never lost.** The mirrors keep every ref update (`core.logAllRefUpdates`) and never delete an
  object (`gc.auto = 0`), so a bad force-push on GitHub can be undone from the mirror. Only GitLab's branches
  are pruned to match.
- **Only pushed work is backed up.** Commits that exist only on this machine are not on GitHub, so push first.
- It refuses to run when the share is not mounted, so it never fills the local disk. It needs `gh` logged in
  and an SSH key known to GitLab. A failing repository shows on the screen and the command exits 1. A lock stops a manual run from overlapping the nightly one,
  and with `HEALTHCHECKS_URL` set a full run reports to healthchecks.io.

## Adding a command

`modules/home/cix/default.nix` owns the dispatcher and the `cix.commands`
option. The module that owns a feature registers its program there, and
the name, the `--help` line and the dispatch all follow from it:

```nix
cix.commands.<name> = {
  description = "One line for cix --help";
  package = <program>;
};
```

The program is not installed on its own: only `cix` is on `PATH`.
It starts with `Usage: cix <name> …` in its own `--help`.

Shell commands prepend `modules/home/cix/ui.sh` to their text, so every
command looks the same: `step` prints a bold section header, `row` an aligned
label and value, and `confirm` asks `[y/N]`, answered with Enter (Enter alone
is no).

## Not part of the CLI

`cix-llm-worker` and `cix-ocr-worker` are fixed entrypoints for the GPU
group and never run by hand ([GPU access](../architecture/gpu-access.md)).
`cix-desktop-gpu` is a boot-time helper for KWin and Plex.
