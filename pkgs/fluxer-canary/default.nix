{
  lib,
  fetchurl,
  appimageTools,
  imagemagick,
  libappindicator,
  libnotify,
  libva,
  speechd-minimal,
}:
let
  pname = "fluxer-canary";
  version = "2026.1014.5142";
  desktopId = "app.fluxer.FluxerDesktopCanary";

  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://pkgs.fluxer.com/desktop/canary/linux/x64/${version}/appimage";
    hash = "sha256-AAPKzDsks2vOIINEG49Z7yZCZ3s1o2abQMffjYVTees=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Electron dlopens these; appimageTools' FHS env lacks them
  extraPkgs = _: [
    libappindicator
    libnotify
    # Without it Chromium can't reach VA-API and decodes video on the CPU
    libva
    speechd-minimal
  ];

  # Otherwise it writes a .desktop entry on every launch that runs the unwrapped binary
  profile = ''
    export FLUXER_DISABLE_DESKTOP_FILE=1
  '';

  # Desktop file ID must match the app's desktopName, its Wayland app_id
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/${desktopId}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${desktopId}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
      --replace-fail '"/opt/${pname}/${pname}"' '${pname}'

    # The AppImage ships only 1024x1024, a size hicolor doesn't index
    for size in 16 22 24 32 48 64 128 256 512; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      ${lib.getExe' imagemagick "magick"} ${appimageContents}/${pname}.png -resize ''${size}x''${size} \
        $out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png
    done
  '';

  meta = {
    description = "Free and open source instant messaging and VoIP chat app (canary channel)";
    homepage = "https://fluxer.app";
    downloadPage = "https://canary.fluxer.app/download";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
