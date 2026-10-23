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
  greeterDir = "/var/lib/plasmalogin";

  # The greeter reads its settings here, not from its home directory
  greeterConfig = "/etc/plasmalogin.conf";
in
{
  # Unlocks KWallet through the login PAM stack; Plasma (Wayland) is the default session
  services.displayManager.plasma-login-manager.enable = true;

  systemd.services.plasmalogin-input-settings = {
    description = "Copy the desktop's pointer settings to the login screen";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      install -d -m755 -o plasmalogin -g plasmalogin /var/lib/plasmalogin/.config
      if [ -e ${source} ]; then
        install -m644 -o plasmalogin -g plasmalogin ${source} /var/lib/plasmalogin/.config/kcminputrc
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
    serviceConfig.Type = "oneshot";
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
        install -m644 -o plasmalogin -g plasmalogin "$image" ${greeterDir}/wallpaper
        printf '[Greeter][Wallpaper][org.kde.image][General]\nImage=file://${greeterDir}/wallpaper\n' > ${greeterConfig}
      fi
    '';
  };
  # Plasma rewrites the file when the wallpaper changes
  systemd.paths.plasmalogin-wallpaper = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = desktopConfig;
  };
}
