{ dotfile, ... }:
{
  programs.ghostty.enable = true;

  xdg.configFile."ghostty/config.ghostty".source = dotfile "ghostty/config.ghostty";
}
