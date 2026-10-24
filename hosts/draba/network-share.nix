{
  config,
  pveSrc,
  registry,
  ...
}:
{
  # System decryption is independent of the user's editing key
  age.identityPaths = [ "/var/lib/agenix/identity.txt" ];
  age.secrets.smb-cloud = {
    # Own store path, so unrelated flake edits don't change it
    file = builtins.path {
      path = "${pveSrc}/secrets/smb-cloud.age";
      name = "smb-cloud.age";
    };
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /home/cardaria/Shares 0700 cardaria users -"
  ];
  fileSystems."/home/cardaria/Shares/Cloud" = {
    device = "//${registry.addresses.storage}/cloud";
    fsType = "cifs";
    options = [
      "credentials=${config.age.secrets.smb-cloud.path}"
      "uid=${config.users.users.cardaria.name}"
      "gid=${config.users.users.cardaria.group}"
      "file_mode=0600"
      "dir_mode=0700"
      "nosuid"
      "nodev"
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=10s"
      # Mounted on first access, so it can't lose the race with the network at boot; a failure retries next time
      "x-systemd.automount"
    ];
  };
}
