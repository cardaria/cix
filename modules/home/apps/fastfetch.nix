{ dotfile, pkgs, ... }:
{
  home.packages = [ pkgs.fastfetch ];

  xdg.configFile."fastfetch/config.jsonc".source = dotfile "fastfetch/config.jsonc";
  xdg.configFile."fastfetch/logo.txt".source = dotfile "fastfetch/logo.txt";
}
