{ pkgs, ... }:
{
  home.packages = [
    # hotkey_helper dlopens libX11/libXi; without them on its runpath it jumps to a null pointer
    (pkgs.teamspeak6-client.overrideAttrs (old: {
      runtimeDependencies = (old.runtimeDependencies or [ ]) ++ [
        pkgs.libx11
        pkgs.libxi
      ];
    }))
  ];
}
