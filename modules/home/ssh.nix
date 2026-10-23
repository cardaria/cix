{ registry, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Hosts tied to personal accounts live in ~/.ssh/config.local, outside Git
    includes = [ "config.local" ];

    # The Proxmox host; agents reach it as `ssh pve` (dotfiles/agents/AGENTS.md)
    settings.pve = {
      hostname = registry.addresses.pve;
      user = "root";
    };
  };
}
