---
title: Network share
category: system
tags: [smb, cifs, mount, agenix]
updated: 2026-10-23
---

# Network share

An SMB share from pve (its address and secret come from the private pve repo) is
mounted at `~/Shares/Cloud` from boot and stays mounted. The kernel client reconnects on its own after network or
server interruptions.

## How it works

| Option | Effect |
| --- | --- |
| `_netdev` | mounted at boot once the network is online |
| `nofail`, `x-systemd.mount-timeout=10s` | an offline server doesn't block boot |
| `credentials=/run/agenix/smb-cloud` | username/password from the agenix secret |
| `uid`/`gid` = cardaria/users, `file_mode=0600`, `dir_mode=0700` | private to the user |
| `nosuid`, `nodev` | no setuid or device files from the server |

`~/Shares` is created by tmpfiles (0700) and is also an XDG user dir (`SHARES`).

## Use it

```sh
findmnt ~/Shares/Cloud
systemctl status home-cardaria-Shares-Cloud.mount
```

It also appears in Dolphin under its mount point.

## Change the credentials

The secret is `secrets/smb-cloud.age` in the private pve repo; edit it there, deploy the server's
share (it applies the password when it starts), then
`nix flake update pve` here so draba takes it, rebuild, close open files and remount:

```sh
sudo systemctl restart home-cardaria-Shares-Cloud.mount
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Not mounted after boot | the server was offline at boot: `sudo systemctl start home-cardaria-Shares-Cloud.mount` |
| `ls` hangs ~10 s, then errors | server offline or its address changed (see `fileSystems` in `hosts/draba/network-share.nix`) |
| Permission denied | wrong credentials: re-edit `smb-cloud.age` in the pve repo, update the `pve` input, rebuild, remount |
| Mount stale after network change | `sudo systemctl restart home-cardaria-Shares-Cloud.mount` |

## Related

- [Secrets](../security/secrets.md) · [draba](../architecture/draba.md)
