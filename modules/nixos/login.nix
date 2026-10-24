{
  config,
  pkgs,
  ...
}:
let
  home = config.users.users.cardaria.home;

  # The greeter's KWin reads pointer settings here; it can't read the home directory
  source = "${home}/.config/kcminputrc";

  # Plasma records the chosen wallpaper in this file
  desktopConfig = "${home}/.config/plasma-org.kde.plasma.desktop-appletsrc";
in
{
  # Unlocks KWallet through the login PAM stack; Plasma (Wayland) is the default session
  services.displayManager.plasma-login-manager.enable = true;

  # The native INI generator escapes KConfig's nested section brackets
  environment.etc."plasmalogin.conf".text = ''
    [Greeter][Wallpaper][org.kde.image][General]
    Image=file:///run/cix-plasmalogin-wallpaper/wallpaper
  '';

  systemd.tmpfiles.rules = [
    "L+ /var/lib/plasmalogin/.config/kcminputrc - - - - /run/cix-plasmalogin-input/kcminputrc"
  ];

  systemd.services.plasmalogin-input-settings = {
    description = "Copy the desktop's pointer settings to the login screen";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      # Desktop-owned paths must never be read with root's access
      User = config.users.users.cardaria.name;
      RuntimeDirectory = "cix-plasmalogin-input";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
    };
    path = [ pkgs.coreutils ];
    script = ''
      if [ -e ${source} ]; then
        install -m644 ${source} /run/cix-plasmalogin-input/kcminputrc
      fi
    '';
  };
  # System Settings replaces the file on save
  systemd.paths.plasmalogin-input-settings = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = source;
  };

  systemd.services.plasmalogin-wallpaper = {
    description = "Copy the desktop wallpaper to the login screen";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.cardaria.name;
      RuntimeDirectory = "cix-plasmalogin-wallpaper";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
    };
    path = [
      pkgs.coreutils
      pkgs.gawk
    ];
    script = ''
      image=$(awk '
        /^\[/ { inside = ($0 ~ /\]\[Wallpaper\]\[org\.kde\.image\]\[General\]$/) }
        inside && /^Image=/ { sub(/^Image=/, ""); sub(/^file:\/\//, ""); print; exit }
      ' ${desktopConfig} 2>/dev/null || true)

      if [ -n "$image" ] && [ -f "$image" ]; then
        install -m644 "$image" /run/cix-plasmalogin-wallpaper/wallpaper
      fi
    '';
  };
  # Plasma rewrites the file when the wallpaper changes
  systemd.paths.plasmalogin-wallpaper = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = desktopConfig;
  };
}
