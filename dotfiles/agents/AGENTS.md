# Global agent instructions

Read by every coding agent on this machine, in any folder. A project's own
`AGENTS.md` or `CLAUDE.md` wins for work inside that project.

This file is `dotfiles/agents/AGENTS.md` in the public cix repo, linked to
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Edit it there and keep it free
of private data (no domains, IP addresses, accounts or secrets).

Public repos never carry the server's details: its domain, public names, addresses, guests,
services or ports. Those belong in the private `~/Repos/pve`; cix reads them from there.

## This machine

- NixOS with Home Manager, declared in `~/Repos/cix`. Persistent changes to the
  machine go through that repo and its `AGENTS.md`, never imperatively.
- Don't install anything globally (`nix-env`, `nix profile install`, `npm -g`,
  `pip --user`, `curl | sh`). For a one-off tool use `nix shell nixpkgs#<pkg>`
  or `nix run nixpkgs#<pkg>`.
- Privileged commands need the user's password; ask them to run those.

## pve (Proxmox VE)

The Proxmox host runs the whole home network: DNS, VPN, reverse proxy, file
share, backups. A mistake there takes everything down, and the agent's own
access with it. These rules are stricter than anywhere else on this machine.

### Access

- `ssh pve` reaches the host as root with key auth. Never attempt password login.
- Inside a container: `ssh pve 'pct exec <id> -- <cmd>'`. Guests:
  `ssh pve 'pct list; qm list'`.
- Docs, configs and the server's own rules live in `~/Repos/pve`. Read its
  `AGENTS.md` before any change.

### Read-only by default

- Observe freely: status, logs, configs, listings, metrics.
- Never print secrets: `/etc/pve/priv/`, API tokens, `.env` values, private
  keys, passwords. Filter or redact them in every command's output.
- Never install packages or tools on the host or in a guest to investigate;
  ask first.

### Every change needs approval

Stop before any command that changes state on the host or in a guest, and ask
with:

1. the exact command and where it runs (host or guest ID);
2. what changes, and which services depend on it;
3. how to undo it.

Approval covers that exact change only; a new or wider change needs a new one.
Then:

- One change at a time; verify it before the next.
- Back up a file before editing it (`cp -a <file> <file>.bak-<YYYYMMDD>`).
  Prefer systemd drop-ins and new files over editing shipped ones.
- Afterwards, confirm the result (service active, guest running, no errors in
  the journal) and report it.
- If something goes wrong, stop, report exactly what happened, and wait. Don't
  improvise a fix.

### High-risk operations

These need the user to name the target and confirm explicitly, even after
general approval. Prepare and explain them; never run them as a side effect:

- destroying, restoring over, migrating or recreating a guest; deleting
  snapshots or backups;
- storage: pools, datasets, partitions, `wipefs`, `mkfs`, `/etc/fstab`,
  `storage.cfg`;
- networking: `/etc/network/interfaces`, `ifreload`, bridges, the Proxmox
  firewall, the DNS and VPN guests; these can cut off all access;
- rebooting or shutting down the host; stopping DNS, VPN or proxy guests;
- package upgrades (`apt upgrade`, `pveupgrade`), kernel or bootloader changes;
- users, permissions, API tokens, SSH keys, certificates.
