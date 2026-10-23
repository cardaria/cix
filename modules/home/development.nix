{ dotfile, pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    eza
    fzf
    lazygit
    micro
    nixd
    nixfmt
    vscode
    zed-editor
    zoxide
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

  # One global instruction file for every coding agent
  home.file.".claude/CLAUDE.md".source = dotfile "agents/AGENTS.md";
  home.file.".codex/AGENTS.md".source = dotfile "agents/AGENTS.md";
}
