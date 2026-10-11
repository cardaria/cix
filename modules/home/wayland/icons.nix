{ lib, pkgs, ... }:
let
  colloid = "${pkgs.colloid-icon-theme}/share/icons/Colloid-Light/apps/scalable";
  breeze = "${pkgs.kdePackages.breeze-icons}/share/icons/breeze/places";

  # App icon names Colloid lacks, mapped to the closest Colloid icon
  aliases = {
    brave-origin = "brave-browser";
    fluxer-canary = "internet-chat";
    haruna = "org.kde.haruna";
    micro = "micro-logo-mark";
    "org.kde.merkuro.calendar" = "org.kde.kalendar";
    teamspeak6-client = "teamspeak";
    vesktop = "discord";
  };

  # Colloid draws the launcher as an Apple logo; keep Breeze's Plasma logo
  launcher = {
    start-here-kde = "64/start-here-kde.svg";
    start-here-kde-plasma = "64/start-here-kde-plasma.svg";
    start-here-kde-symbolic = "22/start-here-kde-symbolic.svg";
    start-here-kde-plasma-symbolic = "22/start-here-kde-plasma-symbolic.svg";
  };

  link = source: name: "ln -s ${source} $theme/apps/scalable/${name}.svg";

  # Light variant to match the Breeze Light scheme; falls back to Breeze, then hicolor
  colloidCix = pkgs.runCommand "colloid-cix-icon-theme" { } ''
    theme=$out/share/icons/Colloid-cix
    mkdir -p $theme/apps/scalable
    cat > $theme/index.theme <<THEME
    [Icon Theme]
    Name=Colloid-cix
    Comment=Colloid Light plus aliases for apps it has no icon for
    Inherits=Colloid-Light
    Directories=apps/scalable

    [apps/scalable]
    Size=128
    MinSize=16
    MaxSize=512
    Type=Scalable
    Context=Applications
    THEME
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: target: link "${colloid}/${target}.svg" name) aliases
      ++ lib.mapAttrsToList (name: file: link "${breeze}/${file}" name) launcher
    )}
  '';
in
{
  home.packages = [
    pkgs.colloid-icon-theme
    colloidCix
  ];
}
