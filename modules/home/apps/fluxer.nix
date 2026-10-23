{ cixPkgs, pkgs, ... }:
let
  # Fluxer's own autostart entry runs the unwrapped binary, which can't start outside the FHS env
  autostart = pkgs.makeDesktopItem {
    name = "app.fluxer.FluxerDesktop";
    desktopName = "Fluxer";
    exec = "fluxer --autostart";
    icon = "fluxer";
  };
in
{
  home.packages = [ cixPkgs.fluxer ];

  # Merged into Fluxer's own --enable-features; without them video decodes on the CPU
  xdg.configFile."fluxer-flags.conf".text = ''
    --enable-features=AcceleratedVideoDecodeLinuxGL,VaapiOnNvidiaGPUs
  '';

  xdg.autostart = {
    enable = true;
    entries = [ "${autostart}/share/applications/app.fluxer.FluxerDesktop.desktop" ];
  };
}
