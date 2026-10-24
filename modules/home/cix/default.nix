# The cix CLI: one dispatcher, subcommands registered by the modules that own them
{
  config,
  lib,
  pkgs,
  ...
}:
let
  commands = config.cix.commands;
  cixDir = "${config.cix.reposDir}/cix";
  pveDir = "${config.cix.reposDir}/pve";
  names = lib.attrNames commands;
  width = lib.foldl' lib.max 0 (map lib.stringLength names);
  usage = pkgs.writeText "cix-usage" ''
    Usage: cix <command> [args]

    Commands:
    ${lib.concatMapStringsSep "\n" (
      name:
      "  ${name}${
          lib.concatStrings (lib.replicate (width - lib.stringLength name + 2) " ")
        }${commands.${name}.description}"
    ) names}

    Run 'cix <command> --help' for details.
  '';
  cases = lib.concatMapStringsSep "\n" (name: ''
    ${name}) shift; exec ${lib.getExe commands.${name}.package} "$@" ;;
  '') names;
  cix = pkgs.writeShellApplication {
    name = "cix";
    text = ''
      if [[ ''${1:-} == help && $# -gt 1 ]]; then
        set -- "$2" --help
      fi
      case ''${1:-help} in
        help | -h | --help) cat ${usage} ;;
        ${cases}
        *)
          echo "cix: unknown command '$1'" >&2
          cat ${usage} >&2
          exit 1
          ;;
      esac
    '';
  };
  ui = builtins.readFile ./ui.sh;
  steps = builtins.readFile ./steps.sh;
  generations = builtins.readFile ./generations.sh;
  # op is left out on purpose: only the setgid wrapper reaches the desktop app
  backup = pkgs.writeShellApplication {
    name = "cix-backup";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gawk
      gnugrep
      hostname
      jq
      openssh
    ];
    runtimeEnv.REPO = cixDir;
    text = ui + builtins.readFile ./backup;
  };
  # The guests of the pve repo: cix update hands those targets to it
  updatePve = pkgs.writeShellApplication {
    name = "cix-update-pve";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      dig
      gawk
      git
      gnugrep
      gnused
      jq
      less
      nix
      nixos-rebuild
      openssh
      skopeo
      util-linux
    ];
    runtimeEnv.REPO = pveDir;
    text = steps + generations + builtins.readFile ./update-pve;
  };
  update = pkgs.writeShellApplication {
    name = "cix-update";
    runtimeInputs = with pkgs; [
      backup
      coreutils
      gawk
      git
      gnugrep
      gnused
      hostname
      jq
      less
      nix
      nixos-rebuild
      updatePve
      util-linux
    ];
    runtimeEnv = {
      REPO = cixDir;
      PVE = pveDir;
    };
    text = steps + generations + builtins.readFile ./update;
  };
  rollback = pkgs.writeShellApplication {
    name = "cix-rollback";
    runtimeInputs = [ update ];
    text = ''
      export CIX_ACTION=rollback
      exec cix-update "$@"
    '';
  };
  repos = import ./repos-package.nix { inherit pkgs; };
in
{
  options.cix.reposDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Repos";
    description = "The folder holding the cix and pve checkouts; the cix commands work on <reposDir>/cix and <reposDir>/pve.";
  };

  options.cix.commands = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            description = "One line shown in `cix --help`";
          };
          package = lib.mkOption {
            type = lib.types.package;
            description = "Program run as `cix <name> ...`";
          };
        };
      }
    );
    default = { };
    description = "Subcommands of the cix CLI";
  };

  config = {
    cix.commands.update = {
      description = "Update this machine for its next boot, or the guests on pve";
      package = update;
    };
    cix.commands.rollback = {
      description = "Review and restore retained system generations";
      package = rollback;
    };
    cix.commands.backup = {
      description = "Back up and verify this host's recovery keys in 1Password";
      package = backup;
    };
    cix.commands.repos = {
      description = "Mirror every GitHub repository locally and to GitLab";
      package = repos;
    };

    home.packages = [ cix ];
  };
}
