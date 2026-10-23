{ pkgs, ... }:
let
  # Vesktop's own "Start with system" writes the unwrapped Electron path, which crashes
  autostart = pkgs.makeDesktopItem {
    name = "vesktop";
    desktopName = "Vesktop";
    exec = "vesktop --start-minimized";
    icon = "vesktop";
  };
in
{
  home.packages = [ pkgs.vesktop ];

  xdg.autostart = {
    enable = true;
    entries = [ "${autostart}/share/applications/vesktop.desktop" ];
  };
}
