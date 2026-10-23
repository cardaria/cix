# The cix repos command, built once for the workstation and for the server's nightly job
{ pkgs }:
pkgs.writeShellApplication {
  name = "cix-repos";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    gh
    git
    gnugrep
    openssh
    util-linux
  ];
  text = builtins.readFile ./ui.sh + builtins.readFile ./repos;
}
