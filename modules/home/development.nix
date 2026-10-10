{ dotfile, pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    codex
    eza
    fzf
    lazygit
    micro
    nixd
    nixfmt
    vscode
    zed-editor
  ];
  home.sessionVariables = {
    EDITOR = "zeditor --wait";
    VISUAL = "zeditor --wait";
  };

  # Micro replaces its settings file on save, so link the directory
  xdg.configFile."micro".source = dotfile "micro";
  # Zed rewrites settings.json
  xdg.configFile."zed".source = dotfile "zed";
  xdg.configFile."Code/User/settings.json".source = dotfile "vscode/settings.json";
}
