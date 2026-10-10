{ cixPkgs, pkgs, ... }:
let
  # Fluxer's own autostart entry runs the unwrapped binary, which can't start outside the FHS env
  autostart = pkgs.makeDesktopItem {
    name = "app.fluxer.FluxerDesktopCanary";
    desktopName = "Fluxer Canary";
    exec = "fluxer-canary --autostart";
    icon = "fluxer-canary";
  };
in
{
  home.packages = [ cixPkgs.fluxer-canary ];

  # Merged into Fluxer's own --enable-features; without them video decodes on the CPU
  xdg.configFile."fluxer-canary-flags.conf".text = ''
    --enable-features=AcceleratedVideoDecodeLinuxGL,VaapiOnNvidiaGPUs
  '';

  xdg.autostart = {
    enable = true;
    entries = [ "${autostart}/share/applications/app.fluxer.FluxerDesktopCanary.desktop" ];
  };
}
