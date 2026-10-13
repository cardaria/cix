{ kdePackages }:
kdePackages.krohnkite.overrideAttrs (old: {
  # Sole-window percentages bypass screen gaps upstream
  patches = (old.patches or [ ]) ++ [ ./sole-window-gaps.patch ];
})
