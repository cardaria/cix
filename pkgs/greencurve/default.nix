{
  autoAddDriverRunpath,
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "greencurve";
  version = "0.28";

  # The source build needs upstream's hash-pinned Zig 0.13 toolchain
  src = fetchurl {
    url = "https://github.com/aufkrawall/green-curve/releases/download/${finalAttrs.version}/greencurve-${finalAttrs.version}-linux-x64.tar.xz";
    hash = "sha256-Bx2T3vkIiylvZKdL49zsbIzgXvcq0WDiNR1goiqj6kM=";
  };

  # The release tarball has no units, launcher or icon
  packaging = fetchFromGitHub {
    owner = "aufkrawall";
    repo = "green-curve";
    tag = finalAttrs.version;
    hash = "sha256-jv9yccj6UioKZmJH+j1N6t21yYXAHHcymak7Y4/Ev3M=";
  };

  nativeBuildInputs = [
    autoAddDriverRunpath
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 greencurve "$out/bin/greencurve"
    install -Dm644 LICENSE README.md -t "$out/share/doc/greencurve"

    arch="$packaging/packaging/arch"
    install -Dm644 "$arch/greencurve.service" "$arch/greencurve-resume.service" \
      -t "$out/lib/systemd/system"
    substituteInPlace "$out"/lib/systemd/system/*.service \
      --replace-fail /usr/bin/greencurve "$out/bin/greencurve"
    install -Dm644 "$arch/greencurve.desktop" -t "$out/share/applications"
    install -Dm644 "$arch/greencurve.png" -t "$out/share/icons/hicolor/256x256/apps"

    runHook postInstall
  '';

  meta = {
    description = "NVIDIA VF curve, overclock, undervolt and fan control daemon and terminal UI";
    homepage = "https://github.com/aufkrawall/green-curve";
    license = lib.licenses.mit;
    mainProgram = "greencurve";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
