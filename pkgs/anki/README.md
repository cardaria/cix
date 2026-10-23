# Anki version bump provenance

**Source:** [ankitects/anki](https://github.com/ankitects/anki) 26.09.3
(rev `29bb700b`). The source, Cargo and Yarn hashes and `missing-hashes.json`
come from the open nixpkgs PR
[#573799](https://github.com/NixOS/nixpkgs/pull/573799), commit `884de875`.
`default.nix` overrides nixpkgs' `anki` (26.08); its recipe, patches and
Python dependencies are used unchanged.

**Local changes:** none beyond the version bump. The build hash in Anki's
About dialog is a let-binding in nixpkgs, so the override rewrites it in
`buildPhase`.

**Updating:** for a newer release, take the hashes and `missing-hashes.json`
from the matching nixpkgs PR, or set each hash to empty and copy the one the
build reports. `missing-hashes.json` is regenerated with
`yarn-berry-fetcher missing-hashes yarn.lock` from the tagged source. Then:

```sh
nix build .#anki -L --no-link
```

and start Anki: Help → About shows the new version and build hash.

**Removal condition:** once the locked nixpkgs has `anki` ≥ 26.09.3 the
override turns itself off (`lib.versionOlder`). Then switch
`modules/home/apps/default.nix` to `pkgs.anki`, delete `pkgs/anki/` and its
line in `pkgs/default.nix`.
