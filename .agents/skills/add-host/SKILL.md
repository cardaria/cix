---
name: add-host
description: >
  Add, install or retire a NixOS host in ~/Repos/cix (a new machine or a VM).
  Use when the user says "add a host", "set up NixOS on <machine>", "make a
  VM for…", "install cix on…" or "remove host <name>". Covers the host
  folder, the flake entry, shared-module reuse, Disko, agenix recipients,
  the install (local or nixos-anywhere) and the docs every host needs.
---

# Add a host

**IRON LAW: a host is added only on the user's request, and everything
machine-specific stays in `hosts/<host>/`. Disk formatting, installs and
re-encrypting secrets each need exact-scope approval.**

## Step 0: decide with the user

| Question | Why it matters |
| --- | --- |
| Name and role (workstation, server, VM) | host folder, README Hosts table |
| Architecture, physical or VM | `system`, hardware config, install path |
| Disk, by `/dev/disk/by-id` | Disko target; a VM disk may have no stable ID, so use the hypervisor's (e.g. `virtio-…`) |
| Desktop or headless | which `modules/nixos/` it imports |
| Users who log in, and their Home Manager config | `home-manager.users` |
| Secrets it needs | agenix recipients |

Read `wiki/architecture/flake.md` and the existing host's folder first; copy
patterns, not values.

## Step 1: host folder

```text
hosts/<host>/
  default.nix         imports the files below
  configuration.nix   hostName, locale, users, bootloader, nix settings, stateVersion
  hardware.nix        generated, no filesystems (Disko owns them)
  storage.nix         Disko layout, disk by ID
```

- `system.stateVersion` = the NixOS release the host is installed with; never bumped.
- Add files like `graphics.nix` only when the host needs them.
- Hardware config comes from the target itself:
  `nixos-generate-config --no-filesystems --show-hardware-config` (or
  nixos-anywhere's `--generate-hardware-config`, Step 4).

## Step 2: flake

- Add `nixosConfigurations.<host>` in `flake.nix`.
- With two hosts, move the module list both share into a `let` binding;
  each host adds its own modules. No `mkHost` function, no auto-discovery
  (`AGENTS.md` → *Maintenance preferences*).
- Desktop modules (`desktop.nix`, `login.nix`, plasma-manager) only on desktop hosts.
- `modules/nixos/packages.nix` provides `cixPkgs` to any host that imports it.
- Shared code must not assume one host's hardware. If it does, move that part into `hosts/<host>/`.

## Step 3: secrets (exact-scope approval)

Only if the host needs secrets:

1. Generate the host's own age identity on the target, at
   `/var/lib/agenix/identity.txt` (root, 0600), and set `age.identityPaths`.
2. Commit its public key as `secrets/<host>.pub` (`age-keygen -y`).
3. Add it to the matching entries in `secrets/agenix-rules.nix`, then
   re-encrypt: `nix run .#agenix -- -r` from `secrets/`. Rules alone grant nothing.
4. Back the identity up in 1Password as **<host> agenix recovery key**.

## Step 4: install (user, or agent with exact approval)

- Physical machine with the live ISO: follow `wiki/system/boot.md` →
  *Fresh installation*, with `<host>` in place of the existing host.
- Remote machine or VM reachable over SSH from any Linux live system:

  ```sh
  nix run github:nix-community/nixos-anywhere -- \
    --flake .#<host> \
    --generate-hardware-config nixos-generate-config ./hosts/<host>/hardware.nix \
    --target-host root@<address>
  ```

  It runs Disko (erasing the target disk) and installs. Copy the age
  identity in with `--extra-files <dir>` when secrets are needed.
- Later deploys: `nixos-change` (`--target-host` for remote hosts).

A guest on pve is not a host of this repo: it is added in the private pve repo (`~/Repos/pve`,
its `AGENTS.md`), and nothing about it goes here.

## Step 5: docs and checks

- `wiki/architecture/<host>.md`: hardware, **Invariants**, storage, host choices,
  post-reboot checks, troubleshooting. Register it in `_sources.yaml`
  (all `hosts/<host>/*.nix`) and `wiki/README.md`.
- `README.md`: a row in the Hosts table.
- `AGENTS.md`: a row in the Hosts table. Host rules go in the host page's **Invariants** section, not in `AGENTS.md`.
- `nix flake check`, then build every host (`project-commit` → Step 4).
- Commit as `feat(<host>): add host`.

## Retiring a host

Remove `hosts/<host>/`, its flake entry, its `.pub` and its recipients
(re-encrypt, approval), its wiki page and table rows. Confirm nothing else
references it: `rg <host>`.

## Forbidden

- Adding a host, or "future" host config, without a request.
- Host-specific values in `modules/` or `home/`.
- Running Disko, nixos-anywhere or `agenix -r` without exact-scope approval.
- Reusing another host's age identity.
