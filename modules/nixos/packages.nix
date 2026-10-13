# Local packages from pkgs/, built with the system's nixpkgs for NixOS and Home Manager alike
{
  chandraSrc,
  cudaPkgs,
  pkgs,
  ...
}:
let
  cixPkgs = import ../../pkgs { inherit pkgs cudaPkgs chandraSrc; };
in
{
  _module.args.cixPkgs = cixPkgs;
  home-manager.extraSpecialArgs = { inherit cixPkgs; };
}
