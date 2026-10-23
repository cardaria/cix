{
  lib,
  osConfig,
  pkgs,
  registry,
  ...
}:
let
  # codex-lb on pve pools ChatGPT accounts; ~/.codex/config.toml stays Codex's own
  provider = ''{ name = "openai", base_url = "https://${registry.services.codex-lb.fqdn}/backend-api/codex", wire_api = "responses", env_key = "CODEX_LB_API_KEY", supports_websockets = true, supports_standalone_web_search = true, requires_openai_auth = true }'';
  codex = pkgs.symlinkJoin {
    name = "codex";
    paths = [ pkgs.codex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/codex \
        --run 'export CODEX_LB_API_KEY="$(< ${osConfig.age.secrets.codex-lb.path})"' \
        --add-flag -c --add-flag model_provider=codex-lb \
        --add-flag -c --add-flag ${lib.escapeShellArg "model_providers.codex-lb=${provider}"}
    '';
  };
in
{
  home.packages = [ codex ];
}
