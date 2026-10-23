# Destructive Disko modes erase this disk: reinstall only
{
  disko.devices.disk.samsung = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_4TB_S7Y9NJ0Y620407J";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          priority = 2;
          size = "16G";
          type = "8200";
          content = {
            type = "swap";
            resumeDevice = false;
          };
        };
        linux = {
          priority = 3;
          size = "100%";
          type = "8300";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };

  # One filesystem holds every subvolume, so scrub it once
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
