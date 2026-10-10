{ pkgs, ... }:
{
  services.desktopManager.plasma6.enable = true;
  programs.kde-pim = {
    enable = true;
    kmail = false;
    kontact = false;
    merkuro = true;
  };
  environment.plasma6.excludePackages = [ pkgs.kdePackages.discover ];
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # A logout-started portal would keep GTK backends and lose ScreenCast
  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    enableDefaultPath = false;
    unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP";
  };

  hardware.graphics.enable = true;
  fonts.enableDefaultPackages = true;

  # Trash, removable media and network locations for GTK apps
  services.gvfs.enable = true;
  security.polkit.enable = true;
  # Unused screen reader; speechd stays, or Electron's TTS autospawns it and Chromium aborts
  services.orca.enable = false;

  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
}
