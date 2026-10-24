---
title: Secrets
category: security
tags: [agenix, age, ssh, secrets, backup, recovery]
updated: 2026-10-24
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

The root copy lets system decryption work independently of the user's home
and editing key. One dedicated age key serves both copies.

## Edit or create a secret

```sh
cd ~/Repos/cix/secrets
umask 077
EDITOR=nano TMPDIR="$XDG_RUNTIME_DIR" \
  nix run ..#agenix -- -e codex-lb.age -i "$HOME/.config/agenix/identity.txt"
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

Each host's recovery keys are 1Password **Documents** in the `Personal` vault:

| Document | Local key | Checked against |
| --- | --- | --- |
| **<host> agenix recovery key** | `~/.config/agenix/identity.txt` | `secrets/<host>.pub` |
| **<host> SSH key** | `~/.ssh/id_ed25519` | `~/.ssh/id_ed25519.pub` |

`cix backup` uploads a missing one after asking, and verifies each copy by
deriving its public key from the downloaded document, so no second plaintext
copy lands on disk. Local private/public key mismatches and failed downloads cannot be marked verified.
Concurrent runs wait for one backup lock. It never overwrites an item: a mismatch or a duplicate
title is reported for you to resolve in 1Password. `cix backup --check`
uploads nothing. Verified public keys are remembered in
`~/.local/state/cix/backups`, so `cix update draba` (which runs `cix backup --auto --check`)
only reaches 1Password when a key is new or changed; this cache is not a fresh check that the remote item still exists. The 1Password CLI can't
import an existing key as an SSH Key item, hence Documents.

To verify the agenix copy by hand:

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

The SSH key comes back the same way; the public key is derived from it:

```sh
(
  umask 077
  set -o noclobber
  op document get "$(hostname) SSH key" > ~/.ssh/id_ed25519 &&
    ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
)
```

The SSH example refuses to overwrite existing files. If retrieval fails, inspect
the partial file before retrying; do not replace a working key. Check for an
existing root key before replacing it. For a fresh install, place
the root copy at `/mnt/var/lib/agenix/identity.txt` before first boot
([Boot & recovery](../system/boot.md#fresh-installation)).

## Current secrets

| File | Consumer |
| --- | --- |
| `codex-lb.age` (the API key alone) | the `codex` wrapper ([Developer tools](../dev/tools.md#codex-via-codex-lb)), readable by the user only |

The share's secret, `smb-cloud.age` (`username=` / `password=`), is in the private pve repo; draba reads
it from the `pve` input ([Network share](../system/network-share.md)). So are the server's own secrets
and each guest's age identity: that repo's `secrets/` and `wiki/security.md` list them. `cix backup` covers
only this machine's key.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `no identity matched any of the recipients` | wrong key: compare `age-keygen -y` with `secrets/<host>.pub` |
| Secret missing in `/run/agenix` | `journalctl -b -u agenix` (or activation log); is the root identity present? |
| Secret edit absent from a rebuild | stage new `.age` files; tracked edits are included without committing. Check the input revision when consuming a secret from another repo |

## Related

- [1Password](1password.md) · [Network share](../system/network-share.md)
- [agenix tutorial](https://ryantm.github.io/agenix/tutorial/)
- memory: `agenix-key-in-1password`
