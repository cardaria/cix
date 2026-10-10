{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Hosts tied to personal accounts live in ~/.ssh/config.local, outside Git
    includes = [ "config.local" ];
  };
}
