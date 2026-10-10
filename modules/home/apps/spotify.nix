{
  dotfile,
  pkgs,
  ...
}:
let
  inherit (pkgs) spotify spicetify-cli;
  marketplace = pkgs.fetchzip {
    url = "https://github.com/spicetify/marketplace/releases/download/v1.0.11/marketplace.zip";
    hash = "sha256-6bSL/Vo/GPAVDAO6G2fxYdiMVitG3Xxka0oD+HL0wBE=";
  };
  # Placeholder theme; Marketplace themes recolour Spotify at runtime
  marketplaceTheme = pkgs.linkFarm "spicetify-marketplace-theme" {
    "color.ini" = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/spicetify/marketplace/b72266c4b939deb40625ce254855c48fecd432f3/resources/color.ini";
      hash = "sha256-gCyD9Pgi6yVPYO806oxT6p2XiJueiGrFMuQpU7lUj7I=";
    };
  };
  adblock = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/rxri/spicetify-extensions/5da6cf1bb723f9efd0177f5fa4f4673b9e0c0936/adblock/adblock.js";
    hash = "sha256-Mp+LGLcAJ8RWOZ7kxoCb+SRHNfJkCIiEXklx6YPoifg=";
  };
  # Spotify's own wrapper (library paths, Wayland), aimed at the writable copy
  wrapper = pkgs.runCommand "spotify-writable-wrapper" { } ''
    install -d $out/bin
    substitute ${spotify}/bin/spotify $out/bin/spotify \
      --replace-fail ${spotify}/share/spotify '$HOME/.local/share/spotify-spicetify'
    chmod +x $out/bin/spotify
  '';
  # Spicetify needs a writable copy, refreshed when its store inputs change
  launcher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = [
      pkgs.coreutils
      spicetify-cli
    ];
    text = ''
      store=${spotify}/share/spotify
      stamp="$store ${spicetify-cli} ${marketplace} ${marketplaceTheme} ${adblock}"
      app="''${XDG_DATA_HOME:-$HOME/.local/share}/spotify-spicetify"
      # Home Manager can't link into the out-of-store spicetify directory; both are gitignored
      config="''${XDG_CONFIG_HOME:-$HOME/.config}/spicetify"
      mkdir -p "$config/CustomApps" "$config/Themes" "$config/Extensions"
      ln -sfn ${marketplace} "$config/CustomApps/marketplace"
      ln -sfn ${marketplaceTheme} "$config/Themes/marketplace"
      ln -sfn ${adblock} "$config/Extensions/adblock.js"
      if [ "$(cat "$app/.store" 2>/dev/null)" != "$stamp" ]; then
        rm -rf "$app"
        cp -r "$store" "$app"
        chmod -R u+w "$app"
        # Spicetify restarts Spotify through this path; the copied script runs the unpatched store binary
        ln -sf ${wrapper}/bin/spotify "$app/spotify"
        # A stale backup gets re-patched on top of itself, which breaks the JS
        spicetify -q clear || true
        spicetify -q backup apply --no-restart
        echo "$stamp" > "$app/.store"
      fi

      exec ${wrapper}/bin/spotify "$@"
    '';
  };
in
{
  home.packages = [
    spicetify-cli
    (pkgs.symlinkJoin {
      inherit (spotify) name meta;
      paths = [ spotify ];
      postBuild = ''
        rm $out/bin/spotify
        cp ${launcher}/bin/spotify $out/bin/spotify
      '';
    })
  ];

  # Directory link survives Spicetify's rewrites
  xdg.configFile."spicetify".source = dotfile "spicetify";
}
