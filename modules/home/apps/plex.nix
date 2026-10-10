{
  dotfile,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # Zink supplies NVIDIA OpenGL inside Plex's Mesa-only FHS sandbox
  pinDesktopGpu = ''
    if card=$(/run/current-system/sw/bin/cix-desktop-gpu 2>/dev/null); then
      device=/sys/class/drm/''${card##*/}/device
      export MESA_LOADER_DRIVER_OVERRIDE=zink
      export MESA_VK_DEVICE_SELECT=$(sed 's/^0x//' "$device"/vendor):$(sed 's/^0x//' "$device"/device)
      export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
    fi
  '';
  plex = pkgs.symlinkJoin {
    name = pkgs.plex-desktop.name;
    inherit (pkgs.plex-desktop) meta;
    paths = [ pkgs.plex-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/plex-desktop"
      makeWrapper ${pkgs.plex-desktop}/bin/plex-desktop "$out/bin/plex-desktop" \
        --run ${lib.escapeShellArg pinDesktopGpu}
      cp --remove-destination ${pkgs.plex-desktop}/share/applications/plex-desktop.desktop \
        "$out/share/applications/plex-desktop.desktop"
      chmod u+w "$out/share/applications/plex-desktop.desktop"
      cp --remove-destination ${../../../dotfiles/plex/assets/plex.png} \
        "$out/share/icons/hicolor/scalable/apps/plex-desktop.png"
      # Absolute path, independent of the icon theme
      substituteInPlace "$out/share/applications/plex-desktop.desktop" \
        --replace-fail 'Icon=plex-desktop' "Icon=$out/share/icons/hicolor/scalable/apps/plex-desktop.png"
      echo 'GenericName=Media Player' >> "$out/share/applications/plex-desktop.desktop"
    '';
  };
in
{
  home.packages = [ plex ];

  xdg.dataFile."plex/mpv.conf".source = dotfile "plex/${osConfig.networking.hostName}/mpv.conf";
}
