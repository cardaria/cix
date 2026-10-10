{ dotfile, pkgs, ... }:
{
  home.packages = with pkgs; [
    btop
    firefox
    gpu-screen-recorder
    haruna
    kdePackages.kcalc
    nvtopPackages.full
    signal-desktop
    wl-clipboard
  ];

  # KDE saves by rename, replacing the link; activation puts it back
  xdg.configFile."mimeapps.list" = {
    source = dotfile "mimeapps/mimeapps.list";
    force = true;
  };
}
