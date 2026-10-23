---
title: GPU access
category: architecture
tags: [gpu, nvidia, cuda, permissions, compute]
updated: 2026-10-22
---

# GPU access

The RTX 5090 is restricted to explicitly approved compute workloads;
desktop rendering uses the RTX 5060 and hardware monitoring remains available.

## One permission boundary

This applies to the default boot entry. In `display-5090` the 5090 drives the
desktop and the udev rule, permission service and device lock-down are not
installed; the group, sudo grants and `nvidia-smi` wrapper stay.

`hosts/draba/compute.nix` owns the policy. The 5090's NVIDIA device,
DRM card and render node belong to `root:cix-compute`, with mode `0660`.
The desktop user and login manager are not members of that group.
Shared NVIDIA control devices remain available for the 5060.

The boot service identifies the compute card by the UUID declared in
`graphics.nix`, checks its three device nodes and removes any user ACLs
before login is permitted. Its read-only `--check` mode prints the selected
nodes. A udev rule removes `uaccess` before the seat ACL rule runs and
preserves the DRM permissions.

NVIDIA's `NVreg_ModifyDeviceFiles=0` prevents its helper from restoring
world-writable permissions. The host creates NVIDIA control, modeset and
per-GPU character devices before NixOS runs `nvidia-modprobe`, which cannot
create missing nodes while this parameter is zero. On older nixpkgs, its
original direct-creation rules are used instead. Existing permissions are
preserved; the compute permission service restricts the card before login.
A plain chmod without this setting is temporary.

This prevents desktop processes from opening the compute card. Choosing
a GPU with CUDA, Vulkan or compositor settings alone does not deny access.
An app that insists on an inaccessible GPU can fail or use software;
permission restrictions do not rewrite the app's device choice.

## Approved workloads

`modules/home/compute.nix` declares the internal `cix.computeEntrypoints`
list. The LLM and OCR modules register fixed executables in the Nix store.
The host grants only those executables permission to run as the normal
user with the compute group through sudo. No root workload or password
prompt is needed, and the group is not added to the user's login session.

| Workload | Entry point | Use |
| --- | --- | --- |
| Local LLM | fixed `cix-llm-worker`, started by the user service | OpenCode or `cix llm` |
| OCR | fixed `cix-ocr-worker`, called by the CLI | `cix ocr` |

Both workers pin CUDA to the compute UUID and keep the user's model paths
and file ownership. The LLM worker accepts no arguments; OCR
keeps its document and output arguments. Sudo does not preserve arbitrary
environment overrides for these grants.

## Monitoring

System Monitor, `nvidia-smi` and nvtop retain statistics for both cards.
The host uses NixOS `security.wrappers` to give only two fixed monitoring
executables, NVIDIA's `nvidia-smi` and nvtop, the effective `cix-compute`
group. nvtop needs its own wrapper because it reads NVML in its own process
instead of calling `nvidia-smi`. Each keeps the caller's user identity; it
does not run as root or give the calling desktop process compute access.
Root-only management operations remain restricted. Invoking either store
binary directly, or any ordinary CUDA client, does not receive this group.

KDE's statistics daemon finds this executable through the standard wrapper
path. Its [query implementation](https://github.com/KDE/ksystemstats/blob/v6.7.5/plugins/gpu/NvidiaSmiProcess.cpp)
uses `--query` for discovery and `dmon -d 2 -s pucm` for live
gauges. Restart `plasma-ksystemstats.service` if it started before the
wrapper existed, so it discovers both cards. `cix llm status` uses the same
monitoring executable, with no separate privileged query worker.

Polling hardware statistics can wake the card; it does not grant Plex,
KWin or another desktop process permission to allocate GPU workloads.

## Tuning

Green Curve's root daemon (`hosts/draba/gpu-tuning.nix`) opens both cards to
apply clocks, the voltage curve, power limits and fan settings. Its
`greencurve` group lets the desktop user drive the daemon over a socket. It
allocates no CUDA context and gives the user no device access, so the compute
boundary above is unchanged. See [draba](draba.md#gpu-tuning-green-curve).

## Adding another compute tool

Register its store executable in `cix.computeEntrypoints` and launch that
executable with the same user and `cix-compute` group. Rebuild and switch.
Do not add the desktop user to the group or grant an unrestricted shell.
Installing a new desktop app needs no new 5090 permission rule.

ComfyUI and other unmanaged CUDA tools need an explicit entry before they
can use the 5090. Changing file permissions cannot revoke handles a
process already holds; log in again after changing the policy.

## Apply and verify

Build and switch through [Deployment](../deployment.md), then reboot to
load the NVIDIA module parameter and start every process with the new
permissions. A build alone does not prove enforcement at runtime.

After reboot:

```sh
systemctl status cix-compute-gpu-permissions
id
grep ModifyDeviceFiles /proc/driver/nvidia/params
nvidia-smi
cix ocr status
systemctl --user status llama-swap
```

The permission service should be active, the login groups should omit
`cix-compute`, and `ModifyDeviceFiles` should be zero. During desktop and
video use, the privileged GPU process list should contain no desktop
allocation on the 5090. Test an LLM request and representative OCR job,
then unload/exit and confirm their memory is released.

NVIDIA may reserve memory internally even with no app using the card;
zero desktop allocations is the enforcement check. Statistics remain
available through the fixed monitoring executable.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Login is blocked by the permission service | boot the previous generation; inspect the service journal and compute UUID |
| Login dependencies fail and NVIDIA character devices are missing | inspect the udev journal. With `ModifyDeviceFiles=0`, the explicit creation rules in `compute.nix` must run before `nvidia-modprobe`; keep the permission service enabled |
| Permissions become world-writable again | `ModifyDeviceFiles` is still 1; reboot into the new generation |
| LLM/OCR reports a sudo permission error | switch to the generation containing the matching store executable and sudo rule |
| A new CUDA app cannot open the 5090 | register an explicit compute entry point; leave the desktop group membership unchanged |
| GPU metrics are unavailable in the desktop | check `command -v nvidia-smi` resolves to `/run/wrappers/bin/nvidia-smi`, then restart `plasma-ksystemstats.service`; do not restore general device access |
| nvtop lists only the 5060 | `command -v nvtop` must resolve to `/run/wrappers/bin/nvtop`; the store binary has no access to the 5090 |

## Related

- [draba](draba.md) · [Local LLM](../dev/local-llm.md) · [Local OCR](../dev/local-ocr.md)
- memory: `rtx5060-display-rtx5090-compute`
