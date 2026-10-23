{ kdePackages }:
kdePackages.krohnkite.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    # Sole-window percentages bypass screen gaps upstream
    ./sole-window-gaps.patch
    # Windows tiled at login before the panel exists stay under it
    ./retile-on-panel.patch
  ];
})
