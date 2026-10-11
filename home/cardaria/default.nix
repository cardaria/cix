{ config, ... }:
{
  imports = [
    ../../modules/home/shell.nix
    ../../modules/home/development.nix
    ../../modules/home/compute.nix
    ../../modules/home/ssh.nix
    ../../modules/home/llm
    ../../modules/home/ocr
    ../../modules/home/apps/default.nix
    ../../modules/home/apps/fastfetch.nix
    ../../modules/home/apps/ghostty.nix
    ../../modules/home/apps/obsidian.nix
    ../../modules/home/apps/brave-origin.nix
    ../../modules/home/apps/fluxer.nix
    ../../modules/home/apps/plex.nix
    ../../modules/home/apps/spotify.nix
    ../../modules/home/apps/teamspeak.nix
    ../../modules/home/apps/vesktop.nix
    ../../modules/home/apps/plasma-systemmonitor.nix
    ../../modules/home/wayland/plasma.nix
    ../../modules/home/wayland/appearance.nix
    ../../modules/home/wayland/icons.nix
  ];

  # Absolute string on purpose: a Nix path would copy dotfiles into the store
  _module.args.dotfile =
    path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Repos/cix/dotfiles/${path}";

  home.username = "cardaria";
  home.homeDirectory = "/home/cardaria";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    publicShare = null;
    templates = null;
    projects = "${config.home.homeDirectory}/Repos";
    extraConfig.SHARES = "${config.home.homeDirectory}/Shares";
    extraConfig.AI = "${config.home.homeDirectory}/AI";
  };
  # Model weights per capability, outside the repo; Nix pins their identity
  systemd.user.tmpfiles.rules = map (capability: "d %h/AI/${capability}/models 0755 - - -") [
    "llm"
    "ocr"
  ];

  # Never bump
  home.stateVersion = "26.05";
}
