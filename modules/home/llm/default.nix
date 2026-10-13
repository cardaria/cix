{
  cixPkgs,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (cixPkgs) ninfer;
  endpoint = "127.0.0.1:8080";
  # Upstream model ID every profile serves; also the warm selector's name
  served = "qwen3.8-27b";

  model = {
    repo = "neroued/Qwen3.8-27B-nvfp4-NInfer";
    rev = "a107ba1b5b0609d9ca90d5ed61439f5f5cc7d64d";
    file = "qwen3_8_27b_nvfp4.ninfer";
    sha256 = "74d2c57145e6ff11d1d2faa79594477f9bc903a611af1fb20218189fbbb77d82";
    dir = "${config.xdg.userDirs.extraConfig.AI}/llm/models";
  };

  # Both share the KV pool between two lanes; one request may use all of it
  profiles = [
    {
      id = "${served}-fast";
      name = "Qwen3.8 27B · Fast 128K";
      context = 131072;
      spec = "--spec dflash2 --draft-tokens 7 --lm-head-draft";
    }
    {
      id = "${served}-long";
      name = "Qwen3.8 27B · Long 256K";
      context = 262144;
      # DFlash2's extra weights leave too little VRAM for 262K of KV
      spec = "--spec mtp --draft-tokens 3 --lm-head-draft";
    }
  ];
  ids = map (p: p.id) profiles;

  # --- llama-swap ---

  swapConfig = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    healthCheckTimeout = 300;
    logToStdout = "both";
    startPort = 10001;
    # Early HTTP 200 turns startup failures into broken streams that OpenCode retries
    sendLoadingState = false;
    # Seconds after the last finished request; in-flight requests pause it
    globalTTL = 900;
    unloadTimeout = 30;
    performance.disabled = true;

    models = lib.listToAttrs (
      map (
        p:
        lib.nameValuePair p.id {
          inherit (p) name;
          useModelName = served;
          cmd = lib.concatStringsSep " " [
            (lib.getExe ninfer)
            "${model.dir}/${model.file}"
            "--host 127.0.0.1 --port \${PORT} --model-id ${served}"
            "--max-context ${toString p.context} --kv-capacity ${toString p.context}"
            "--max-concurrency 2 --kv-dtype fp8 ${p.spec}"
            "--preserve-thinking"
            # OpenCode's title request queues behind the first turn
            "--pending-timeout-ms 900000"
          ];
        }
      ) profiles
    );

    # Whatever profile is loaded, else a cold start of the first
    selectors.${served} = {
      strategy = "warm";
      targets = ids;
    };

    # One profile on the GPU at a time; a swap waits for in-flight requests
    routing.router = {
      use = "group";
      settings.groups.gpu = {
        swap = true;
        exclusive = true;
        members = ids;
      };
    };
  };

  # --- OpenCode ---

  # Qwen's accepted efforts; thinking-off first because OpenCode uses it for titles
  efforts = [
    "none"
    "low"
    "medium"
    "xhigh"
  ];
  variants = lib.listToAttrs (
    lib.imap0 (
      i: effort:
      let
        variant.reasoningEffort = effort;
      in
      lib.nameValuePair effort (
        # A plain value is unordered; the rest chain after it
        if i == 0 then variant else lib.hm.dag.entryAfter [ (lib.elemAt efforts (i - 1)) ] variant
      )
    ) efforts
  );

  cixLlm = pkgs.writeShellApplication {
    name = "cix-llm";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      gnugrep
      jq
      systemd
    ];
    runtimeEnv = {
      ENDPOINT = "http://${endpoint}";
      MODEL_REPO = model.repo;
      MODEL_REV = model.rev;
      MODEL_FILE = model.file;
      MODEL_SHA256 = model.sha256;
      MODEL_DIR = model.dir;
      COMPUTE_GPU = osConfig.cix.computeGpu;
    };
    text = builtins.readFile ./cix-llm;
  };
  llmWorker = pkgs.writeShellApplication {
    name = "cix-llm-worker";
    runtimeEnv.CUDA_VISIBLE_DEVICES = osConfig.cix.computeGpu;
    text = ''
      [[ $# == 0 ]]
      exec ${lib.getExe pkgs.llama-swap} --listen ${endpoint} --config ${swapConfig}
    '';
  };
in
{
  cix.commands.llm = {
    description = "Local LLM: status, unload, logs, tps, fetch, ui";
    package = cixLlm;
  };
  cix.computeEntrypoints.llm = llmWorker;

  systemd.user.services.llama-swap = {
    Unit.Description = "On-demand local LLM gateway";
    Service = {
      ExecStart = "/run/wrappers/bin/sudo --non-interactive --user=${config.home.username} --group=cix-compute ${lib.getExe llmWorker}";
      Restart = "on-failure";
      RestartSec = 3;
      # Above unloadTimeout, so NInfer exits cleanly and frees the VRAM
      TimeoutStopSec = 45;
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.opencode = {
    enable = true;
    settings = {
      model = "local/${(lib.head profiles).id}";
      autoupdate = false;
      share = "disabled";
      # Clears old tool output before it forces a compaction
      compaction.prune = true;

      provider.local = {
        npm = "@ai-sdk/openai-compatible";
        name = "Local";
        options = {
          baseURL = "http://${endpoint}/v1";
          # A swap can wait for another profile's request to finish
          headerTimeout = 900000;
        };
        models = lib.listToAttrs (
          map (
            p:
            lib.nameValuePair p.id {
              inherit (p) name;
              limit = {
                inherit (p) context;
                output = 32000;
              };
              tool_call = true;
              reasoning = true;
              attachment = false;
              # Replays thinking, which the template keeps and the prefix cache expects
              interleaved.field = "reasoning_content";
              inherit variants;
            }
          ) profiles
        );
      };
    };
  };
}
