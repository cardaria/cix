---
name: wiki-maintainer
description: >
  Create, update, sync or audit the cix knowledge base in ~/Repos/cix:
  wiki/, memory/, README.md and AGENTS.md. Use when the user says
  "write/update/review/sync the wiki", "docs are out of date", "document
  <component>", "add a decision card", or after Nix changes that need docs.
  Covers source lookup via wiki/_sources.yaml, incremental updates, decision
  cards, README/AGENTS upkeep and audits. A one-off typo fix doesn't need it.
---

# Wiki maintainer

**IRON LAW: read the sources before writing. Keep the user's wording, never
invent a *why*, and never add a second structure: `wiki/_sources.yaml`,
`memory/INDEX.md` and the category folders are the only ones.**

## Layers

| Layer | Answers | Location | Public |
| --- | --- | --- | --- |
| Code | *what* is configured | `flake.nix`, `hosts/`, `modules/`, `home/`, `pkgs/`, `dotfiles/` | yes |
| Wiki | *how to use and fix it* | `wiki/` (map `wiki/README.md`, sources `wiki/_sources.yaml`) | yes |
| Memory | *why it is this way* | `memory/INDEX.md`, `memory/cards/<slug>.md` | **no**, local and gitignored |
| Entry points | overview, agent contract | `README.md`, `AGENTS.md` | yes |

Everything public is read by strangers: no personal details, and private
identifiers (IPs, serials, disk IDs, MACs) only in code.

## Modes (one per task)

| Mode | When | Produces |
| --- | --- | --- |
| `create` | a component has no page | page + `_sources.yaml` entry + `wiki/README.md` link |
| `update` / `sync` | behaviour changed, or docs look stale | minimal edits to the bound pages, `updated` refreshed |
| `record_decision` | a non-obvious why, hardware fact or constraint | memory card + `INDEX.md` line |
| `audit` | the user asks for a consistency check | `pass`/`warn`/`fail` list; **no edits** until confirmed |

## Before writing

- [ ] `git status --short`: keep staged, unstaged and user-written content intact.
- [ ] Read the target page **and all its sources in full**, not a diff hunk.
- [ ] Read one sibling page in the same folder as the style reference.
- [ ] If code, page and the user disagree, stop and ask. Code at the locked
      revision wins on facts; the user wins on wording and intent.

## Page conventions

```yaml
---
title: <Title>
category: <folder name, or overview at the top level>
tags: [kebab-case, keywords]
updated: YYYY-MM-DD
---
```

`nix flake check` enforces the frontmatter, the category/folder match and
the source mapping.

- English, written for the user: how to use and fix it, not a translation of the Nix.
- Order: one-sentence summary → concepts or layout → how to use it (real keys
  and commands) → options table → workflows → `## Troubleshooting` → `## Related`.
- Over ~150 lines: a `## Contents` list after the summary. Over ~250: split the page.
- Tables for options and shortcuts; copy-pasteable `sh` blocks.
- Name files and options; never line numbers.
- At most one clause of *why* inline. Longer reasoning goes into a memory card,
  cited in `## Related` as plain text (`memory: <slug>`); a link would 404 publicly.
- Relative links between pages; repo-relative paths for source files.

## `wiki/_sources.yaml`

The only mapping: `page → { sources: [...], memory: [...] }`. The reverse
lookup is computed, never stored:

```sh
nix shell nixpkgs#yq-go -c yq 'to_entries[] | select(.value.sources[] == "<path>") | .key' wiki/_sources.yaml
```

Invariants (the check enforces 1, 2 and 4; check 3 by hand, memory is local):

1. Every `.nix` file under `hosts/`, `modules/`, `home/`, `pkgs/`, `secrets/`, plus `flake.nix`, is a source of some page.
2. Every listed source exists.
3. Every listed memory slug exists in `memory/cards/`.
4. Every page except `wiki/README.md` has an entry.

## Updating a page

1. Keep its skeleton and headings unless they're wrong.
2. The user's how-to text (workflows, troubleshooting) keeps its wording.
3. Facts (values, paths, versions, names) come from the current source.
4. Remove what no longer exists; don't leave "formerly" notes. Git has the history.
5. Refresh `updated`.

A changed file mapped to no page: add it to the closest page's `sources`, or
create a page if the user interacts with the component directly. Background
services fold into an existing page.

## Entry points

| File | Update when |
| --- | --- |
| `README.md` | hosts or their hardware change (Hosts table), the stack changes (Current system table), top-level folders change (Layout) |
| `wiki/README.md` | a page is added, removed or renamed |
| `AGENTS.md` | a boundary, rule, skill, shared stack fact or host changes; imperative voice, no speculation. Host details go on the host page |

## Memory cards

Write one when the *why* can't be read from code or commits and someone
might later "simplify" it away. Not for manual-level facts or troubleshooting.

1. Copy `memory/_template.md` to `memory/cards/<slug>.md`.
2. Frontmatter: `id` (= slug), `type` (`decision` | `hardware` | `constraint`), `tags`, `date`.
3. Body: Problem → Decision → Why → How to apply → Related.
4. Add one line to the matching group in `memory/INDEX.md`, keeping it 1:1 with `cards/`.

Changing or deleting an existing card needs the user's confirmation.

## Audit

1. Sources ↔ pages (the check), memory slugs (by hand).
2. Tables, commands, defaults and paths match the code.
3. New features documented, removed ones gone.
4. README tables and tree, `AGENTS.md` Stack and Hosts tables accurate.
5. No personal details or private identifiers in public files.

Report findings; edit only after confirmation.

## Handoff

```text
Mode:       <mode>
Changed:    <pages / cards>
Kept as-is: <user content preserved>
Skipped:    <item — reason>
Validation: nix flake check — pass/fail; memory slugs — pass/warn
```

## Forbidden

- Writing from a diff hunk without reading the full source and page.
- A second mapping, plan, log or backlog.
- Stating an unproven *why* as fact; filler cards.
- Moving, deleting or bulk-rewriting the user's docs without confirmation, or generating pages by script.
- Calling doc checks "built", "switched" or "verified".
