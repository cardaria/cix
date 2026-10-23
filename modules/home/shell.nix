{ dotfile, ... }:
{
  home.file.".zshenv".source = dotfile "zsh/.zshenv";
  xdg.configFile."zsh".source = dotfile "zsh";
}
