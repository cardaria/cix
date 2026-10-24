---
title: draba
category: architecture
tags: [hardware, gpu, nvidia, disko, btrfs, undervolt]
updated: 2026-10-24
---

# draba

The workstation itself: an AMD desktop with two GPUs that have separate jobs,
and a dual-boot disk layout.

## Contents

- [Hardware](#hardware) · [Invariants](#invariants)
- [GPUs](#two-gpus-two-jobs) · [Storage](#storage-disko)
- [Kernel](#kernel-and-modules) · [Locale](#locale) · [Input](#input-devices)
- [After a reboot](#after-a-reboot) · [Troubleshooting](#troubleshooting)

## Hardware

| Part | Detail | Owned by |
| --- | --- | --- |
| CPU | AMD (`kvm-amd`, microcode updates) | `hosts/draba/hardware.nix` |
| Display GPU | NVIDIA RTX 5060 LP (8 GiB), open kernel modules with early KMS | `hosts/draba/graphics.nix` |
| Compute GPU | NVIDIA RTX 5090 (32 GiB), same driver (`branch = "latest"`) | `hosts/draba/graphics.nix` |
| GPU tuning | Green Curve daemon: VF-curve undervolt, overclock, fans | `hosts/draba/gpu-tuning.nix` |
| Monitor | DisplayPort: 3840×2160 @ 160 Hz, KWin scale 150%, matched by EDID identity | `dotfiles/kwin/draba/kwinoutputconfig.json` |
| NixOS disk | 4 TB NVMe, Disko-managed | `hosts/draba/storage.nix` |
| Windows disk | separate NVMe, not managed by this repo | n/a |

## Invariants

Don't change these without the user asking:

- The default boot entry runs the desktop on the RTX 5060 over DisplayPort; the
  RTX 5090 stays compute-only. KWin is pinned to the 5060 through `cix-desktop-gpu`.
  The `display-5090` entry is the only exception (see below).
- From `display-5090`, never activate the base closure (`test`/`switch`); activate
  `<out>/specialisation/display-5090` instead. The base moves the desktop to the
  5060 under the running session and leaves a dead screen.
- The UI size is 150% on both DisplayPort and HDMI, set only by KWin's fractional scale.
- Disko owns only the disk in `hosts/draba/storage.nix`; the Windows disk is never touched.
- GRUB keeps the Windows entry (os-prober) and `configurationLimit = 4` for the 1 GB ESP.

## Two GPUs, two jobs

- The **RTX 5060 LP** runs the desktop. Connect the monitor's DisplayPort cable
  to it. The greeter and the session (KWin) both use only this card.
- The **RTX 5090** has no display and is used for CUDA compute (local LLM and OCR).
- [GPU access](gpu-access.md) restricts its device nodes to approved
  compute entry points and the fixed NVIDIA monitoring executable;
  installing a desktop app does not grant compute access.
- `hosts/draba/desktop-gpu` finds exactly one card matching the desktop
  GPU's PCI IDs and driver, and prints its `/dev/dri/cardN` path. It is
  packaged as `cix-desktop-gpu`, with the IDs set in `hosts/draba/graphics.nix`.
- Both cards use the NVIDIA driver, so the PCI IDs tell them apart. Apps
  draw through the compositor's GPU, the 5060.
- Approved compute workers pin the 5090 by its
  UUID (`cix.computeGpu`): the `llama-swap` service and `cix ocr`. Other CUDA
  programs need an explicit compute entry before using the 5090. Ordinary
  desktop CUDA clients can enumerate only the accessible 5060. CUDA
  ordering and an environment variable do not grant device permissions.
  `CUDA_VISIBLE_DEVICES` is not set session-wide: Brave's video decoding runs on the
  desktop GPU.
- **Display on the 5090 (boot entry `display-5090`):** a NixOS specialisation sets
  `cix.displayGpu = "rtx5090"`. Switch the monitor to its HDMI input (the 5090's
  cable) and pick the entry in GRUB; the default entry and the DisplayPort input
  are unchanged. `cix-desktop-gpu` then selects the 5090, so KWin, the greeter and
  the `cix-desktop-render` link follow it, and the 5090 access boundary
  ([GPU access](gpu-access.md)) is off, because KWin must open the card behind the
  screen. LLM and OCR still pin the 5090 by UUID. The 5060 idles. Both entries
  share one kernel and initrd, so the 1 GB ESP is not doubled. The console mode
  (`cix.consoleMode`) is `3840x2160` there, without a forced refresh rate.
- The 5060's slot hangs off the second chipset chip and is wired **PCIe 3.0 ×2**
  (≈2 GB/s), shared upstream with the Windows SSD, Wi-Fi, NIC and USB. The
  Gen 4 ×8 slot would sit under the 5090's fans. The desktop runs fine, but
  anything that copies whole frames off the card (screen sharing with CPU
  encoding in Discord/TeamSpeak, remote desktop, a game rendered on the 5090)
  saturates the link and the desktop stutters. Share a window at 30 fps, record
  with NVENC (gpu-screen-recorder), or move the card to the ×8 slot with a riser.
- VA-API uses a patched `nvidia-vaapi-driver` (`pkgs/nvidia-vaapi-driver/`, installed through `hardware.graphics.extraPackages`):
  the stock driver always decoded on the first card, the 5090, whichever render
  node it was given, so video drawn on the 5060 came out green (Brave) or
  crashed Plex's mpv. The patch picks the card behind the render node.
- KWin, in the greeter and in the session, is pinned to that card through
  `KWIN_DRM_DEVICES` and `KWIN_RENDER_NODES`, written at boot by the
  `cix-desktop-gpu` service ([Plasma](../desktop/plasma.md#gpu-selection)),
  so PCI or card renumbering can't move the desktop. If the card isn't found,
  the service fails and the login manager doesn't start, rather than falling
  back to the 5090.

```sh
cix-desktop-gpu          # → /dev/dri/cardN
nvidia-smi               # 5090: no display attached
```

### Early KMS and console mode

The base and `display-5090` entries share one kernel and initrd (plus older generations). The initrd loads
`nvidia`, `nvidia_modeset` and `nvidia_drm` with their GSP firmware, so the
console moves to the NVIDIA driver before stage 2. Before that it runs on the
firmware's 1024×768 framebuffer; GRUB can't raise it because the GPUs'
firmware offers no 4K mode.

The kernel's `video=3840x2160@160` puts the console in KWin's mode on the
5060's DisplayPort. The greeter and the session read the same 160 Hz mode
from `kwinoutputconfig.json` (KWin's own default is also the highest rate),
so nothing should switch modes between boot and desktop. The
rate must exist on the link: when it doesn't (the 5060's HDMI, for one), the
kernel invents a mode for it. On a link without 160 Hz, change the rate in
`hosts/draba/graphics.nix`.

### NVIDIA notes

- `open = true` is required for Blackwell. Userspace stays proprietary.
- The driver follows the newest non-beta release, and the kernel follows
  `linuxPackages_latest`. Both move only when nixpkgs is updated.
- Suspend keeps VRAM in `/var/tmp` (disk-backed, not tmpfs). Keep at least
  42 GiB free there (both cards, 40 GiB of VRAM).
- Kernel and driver changes are only proven by a reboot. Switching drivers
  in a running session is not a test.

### GPU tuning (Green Curve)

[Green Curve](https://github.com/aufkrawall/green-curve) edits the
voltage/frequency curve point by point, like MSI Afterburner on Windows. Use it
to undervolt and overclock the 5090. `hosts/draba/gpu-tuning.nix` installs
`pkgs/greencurve/`, enables `greencurve.service` (the root daemon that applies
settings) and `greencurve-resume.service` (reapplies them after suspend), and
adds the user to the `greencurve` group.

- Open the TUI with `greencurve` or the *Green Curve* launcher. It talks to the
  daemon over `/run/greencurve/greencurve.sock`, so it needs no root. Pick the
  5090 inside the TUI. The daemon sees both cards.
- The daemon keeps its state in `/var/lib/greencurve`. By default it
  reapplies the last applied settings at boot; `greencurve --show-startup`
  prints the startup policy.
- The group grants clock, voltage, power and fan control of both cards
  through the daemon. It doesn't grant CUDA access to the 5090
  ([GPU access](gpu-access.md)).
- Don't run upstream's `--service-install` or `greencurve-setup.sh`. They
  write a second unit under `/etc/systemd/system`. Don't run LACT next to it
  either: both would write the same curve.
- Test a curve under the real workload. A compute job pushed too far may
  produce wrong output instead of crashing.

## Storage (Disko)

| Partition | Size | Content |
| --- | --- | --- |
| ESP | 1G | `/boot` (GRUB) |
| swap | 16G | swap |
| btrfs | rest | `@root` → `/`, `@home` → `/home`, `@nix` → `/nix` (zstd) |

- Disko declares the layout; `hardware.nix` deliberately has no filesystems.
- There is no disk encryption and no snapshots. Generations are not backups.
- `btrfs-scrub@-.timer` checks every block against its checksum once a month.
  File data has one copy, so it reports corruption without repairing it;
  metadata is duplicated and gets repaired.
- `nh-clean.timer` (`configuration.nix`) collects garbage weekly: it keeps
  every generation from the last 7 days and never fewer than 5, removes stale
  `result` and direnv roots, then deduplicates the store.
- The disk is referenced by its `/dev/disk/by-id` path, so device renumbering
  cannot redirect Disko ([Boot & recovery](../system/boot.md)).

## Kernel and modules

- `boot.kernelPackages = pkgs.linuxPackages_latest`.
- The initrd loads `xhci_pci_prom21` (separate from `xhci_pci` since Linux 7.2)
  for the AMD PROM21 USB controller, guarded by a kernel version check.

## Locale

English UI with Swedish formats (`sv_SE` for `LC_*`), Swedish keyboard (`se`,
console `sv-latin1`), timezone `Europe/Stockholm`.

## Input devices

`hosts/draba/input.nix` declares this machine's mouse settings through
Home Manager and plasma-manager. The G-Wolves mouse uses speed −0.3 with
flat acceleration; the MonsGeek keyboard's mouse interface uses speed 0.
Device names and vendor/product IDs stay in that host module. See
[Preferences](../desktop/preferences.md#input).

## After a reboot

Kernel, NVIDIA, GPU-selection, boot and storage changes are proven only here:

| Change | Check |
| --- | --- |
| Kernel or NVIDIA | `nvidia-smi` lists both cards; `kscreen-doctor -o` shows 3840×2160 @ 160 Hz; greeter, lock/unlock and suspend/resume work on DisplayPort |
| GPU selection | `cix-desktop-gpu` prints one card; `/run/cix-desktop-gpu/kwin.env` names it; `kwin_wayland` runs only on the 5060 in `nvidia-smi` |
| Boot or GRUB | the Windows entry is listed and boots |
| Storage | `findmnt -R /` shows the three subvolumes; `swapon --show` lists swap |

Then `systemctl --failed` should be empty.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Black screen after login | is the cable on the 5060's DisplayPort? `journalctl --user -b -u plasma-kwin_wayland` |
| Dead screen or `no outputs` right after a switch | you were in `display-5090` and activated the base, which moves the desktop to the 5060 and locks the 5090. Power-cycle and boot `display-5090` again; apply changes with `<out>/specialisation/display-5090/bin/switch-to-configuration test` ([Deployment](../deployment.md#booted-into-a-specialisation)) |
| An app lags the whole desktop | check `nvidia-smi` for GPU usage and process allocations; cross-GPU frame copies can saturate the 5060's link |
| Desktop stutters while screen sharing | the ×2 slot is full: `nvidia-smi dmon -i 1 -s t` shows `txpci` near 1.9 GB/s. Share a smaller window or 30 fps |
| `cix-desktop-gpu` errors (no login manager) | `lspci -nnk \| grep -A3 VGA`. Is the 5060 bound to `nvidia`? Its PCI IDs changed if the card was replaced |
| Suspend fails with the GPUs | free space in `/var/tmp` (≥ 42 GiB) |
| CUDA missing after update | reboot first; then `nvidia-smi` |
| Updated `nvidia-smi` segfaults even with `--help` | retain the previous dependency lock; the updater now checks the candidate executable before allowing boot installation |
| Plasma and user sessions fail with a compute-permission dependency | check for missing NVIDIA character devices and udev helper failures; see [GPU access](gpu-access.md#troubleshooting). Boot a generation from before the failing input update |
| Green Curve TUI can't reach the daemon | `systemctl status greencurve`; `id` lists `greencurve` (log in again after the first switch) |
| A bad curve crashes the GPU or the desktop | `greencurve --reset --apply-config`; if it hits at boot, `greencurve --startup-profile none` first |

## Related

- [Plasma](../desktop/plasma.md) · [Login](../desktop/login.md) · [Boot & recovery](../system/boot.md)
- memory: `rtx5060-display-rtx5090-compute`, `rtx5060-pcie-gen3-x2-slot`, `disks-by-identity`
