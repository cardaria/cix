---
title: 1Password
category: security
tags: [1password, op, cli, polkit]
updated: 2026-10-19
---

# 1Password

The 1Password GUI and CLI are installed through their NixOS modules
(`modules/nixos/1password.nix`). Those set up the setgid wrappers and polkit
policy that browser and CLI integration need, which a plain package install does not.

## Setup on a new machine

1. Activate the system, then launch `1password` and sign in.
2. **Settings → Developer → Integrate with 1Password CLI**.
3. Check it:

```sh
op whoami
```

Unlock prompts come from 1Password itself. System-auth prompts come through
KDE's polkit agent, `polkit-kde-agent-1` (the polkit owner is `cardaria`).

## Used for

- The off-machine backup of the agenix and SSH keys, made and verified by `cix backup` ([Secrets](secrets.md#back-up-the-key-1password)).
- Account sign-in and vault contents stay in 1Password, never in Git.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `op` says the app isn't connected | enable CLI integration in Settings → Developer; keep the app unlocked |
| No system-auth prompt | KDE's polkit agent: `systemctl --user restart plasma-polkit-agent` |
| Browser extension can't reach the app | the browser must be allowed in 1Password's settings (custom browsers list) |

## Related

- [Secrets](secrets.md)
- [1Password CLI get started](https://www.1password.dev/cli/get-started)
