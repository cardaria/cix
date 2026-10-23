# RTX 5060 LP drives the desktop by default; RTX 5090 is CUDA only
{
  cixPkgs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cix;
  # The selected card's PCI identity, shared by the selector and the udev link
  ids = cfg.gpus.${cfg.displayGpu};
  desktopGpu = pkgs.writeShellApplication {
    name = "cix-desktop-gpu";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv = {
      DESKTOP_GPU_NAME = ids.name;
      # In the order the selector reads them from sysfs
      DESKTOP_GPU_IDS = "${ids.vendor} ${ids.device} ${ids.subsystemVendor} ${ids.subsystemDevice}";
      DESKTOP_GPU_DRIVER = "nvidia";
    };
    text = builtins.readFile ./desktop-gpu;
  };
in
{
  options.cix = {
    # Both cards are Blackwell, so CUDA tools pin the 5090 by UUID
    computeGpu = lib.mkOption {
      type = lib.types.str;
      description = "CUDA UUID of the compute GPU";
    };

    gpus = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      readOnly = true;
      description = "PCI identity of each GPU";
      default = {
        rtx5060 = {
          name = "RTX 5060 LP";
          vendor = "0x10de";
          device = "0x2d05";
          subsystemVendor = "0x1458";
          subsystemDevice = "0x41a1";
        };
        rtx5090 = {
          name = "RTX 5090";
          vendor = "0x10de";
          device = "0x2b85";
          subsystemVendor = "0x1458";
          subsystemDevice = "0x416e";
        };
      };
    };

    displayGpu = lib.mkOption {
      type = lib.types.enum [
        "rtx5060"
        "rtx5090"
      ];
      default = "rtx5060";
      description = "GPU that drives the desktop; the 5090 is compute-only unless chosen here";
    };

    consoleMode = lib.mkOption {
      type = lib.types.str;
      default = "3840x2160@160";
      description = "Kernel video= mode for the console, in KWin's mode on the display GPU's link";
    };
  };

  config = {
    services.xserver.videoDrivers = [ "nvidia" ];

    # Early KMS: the console and greeter come up on the NVIDIA driver without a mode switch
    # NVIDIA's GSP firmware comes along through modinfo
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_drm"
    ];
    # Console in KWin's mode (the 5060's DisplayPort): no mode switch up to the desktop
    boot.kernelParams = [ "video=${cfg.consoleMode}" ];
    # Also used by Plex's wrapper to pick the desktop GPU
    environment.systemPackages = [ desktopGpu ];
    # A fixed render-node path for apps configured with a device file (Plex's mpv.conf)
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="renderD*", ATTRS{vendor}=="${ids.vendor}", ATTRS{device}=="${ids.device}", ATTRS{subsystem_vendor}=="${ids.subsystemVendor}", ATTRS{subsystem_device}=="${ids.subsystemDevice}", SYMLINK+="dri/cix-desktop-render"
    '';

    # KWin's display and render devices, shared by the greeter and the Plasma session
    systemd.services.cix-desktop-gpu = {
      description = "Select the desktop GPU for KWin";
      before = [ "display-manager.service" ];
      requiredBy = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "cix-desktop-gpu";
        RuntimeDirectoryPreserve = true;
        # The selector reads udev's by-path links
        ExecStartPre = "${pkgs.systemd}/bin/udevadm settle --timeout=10";
      };
      script = ''
        card=$(${lib.getExe desktopGpu})
        render=$(basename /sys/class/drm/"''${card##*/}"/device/drm/renderD*)
        printf 'KWIN_DRM_DEVICES=%s\nKWIN_RENDER_NODES=/dev/dri/%s\n' "$card" "$render" \
          > /run/cix-desktop-gpu/kwin.env
      '';
    };
    systemd.user.services.plasma-login-kwin_wayland = {
      overrideStrategy = "asDropin";
      serviceConfig.EnvironmentFile = "/run/cix-desktop-gpu/kwin.env";
    };
    # startplasma sources these before it starts KWin and syncs them to systemd
    environment.etc."xdg/plasma-workspace/env/cix-desktop-gpu.sh".text = ''
      set -a
      . /run/cix-desktop-gpu/kwin.env
      set +a
    '';

    # The greeter's KWin reads the session's monitor config; a store copy, refreshed on rebuild
    systemd.tmpfiles.settings.plasmalogin-outputs = {
      "/var/lib/plasmalogin/.config".d = {
        user = "plasmalogin";
        group = "plasmalogin";
        mode = "0755";
      };
      "/var/lib/plasmalogin/.config/kwinoutputconfig.json"."L+".argument = "${
        ../../dotfiles/kwin/draba/kwinoutputconfig.json
      }";
    };

    cix.computeGpu = "GPU-a7c189ed-f232-10af-2df2-4346c69a5e09";

    # Boot entry for the monitor's HDMI input, cabled to the 5090; the 5060 idles
    specialisation.display-5090.configuration = {
      boot.loader.grub.configurationName = lib.mkForce "RTX 5090";
      cix.displayGpu = "rtx5090";
      # HDMI may not carry 160 Hz; set the rate once measured on this link
      cix.consoleMode = "3840x2160";
      system.nixos.tags = [ "display-5090" ];
    };

    hardware.nvidia = {
      branch = "latest";
      # Blackwell requires the open kernel modules
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      # 40 GiB of VRAM (5090 and 5060) doesn't fit the /tmp tmpfs on suspend
      moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
      # Replaced below by the multi-GPU patched driver
      videoAcceleration = false;
    };
    # Stock VA-API decodes on the 5090 whatever card it gets (pkgs/nvidia-vaapi-driver)
    hardware.graphics.extraPackages = [ cixPkgs.nvidia-vaapi-driver ];
  };
}
