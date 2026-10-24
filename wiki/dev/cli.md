---
title: cix CLI
category: dev
tags: [cli, cix, update, rollback, backup, llm, ocr]
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
| `cix update pve` | update every guest stage by stage; name one or more guests to select a subset | [Deployment](../deployment.md#update-the-guests-on-pve) |
| `cix rollback <target>` | review retained generations, prepare this machine's next boot or activate selected guests; `--list` inspects without changes | [Rolling back](#rolling-back) |
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
- `--verbose` streams every command's full output; by default each step shows a spinner, then one
  line, and keeps its output in the run's log (shown when a step fails).
- At a question, `c` opens every change in a full-screen pager (arrows or Page Up/Down to scroll, `q` to go back), then asks again.
- The commands work on `<reposDir>/cix` and `<reposDir>/pve`; `reposDir` is the Home Manager option
  `cix.reposDir` (default `~/Repos`), so a checkout elsewhere is one line.

`cix update pve` asks once, after one review of every guest. It requires healthy target units
and lists failing baseline checks for explicit acceptance. It stops at the first guest that
introduces a failing check or fails its unit checks afterwards; logs
and the review stay in `~/.local/state/cix/updates`.

`cix update <guest-a> <guest-b> --no-update` uses the same planner for just those guests,
in registry stage order. The order of names on the command line does not override their stages.
`cix rollback` reuses that review and sequential activation flow with retained generations instead
of new builds. It shares the update lock; its logs and temporary GC roots use the same state folder.
`modules/home/cix/generations.sh` reads system profile links and selects or displays generations.

The command rejects concurrent runs and untracked files, and asks before
including working-tree edits. Checks and the build use the same immutable
source snapshot. Recovery-key verification must succeed; run `cix backup`
separately when a key needs uploading.

Guest activation first runs `dry-activate` and prints its unit preview. The running closure,
system profile and registry plan must still match the review before deployment. An interruption
stops the local step's process group; an already-started remote activation may continue, so
inspect the guest and follow the recorded recovery command before retrying.

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

`modules/home/cix/test-update.py` and `test-update-pve.py` exercise updates and rollbacks with
fake Nix, sudo and SSH commands in temporary directories; `nix flake check` runs them automatically.

## Rolling back

```sh
cix rollback draba --list
cix rollback draba                  # prepare an older build for the next boot
cix rollback <guest> --list
cix rollback <guest>                # activate an older build, then verify health
cix rollback <guest> --generation 12 # select one retained generation explicitly
cix rollback <guest-a> <guest-b> --dry-run
```

The default selects the highest retained generation below the current system profile with a
different closure. `--list` displays the retained generation numbers and exact paths without
copying or activating anything; `--generation` requires one named target. An older generation is
not necessarily healthy, particularly after an automatic recovery: review it or select explicitly.
Missing or collected generations stop the operation before any guest is changed.

On the workstation, rollback reviews the package changes and asks before preparing the next boot.
The running desktop is left alone, including its current GPU specialisation; reboot yourself and
select the same specialisation. A candidate missing that specialisation is refused.

For guests, it reuses the update planner, stage order, review, activation and health checks.
Retained closures are inspected and activated on their guests, where system generations already
protect them from garbage collection. No closure import or local trust change is needed.
`--dry-run` does not write to the guests. The registry must still
evaluate, but rollback never updates inputs, builds a configuration or edits the working tree.
Existing failed units can be repaired by rollback; failing checks require acknowledgement and
must recover afterwards. Each guest must pass before the next starts. The registry's automatic
rollback policy also applies to a failed manual rollback, returning that guest to its starting build.
Guests already changed earlier in the run remain changed; this is not an atomic group operation.

Rollback changes system generations, not application data, database migrations, Git files, image
pins or live dotfiles. Old container images may need downloading by their services during activation;
the current source's image pins are not pulled for a rollback. Logs retain the starting closures
and print an exact recovery command on failure. `cix rollback pve` selects all guests and still asks
after showing each destination; the Proxmox host itself is never rolled back.

## Repository backups

`cix repos backup` keeps a bare mirror of every GitHub repository of the account (forks excluded; the list
comes from GitHub with pagination, so repositories that are not cloned here are included) in `~/Shares/Cloud/Backups/git`,
then pushes branches and tags to GitLab, where a missing project is created as a **private** one. The nightly
run is the job of the server, which is always on (the private pve repo describes it); this command is the
manual version (for example right after pushing). `cix repos status` shows the last run and
the age of each mirror.

- **Two copies, two reasons.** GitLab protects against losing the GitHub account; the mirrors on the share are
  copied by the share's rsync jobs to two more disks with seven days of history.
- **Retain upstream history.** The mirrors record ref updates (`core.logAllRefUpdates`) and disable
  automatic garbage collection (`gc.auto = 0`), so a bad force-push can be recovered from retained mirror history. GitLab's branches and tags
  follow the retained local refs, including refs deleted upstream. Manual garbage collection
  can still remove expired unreachable history; the backup command never runs it.
- **Only pushed work is backed up.** Commits that exist only on this machine are not on GitHub, so push first.
- It refuses to run when the share is not mounted, so it never fills the local disk. It needs `gh` logged in
  and an SSH key known to GitLab. A failing repository shows on the screen and the command exits 1; unknown requested names are refused before any mirror changes. A lock stops a manual run from overlapping the nightly one,
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
