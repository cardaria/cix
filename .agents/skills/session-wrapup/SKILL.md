---
name: session-wrapup
description: >
  End-of-session review for ~/Repos/cix. Use when the user says "wrap up",
  "we're done", "summarize the session", "anything worth remembering?" or
  "update memory". Reviews what changed and what was decided, proposes
  memory cards and wiki fixes, lists open checks and uncommitted work. Never
  commits, pushes, rebuilds or cleans up.
---

# Session wrap-up

**IRON LAW: persist only knowledge that would change a future decision. A
summary request is not permission to write.**

## Step 1: gather

```sh
cd ~/Repos/cix
git status --short
git log --oneline -10
```

Re-read the conversation for: decisions and their reasons, things that were
tried and failed, the user's corrections and preferences, verification
results, and questions still open.

## Step 2: sort

For each candidate ask: *if a future agent couldn't see this, would it make
a different or less safe decision?*

| Kind | Goes to |
| --- | --- |
| Non-obvious trade-off, hidden pitfall, hardware fact, user policy, reusable correction | memory card |
| How to use or fix something | the bound wiki page (usually its Troubleshooting table) |
| Readable from code or a commit message | nowhere |
| Not yet verified (e.g. "suspend untested after the driver bump") | the report's open checks |

No backlog file: open checks live in the report and in the user's hands.

## Step 3: propose, then write

- Asked for a summary: propose cards (slug, type, one line, why) and wiki
  edits, then stop.
- Asked to update memory or docs: write them with `wiki-maintainer`
  (*Memory cards*, *Updating a page*). Changing or deleting existing cards
  or pages still needs confirmation.
- Nothing new: say *"No new decisions; memory doesn't need updating."*

## Step 4: report

```markdown
## Session wrap-up
**Done:** <what changed, by commit or file>
**Memory:** <cards added/updated> / proposed: <slugs> / nothing new
**Wiki:** <pages synced> / up to date
**Open checks:** <items, each with the step that proves it> / none
**Uncommitted:** <paths>; commit with `project-commit` / clean
**Next step:** <one concrete action>
```

Run `git diff --check` and `nix flake check` if anything was written.

## Forbidden

- Cards for routine changes, tests or obvious config; a *why* invented after the fact.
- Committing, pushing, rebuilding or cleaning as part of the wrap-up.
- Interrupting the user's work to wrap up unasked.
