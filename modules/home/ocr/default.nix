{
  chandraModel,
  cixPkgs,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  chandra = cixPkgs.chandra-ocr;
  names = lib.filter (
    name:
    lib.hasSuffix ".json" name
    || lib.hasSuffix ".jinja" name
    || lib.hasSuffix ".safetensors" name
    || name == "LICENSE"
  ) (builtins.attrNames (builtins.readDir chandraModel));
  manifest = pkgs.writeText "chandra-model.json" (
    builtins.toJSON {
      id = "datalab-to/chandra-ocr-2";
      sha = chandraModel.rev;
      files = map (
        name:
        let
          content = builtins.readFile "${chandraModel}/${name}";
          pointer = builtins.match "version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]+)\nsize ([0-9]+)\n?" content;
        in
        {
          inherit name;
          size =
            if pointer == null then builtins.stringLength content else lib.toInt (builtins.elemAt pointer 1);
          sha256 =
            if pointer == null then builtins.hashString "sha256" content else builtins.elemAt pointer 0;
        }
      ) names;
    }
  );
  modelDir = "${config.xdg.userDirs.extraConfig.AI}/ocr/models/chandra-ocr-2/${chandraModel.rev}";
  ocrWorker = pkgs.writeShellApplication {
    name = "cix-ocr-worker";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.util-linux
    ];
    runtimeEnv = {
      MODEL_METADATA = toString manifest;
      MODEL_CHECKPOINT = modelDir;
      # Only the compute GPU, so cuda:0 is never the display card
      CUDA_VISIBLE_DEVICES = osConfig.cix.computeGpu;
      TORCH_DEVICE = "cuda:0";
      TORCH_ATTN = "sdpa";
      HF_HUB_OFFLINE = "1";
      HF_HUB_DISABLE_TELEMETRY = "1";
      DO_NOT_TRACK = "1";
      TRITON_LIBCUDA_PATH = "/run/opengl-driver/lib";
      # Kernel cache under XDG instead of ~/.triton
      TRITON_CACHE_DIR = "${config.xdg.cacheHome}/triton";
      CC = "${pkgs.stdenv.cc}/bin/cc";
    };
    text = ''
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      case ''${1:-help} in
        fetch|verify|status)
          exec 9>"''${XDG_RUNTIME_DIR:?}/cix-ocr.lock"
          flock 9
          exec ${lib.getExe pkgs.python3} ${./model.py} "$1"
          ;;
      esac
      # Concurrent OCR invocations would each load the same weights
      exec 9>"''${XDG_RUNTIME_DIR:?}/cix-ocr.lock"
      flock 9
      if [[ ! -f "$MODEL_CHECKPOINT/.verified" ]]; then
        echo 'Model missing or unverified: run cix ocr fetch' >&2
        exit 1
      fi
      exec ${lib.getExe chandra} "$@" --method hf
    '';
  };
  cixOcr = pkgs.writeShellApplication {
    name = "cix-ocr";
    text = ''
      case ''${1:-help} in
        help | --help | -h)
          echo 'Usage: cix ocr INPUT OUTPUT [Chandra options]'
          echo '       cix ocr fetch|verify|status'
          echo
          exec ${lib.getExe chandra} --help
          ;;
      esac
      exec /run/wrappers/bin/sudo --non-interactive --user=${config.home.username} \
        --group=cix-compute ${lib.getExe ocrWorker} "$@"
    '';
  };
in
{
  cix.commands.ocr = {
    description = "Chandra OCR: convert PDFs and images, fetch and verify the model";
    package = cixOcr;
  };
  cix.computeEntrypoints.ocr = ocrWorker;
}
