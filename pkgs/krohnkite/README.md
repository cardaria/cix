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

`retile-on-panel.patch` re-tiles when a panel window is added or resized.
KWin exposes no work-area signal to scripts, so windows tiled at login before
plasmashell maps the panel otherwise stay under it (upstream issue
[#163](https://github.com/anametologin/krohnkite/issues/163), closed unfixed).

**Build:** `nix build .#krohnkite --no-link`.

**Upstream:** not submitted.

**Updating:** follows nixpkgs. After a flake update the patches must still
apply; then check the layout cases above.

**Removal condition:** drop each patch once upstream combines sole-window
percentages with the screen gaps, or re-tiles when a panel reserves space.
