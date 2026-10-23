{ lib, ... }:
{
  options.cix.computeEntrypoints = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = { };
    internal = true;
    description = "Store executables allowed to run with the compute GPU group";
  };
}
