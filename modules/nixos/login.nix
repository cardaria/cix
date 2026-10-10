{ config, pkgs, ... }:
let
  # The greeter's KWin reads pointer settings here; it can't read the home directory
  source = "${config.users.users.cardaria.home}/.config/kcminputrc";
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
}
