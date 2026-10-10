---
title: Secrets
category: security
tags: [agenix, age, secrets, backup, recovery]
updated: 2026-10-10
---

# Secrets

agenix stores credentials encrypted in Git. NixOS decrypts them at activation
into `/run/agenix/`, and services get a file path, never a password in Nix
code. Only ciphertext (`.age`) and public keys are committed.

## Keys

| Path | What | Mode |
| --- | --- | --- |
| `secrets/<host>.pub` | each host's public recipient, committed | n/a |
| `secrets/agenix-rules.nix` | which recipients can decrypt which file | n/a |
| `~/.config/agenix/identity.txt` | private key for editing | 0600, user |
| `/var/lib/agenix/identity.txt` | the same private key for system decryption | 0600, root |

The root copy is used because it is readable during early activation, before
`/home` is mounted. One dedicated age key serves both copies.

## Edit or create a secret

```sh
cd ~/Repos/cix/secrets
umask 077
EDITOR=nano TMPDIR="$XDG_RUNTIME_DIR" \
  nix run ..#agenix -- -e smb-cloud.age -i "$HOME/.config/agenix/identity.txt"
```

Saving re-encrypts. The plaintext temp file stays in the RAM-backed runtime dir.

**New secret:**

1. Add `"<name>.age".publicKeys = [ … ];` to `secrets/agenix-rules.nix`.
2. Create it with the command above.
3. Declare it in the module of the consuming service:

   ```nix
   age.secrets.example = {
     file = ../../secrets/example.age;
     mode = "0400";        # set owner/group if a non-root service reads it
   };
   ```

4. Give the service `config.age.secrets.example.path`. Stage the `.age` file,
   rebuild ([Deployment](../deployment.md)).

Adding a recipient later means **re-encrypting** (`agenix -r`). Editing the
rules alone grants nothing.

## Back up the key (1Password)

Each host's key is backed up in 1Password as **<host> agenix recovery key**.
To create the backup again, or check it:

1. In a private vault, create a **Document** named **<host> agenix recovery key**
   and attach `~/.config/agenix/identity.txt`.
2. Verify the backup without writing another plaintext copy:

```sh
set -o pipefail
op document get "$(hostname) agenix recovery key" |
  nix shell ~/Repos/cix#age -c age-keygen -y |
  cmp - ~/Repos/cix/secrets/$(hostname).pub && echo 'Backup recipient matches.'
```

Use the item ID if the title is ambiguous. Without this key, every secret has
to be recreated or its credentials reset.

## Restore

```sh
# put the key at ~/.config/agenix/identity.txt (mode 0600), then:
nix shell ~/Repos/cix#age -c age-keygen -y ~/.config/agenix/identity.txt   # must equal secrets/<host>.pub
sudo install -d -m 0700 /var/lib/agenix
sudo install -m 0600 -o root -g root ~/.config/agenix/identity.txt /var/lib/agenix/identity.txt
```

Check for an existing root key before replacing it. For a fresh install, place
the root copy at `/mnt/var/lib/agenix/identity.txt` before first boot
([Boot & recovery](../system/boot.md#fresh-installation)).

## Current secrets

| File | Consumer |
| --- | --- |
| `smb-cloud.age` (`username=` / `password=`) | [Network share](../system/network-share.md) |

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `no identity matched any of the recipients` | wrong key: compare `age-keygen -y` with `secrets/<host>.pub` |
| Secret missing in `/run/agenix` | `journalctl -b -u agenix` (or activation log); is the root identity present? |
| Rebuild unchanged after editing secret | the `.age` file must be staged/committed for the Git flake to see it |

## Related

- [1Password](1password.md) · [Network share](../system/network-share.md)
- [agenix tutorial](https://ryantm.github.io/agenix/tutorial/)
- memory: `agenix-key-in-1password`
