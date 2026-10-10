---
name: project-commit
description: >
  Commit (and, when asked, push) changes in ~/Repos/cix. Use when the user
  says "commit", "commit this", "commit and push", "save these changes" or
  "prepare a commit". Runs the scope check, diff review, docs gate, privacy
  gate for the public repo, validation, exact staging, the commit and an
  optional push. Not for rebuilds (nixos-change) or memory (session-wrapup).
---

# Project commit

**IRON LAW: the repo is public. Nothing is committed until the diff is
reviewed, the docs are in sync, the privacy gate is clean and validation
passes. Stage exact paths only. Push only when asked.**

Flow: scope → review → docs gate → privacy gate → validate → commit → push (if asked) → handoff.

## Step 0: scope

```sh
cd ~/Repos/cix
git status --short
git diff HEAD --stat
git ls-files --others --exclude-standard
git log --oneline -5
```

- The user's "commit" covers the changes made for the current task. Stop
  and ask only when the tree also holds unrelated or unexplained changes.
- One logical change per commit. If the tree holds several, commit them
  separately, each with its own docs.
- App-written live dotfiles (KWin's `kwinoutputconfig.json`, Plasma or app
  state under `dotfiles/`) change on their own. Commit that churn separately
  as `chore(<app>): …` unless it belongs to the change.
- Preserve existing staging and dirty files. Never reset, checkout or clean.

## Step 1: review the diff

Read the whole diff (`git diff HEAD -- <paths>`) and every new file in full:

- [ ] Placement follows `AGENTS.md` (config boundaries, package table); no
      duplicate declaration (`rg <pname>`).
- [ ] New modules are imported (HM: `home/<user>/default.nix`; NixOS:
      `flake.nix` or the host's `default.nix`).
- [ ] Local packages are reached as `cixPkgs.<name>`; overrides stay local, no overlays.
- [ ] Live dotfiles use the `dotfile "<app>"` helper, never a Nix path.
- [ ] No stale paths after a rename or move (`rg old/path`).
- [ ] Host-specific values (PCI IDs, disk IDs, EDID, IPs) stay in `hosts/<host>/`, not in shared `modules/`.
- [ ] Comments follow `AGENTS.md` → *Config style*.

Fix problems inside the task's scope; report anything else.

## Step 2: docs gate

Reverse-lookup every changed source in `wiki/_sources.yaml`:

```sh
nix shell nixpkgs#yq-go -c yq 'to_entries[] | select(.value.sources[] == "<path>") | .key' wiki/_sources.yaml
```

| Change | Update in the same commit |
| --- | --- |
| User-visible behaviour (shortcut, default, app, service) | the bound wiki page(s) |
| Added, removed or moved module or folder | `_sources.yaml`, `wiki/README.md`, README tree; `AGENTS.md` if a boundary moved |
| Package in `pkgs/` | its `README.md`, `wiki/dev/nix-packaging.md`, `_sources.yaml` |
| Hardware, boot, disk, GPU | `wiki/architecture/<host>.md`, `wiki/system/boot.md` |
| Host added or removed | see the `add-host` skill |
| Secret added | `wiki/security/secrets.md` |
| Value tweak, package added to a list, comment, typo | usually nothing |

Write docs with `wiki-maintainer`. If none are needed, say so and why.

## Step 3: privacy gate

Run on what will be committed:

```sh
{ git diff HEAD -- <changed paths>; cat -- <new files>; } | grep -nEi \
  'AGE-SECRET-KEY|PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|xox[bp]-|password *[:=] *[^ ]|@(gmail|outlook|hotmail|proton|icloud)\.'
git config user.email            # must be the GitHub noreply address
```

- Review every hit. A real secret or personal detail is a stop: show it and
  ask. Plaintext secrets never enter Git, not even briefly.
- Personal data stays out: other people's names, school or work accounts,
  hostnames and usernames on other machines (those go in untracked files,
  e.g. `~/.ssh/config.local`).
- Hardware identifiers in code are allowed; docs name the file instead.
- Files to check by hand: anything an app wrote (it may embed account names or paths).

## Step 4: validate

```sh
git diff --check
nix flake check                  # formatting, docs-sources, IPv4-in-docs
```

Build when `.nix` structure changed (new/moved files, imports, inputs,
`pkgs/`, shared modules). Build every host a shared change can reach:

```sh
for host in $(nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link --print-out-paths
done
```

New files must be staged (or use `path:.`) or the Git flake won't see them.
A failure stops the commit. Validation is not activation.

## Step 5: commit

```sh
git add -- <exact paths>         # deletions: git rm, or git add on the deleted path
git diff --cached --stat         # must match the reviewed scope
git commit -F - <<'EOF'
<type>(<scope>): <description>

<optional body: why, not what>
EOF
```

- Types: `feat`, `fix`, `refactor`, `chore`, `docs`.
- Scope: the module or area (`plasma`, `kwin`, `brave`, `<host>`, `flake`, `pkgs`, `wiki`, `skills`, `repo`).
- Subject: imperative, lower case, no trailing period, under ~70 characters.

## Step 6: push (only when asked)

```sh
git log @{u}..HEAD --format='%h %ae %s'    # every author email must be the noreply address
git push
```

Never force-push `main`. If the push is rejected, fetch and report; don't rebase without a request.

## Handoff

```markdown
**Committed:** <hash> <subject>   (**Pushed:** yes/no)
**Docs:** <pages> / none needed: <why>
**Validation:** diff --check, flake check, build <hosts> — pass/fail/skipped (<why>)
**Left out:** <paths> / none
**To apply:** nixos-change (Nix changed) / app reload (dotfiles only) / nothing
```

## Forbidden

- `git add -A`, `git add .`, or reset/clean/checkout over the user's work.
- Committing with a privacy hit, a failed check or missing docs.
- Amend, rebase, force-push or PRs without an explicit request.
- Calling a commit "applied" or "deployed".
