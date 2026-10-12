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

  # Colloid's mic fills the whole 22px box while the speaker is smaller; shrink it to match
  micStatus = "${pkgs.colloid-icon-theme}/share/icons/Colloid-Light/status/22";
  mics = {
    microphone-sensitivity-high = "mic-on";
    microphone-sensitivity-medium = "microphone-sensitivity-medium";
    microphone-sensitivity-low = "microphone-sensitivity-low";
    microphone-sensitivity-muted = "mic-off";
  };

  link = source: name: "ln -s ${source} $theme/apps/scalable/${name}.svg";

  # Light variant to match the Breeze Light scheme; falls back to Breeze, then hicolor
  colloidCix = pkgs.runCommand "colloid-cix-icon-theme" { } ''
    theme=$out/share/icons/Colloid-cix
    mkdir -p $theme/apps/scalable $theme/status/22
    cat > $theme/index.theme <<THEME
    [Icon Theme]
    Name=Colloid-cix
    Comment=Colloid Light plus aliases for apps it has no icon for
    Inherits=Colloid-Light
    Directories=apps/scalable,status/22

    [apps/scalable]
    Size=128
    MinSize=16
    MaxSize=512
    Type=Scalable
    Context=Applications

    [status/22]
    Size=22
    Context=Status
    Type=Fixed
    THEME
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: target: link "${colloid}/${target}.svg" name) aliases
      ++ lib.mapAttrsToList (name: file: link "${breeze}/${file}" name) launcher
    )}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: file:
        "sed 's/width=\"22\" height=\"22\"/& viewBox=\"-2.5 -2.5 27 27\"/' ${micStatus}/${file}.svg > $theme/status/22/${name}.svg"
      ) mics
    )}
  '';
in
{
  home.packages = [
    pkgs.colloid-icon-theme
    colloidCix
  ];
}
