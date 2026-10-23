---
name: nix-packaging
description: >
  Add, update, patch, review or retire a package in ~/Repos/cix: a
  hand-written package in pkgs/, or an override (override, overrideAttrs,
  symlinkJoin) in a module. Use when the user says "package X", "update
  <package>", "bump the override", "patch this app", "why won't this build",
  or something isn't in nixpkgs. Covers searching nixpkgs first, choosing the
  shape, provenance, isolated builds, patches and retirement.
---

# Nix packaging

**IRON LAW: search nixpkgs (the locked revision and unstable) before writing
anything. Every package in `pkgs/` has a provenance README with a removal
condition and builds on its own as `nix build .#<name>`. One definition per
package; no overlays.**

## Step 0: search

```sh
nix eval --raw .#nixosConfigurations.<host>.pkgs.<name>.version   # locked nixpkgs
nix search nixpkgs#<name>                                         # current unstable
gh pr list -R NixOS/nixpkgs --search "<name> in:title" --state open
rg -n '<name>' .                                                  # already here?
```

## Step 1: choose the shape

| Situation | Shape | Where |
| --- | --- | --- |
| In nixpkgs, fine as-is | add to a package list | `AGENTS.md` placement table |
| Needs flags or features | `pkg.override { … }` | the app's module |
| Needs a newer version | `overrideAttrs`, guarded by `lib.versionOlder` so it expires itself | the app's module |
| Needs a small fix | `overrideAttrs` adding a patch | `pkgs/<name>/` when the patch is a file |
| Only the launcher, icon or wrapper differs | `symlinkJoin` + `postBuild` | the app's module |
| Not in nixpkgs, or only in an open PR | full package | `pkgs/<name>/` |

Find working examples in the repo instead of copying from memory:
`rg -l 'versionOlder|overrideAttrs|symlinkJoin' modules pkgs`.

## Step 2: `pkgs/<name>/`

```text
pkgs/<name>/
  default.nix    callPackage style; finalAttrs, meta (description, homepage, license, platforms)
  *.patch        one concern each, named by purpose
  README.md      provenance
```

Register it in `pkgs/default.nix` (alphabetical). That one line makes it:

- a flake output: `nix build .#<name>`;
- available to every NixOS and Home Manager module as `cixPkgs.<name>`
  (`modules/nixos/packages.nix`). Never import `pkgs/` by relative path.

Extra inputs (a flake input as source, say) are passed in `pkgs/default.nix`
and come from `specialArgs` in `flake.nix`.

README fields, in this order:

- **Source:** upstream URL and version or commit, or the nixpkgs PR and commit.
- **Local changes:** each patch or injected change, and whether it went upstream. "None" is fine.
- **Updating:** how to bump it and what to run to verify it.
- **Removal condition:** when it can go, e.g. "once the locked nixpkgs has `<name>` ≥ X".

## Step 3: build and verify

```sh
nix build .#<name> -L --no-link --print-out-paths
nix flake check
```

Then build the host(s) using it and run the verification from the README.

Tools (`nix develop` has nurl, nix-update and yq; others via `nix shell nixpkgs#<tool>`):

| Tool | Use |
| --- | --- |
| `nix-init` | first draft from a URL |
| `nurl <repo-url> <rev>` | fetcher call with the right hash |
| `nix-update --flake <name> --version <v>` | bump version and hashes |
| `nix hash convert`, `nix-prefetch-url` | one-off hashes |

## Patches

- Make them against the upstream tag or commit: `git diff > pkgs/<name>/<purpose>.patch`.
- One line in `default.nix` above each `patches` entry says why.
- After a bump every patch must apply; rebase it, or drop it when upstream
  fixed the problem, and update the README.
- Fixes for Nix-specific paths or sandboxing are worth sending upstream; note
  in the README whether they were.

## Updating

1. Read the package's README → **Updating**.
2. Bump (`nix-update`, or `nurl` for a pinned commit), build, verify.
3. Update **Source** and anything else the bump changed.

## Retiring

When the removal condition holds: switch the caller to the nixpkgs attribute,
delete `pkgs/<name>/`, remove its line in `pkgs/default.nix`, and update
`_sources.yaml`, `wiki/dev/nix-packaging.md` and the component page.

## Report

```markdown
**Package:** <name>   **Shape:** <shape>   **Version:** old → new
**Source:** <url / PR + rev>
**Build:** nix build .#<name> pass/fail; hosts built: <list>
**Verified:** <README check> / not run (<why>)
**Patches:** applied / rebased / dropped (<which>)
**Docs:** pkgs/<name>/README.md, wiki/dev/nix-packaging.md, _sources.yaml
```

## Forbidden

- Overlays for a single package; a second definition of the same package.
- `lib.fakeHash` left in committed code.
- `doCheck = false` without a one-line reason.
- A package in `pkgs/` without a README or removal condition.
