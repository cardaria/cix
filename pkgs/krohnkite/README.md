# Krohnkite patch provenance

**Source:** nixpkgs `kdePackages.krohnkite` 0.9.9.2, from
[anametologin/Krohnkite](https://codeberg.org/anametologin/Krohnkite).
`default.nix` overrides the upstream package; no source or dependency pins
are duplicated.

**Local changes:** `sole-window-gaps.patch` applies the configured screen
gaps after sizing the lone tiled window by percentage. At 60% width and
100% height, the window remains centered and keeps the usual top and bottom
padding. Multiple tiles, Monocle maximize and sole-window "No Gaps" retain
their upstream behavior.

`retile-on-dock.patch` re-tiles shortly after a dock (the panel) appears, so a window
opened at login before the panel exists moves out from under it.

**Build:** `nix build .#krohnkite --no-link`.

**Upstream:** not submitted.

**Updating:** follows nixpkgs. After a flake update the patch must still
apply; then check the layout cases above.

**Removal condition:** drop this override once upstream combines
sole-window percentages with the configured screen gaps.
