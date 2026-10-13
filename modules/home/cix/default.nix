# The cix CLI: one dispatcher, subcommands registered by the modules that own them
{
  config,
  lib,
  pkgs,
  ...
}:
let
  commands = config.cix.commands;
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
  update = pkgs.writeShellApplication {
    name = "cix-update";
    runtimeInputs = with pkgs; [
      coreutils
      git
      hostname
    ];
    runtimeEnv.REPO = "${config.home.homeDirectory}/Repos/cix";
    text = builtins.readFile ./update;
  };
in
{
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
      description = "Update inputs, preview the changes, then apply the system";
      package = update;
    };
    home.packages = [ cix ];
  };
}
