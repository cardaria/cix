{
  lib,
  pkgs,
  ...
}:
let
  # Chromium keeps only the last --enable-features, so repeat the wrapper's
  features = [
    "AcceleratedVideoDecodeLinuxGL"
    "AcceleratedVideoEncoder"
    "WaylandWindowDecorations"
    # Without it Chromium skips VA-API on NVIDIA and decodes on the CPU
    "VaapiOnNvidiaGPUs"
  ];
  commandLineArgs = lib.concatStringsSep " " [
    "--ozone-platform=wayland"
    "--enable-features=${lib.concatStringsSep "," features}"
  ];
  origin = (pkgs.brave-origin.override { inherit commandLineArgs; }).overrideAttrs (previous: {
    postInstall = (previous.postInstall or "") + ''
      # Fresh profiles default to the system frame
      install -m644 ${../../../dotfiles/brave-origin/initial_preferences.json} \
        "$out/opt/brave.com/brave-origin/initial_preferences"
    '';
  });
in
{
  home.packages = [ origin ];
  home.sessionVariables.BROWSER = "brave-origin";
}
