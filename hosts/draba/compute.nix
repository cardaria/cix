{
  config,
  lib,
  pkgs,
  ...
}:
let
  permissions = pkgs.writeShellApplication {
    name = "cix-compute-gpu-permissions";
    runtimeInputs = [
      pkgs.acl
      pkgs.coreutils
      pkgs.gawk
    ];
    runtimeEnv.COMPUTE_GPU_UUID = config.cix.computeGpu;
    text = ''
      shopt -s nullglob
      matches=()
      for info in /proc/driver/nvidia/gpus/*/information; do
        uuid=$(awk -F ':[[:space:]]*' '$1 == "GPU UUID" { print $2 }' "$info")
        if [[ "$uuid" == "$COMPUTE_GPU_UUID" ]]; then
          matches+=("$info")
        fi
      done
      if [[ ''${#matches[@]} != 1 ]]; then
        echo 'Expected exactly one compute GPU; refusing to start user sessions' >&2
        exit 1
      fi
      info=''${matches[0]}
      pci=''${info%/information}
      pci=''${pci##*/}
      minor=$(awk -F ':[[:space:]]*' '$1 == "Device Minor" { print $2 }' "$info")
      [[ "$minor" =~ ^[0-9]+$ ]]
      nodes=("/dev/nvidia$minor")
      if [[ ''${1:-} != --nvidia-only ]]; then
        for node in /sys/bus/pci/devices/"$pci"/drm/card* /sys/bus/pci/devices/"$pci"/drm/renderD*; do
          nodes+=("/dev/dri/''${node##*/}")
        done
        [[ ''${#nodes[@]} == 3 ]]
      fi
      for node in "''${nodes[@]}"; do
        [[ -c "$node" ]]
      done
      if [[ ''${1:-} == --check ]]; then
        printf '%s\n' "''${nodes[@]}"
        exit 0
      fi
      for node in "''${nodes[@]}"; do
        setfacl -b "$node"
        chown root:cix-compute "$node"
        chmod 0660 "$node"
      done
    '';
  };
  gpu = config.cix.gpus.rtx5090;
  rules = pkgs.writeTextDir "lib/udev/rules.d/72-cix-compute-gpu.rules" ''
    SUBSYSTEM=="drm", ATTRS{vendor}=="${gpu.vendor}", ATTRS{device}=="${gpu.device}", ATTRS{subsystem_vendor}=="${gpu.subsystemVendor}", ATTRS{subsystem_device}=="${gpu.subsystemDevice}", GROUP:="cix-compute", MODE:="0660", TAG-="uaccess"
  '';
in
{
  config = lib.mkMerge [
    {
      users.groups.cix-compute = { };

      # Only the fixed NVIDIA monitoring binary receives the GPU group, never root
      security.wrappers.nvidia-smi = {
        source = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi";
        owner = "root";
        group = "cix-compute";
        setgid = true;
      };

      # NVIDIA otherwise restores its device nodes to world-writable on use
      # Also in the display-5090 entry, so both entries share one initrd on the small ESP
      hardware.nvidia.moduleParams.nvidia.NVreg_ModifyDeviceFiles = 0;

      # Change only the group; compute jobs retain the user's files and ownership
      security.sudo.extraRules = [
        {
          users = [ "cardaria" ];
          runAs = "cardaria:cix-compute";
          commands = map (program: {
            command = lib.getExe program;
            options = [
              "NOPASSWD"
              "NOSETENV"
            ];
          }) (builtins.attrValues config.home-manager.users.cardaria.cix.computeEntrypoints);
        }
      ];
    }

    # Off when the 5090 drives the desktop: KWin must open the card behind the screen
    (lib.mkIf (config.cix.displayGpu != "rtx5090") {
      services.udev.packages = [ rules ];
      # Run after NixOS creates the NVIDIA character devices
      services.udev.extraRules = lib.mkAfter ''
        KERNEL=="nvidia", RUN+="${lib.getExe permissions} --nvidia-only"
      '';
      systemd.services.cix-compute-gpu-permissions = {
        description = "Restrict the compute GPU to approved workloads";
        before = [
          "display-manager.service"
          "systemd-user-sessions.service"
        ];
        requiredBy = [
          "display-manager.service"
          "systemd-user-sessions.service"
        ];
        after = [ "systemd-udev-trigger.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.systemd}/bin/udevadm settle --timeout=10";
          ExecStart = lib.getExe permissions;
        };
      };
    })
  ];
}
