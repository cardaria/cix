{ config, ... }:
{
  # Root's copy, readable before /home is mounted
  age.identityPaths = [ "/var/lib/agenix/identity.txt" ];
  age.secrets.smb-cloud = {
    # Own store path, so unrelated flake edits don't change it
    file = builtins.path {
      path = ../../secrets/smb-cloud.age;
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
    device = "//192.168.137.202/cloud";
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
    ];
  };
}
