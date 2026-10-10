---
title: Boot and recovery
category: system
tags: [grub, windows, rollback, disko, live-iso, install]
updated: 2026-10-10
---

# Boot and recovery

GRUB (EFI) boots NixOS generations and chainloads Windows. When something
breaks, recovery goes in this order: an older generation, then the live ISO
plus Disko `mount`, then a fresh install.

## Contents

1. [Boot setup](#boot-setup)
2. [Roll back a bad generation](#roll-back-a-bad-generation)
3. [Recover from a live ISO](#recover-from-a-live-iso)
4. [Fresh installation](#fresh-installation)
5. [Troubleshooting](#troubleshooting)

## Boot setup

| Setting | Value |
| --- | --- |
| Loader | GRUB, EFI, `devices = [ "nodev" ]`, ESP at `/boot` |
| Timeout / default | 3 s, entry 0 (latest generation) |
| Generations | `configurationLimit = 4`. The ESP is 1 GB; one kernel with its NVIDIA initrd is ~135 MB, and the installer copies new files before pruning old ones, so the peak is 5 sets (~675 MB) |
| Other OSes | `useOSProber = true`. Windows is detected when the menu is regenerated (on switch), not at each boot |
| Fallback | the firmware's own Windows Boot Manager entry stays independent |

No Windows disk UUID or EFI path is hardcoded.

## Roll back a bad generation

- **System doesn't boot:** pick an older generation in the GRUB menu.
- **System works:**

```sh
sudo nixos-rebuild switch --rollback --no-reexec
```

Then revert the faulty change in Git separately. Generations do not restore
live dotfiles or user data.

## Recover from a live ISO

Boot a NixOS ISO in UEFI mode, connect to the network, then fetch the repo:

```sh
nix-shell -p git gh
gh auth login --git-protocol https --web && gh auth setup-git
gh repo clone cardaria/cix /tmp/cix && cd /tmp/cix
export NIX_CONFIG='experimental-features = nix-command flakes'
host=draba                           # the host to recover or install
```

**Identify the disks.** Check that the by-id path in `hosts/<host>/storage.nix`
resolves to the intended disk:

```sh
lsblk -o NAME,MODEL,SERIAL,SIZE,FSTYPE,PARTLABEL,MOUNTPOINTS
```

**Dry-run the mount**, read the script, then mount (never `format`/`destroy` for recovery):

```sh
cat "$(nix run .#disko -- --dry-run --mode mount --flake "$PWD#$host")"
ls -l /dev/disk/by-partlabel/
sudo nix run .#disko -- --mode mount --flake "$PWD#$host"
findmnt -R /mnt -o TARGET,SOURCE,FSTYPE,OPTIONS
sudo nixos-enter --root /mnt          # repair inside; `exit` to leave
```

Check that `/mnt`, `/mnt/home` and `/mnt/nix` are `@root`, `@home` and `@nix`,
and that `/mnt/boot` is the NixOS disk's ESP. Re-identify the devices in every live session.

## Fresh installation

This erases the NixOS disk. Back up data and the age key first. Start from a
live ISO with the repo cloned and `host` set ([above](#recover-from-a-live-iso)).

```sh
nix flake check
nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link
cat "$(nix run .#disko -- --dry-run --mode destroy,format,mount --flake "$PWD#$host")"
# read it: the only target must be the disk from storage.nix. Then:
sudo nix run .#disko -- --mode destroy,format,mount --flake "$PWD#$host"
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config   # compare with hardware.nix
```

Restore the age key before installing, if you're keeping the secrets:
`/mnt/var/lib/agenix/identity.txt`, root, mode 0600. Then:

```sh
sudo nixos-install --root /mnt --flake "$PWD#$host"
sudo nixos-enter --root /mnt -c 'passwd cardaria'
sudo mkdir -p /mnt/home/cardaria/Repos/cix
sudo cp -a "$PWD/." /mnt/home/cardaria/Repos/cix/
sudo nixos-enter --root /mnt -c 'chown -R cardaria:users /home/cardaria/Repos/cix'
```

After rebooting, check mounts, swap, network, `systemctl --failed`, the desktop
and that Windows still boots. Restore the user's editing key ([Secrets](../security/secrets.md#restore))
and the Berkeley Mono font ([Terminal](../apps/terminal.md)).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Switch fails with "No space left" on `/boot` | an older generation set still fills the ESP: `df -h /boot`; lower `configurationLimit` or delete old generations (`nix-collect-garbage --delete-older-than`) and switch again |
| Windows missing from GRUB | run a `switch` (regenerates the menu with os-prober); the firmware entry still works |
| Disko dry-run targets the wrong disk | stop. The by-id in `storage.nix` doesn't match this machine |

## Related

- [draba](../architecture/draba.md) · [Secrets](../security/secrets.md) · [Deployment](../deployment.md)
- memory: `disks-by-identity`
