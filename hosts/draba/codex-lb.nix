{ config, ... }:
{
  # This host's API key for codex-lb on pve, read by the codex wrapper
  age.secrets.codex-lb = {
    file = builtins.path {
      path = ../../secrets/codex-lb.age;
      name = "codex-lb.age";
    };
    owner = config.users.users.cardaria.name;
    mode = "0400";
  };
}
