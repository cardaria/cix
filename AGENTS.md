# cix — agent working rules

Personal NixOS flake with integrated Home Manager. Each machine is a host in
`hosts/<host>/` with its own wiki page. This file is the contract for every
coding agent (Claude Code, Codex, …). `CLAUDE.md` only imports it. Rules are
imperative on purpose: follow them as written.

## Stack

Shared by every host unless its page says otherwise.

| Item | Value |
| --- | --- |
| System | NixOS unstable with flakes; inputs are updated deliberately |
| User side | Home Manager as a NixOS module; plasma-manager on desktop hosts |
| Storage | Disko with btrfs subvolumes; disks referenced by `/dev/disk/by-id` |
| Secrets | agenix; one age identity per host at `/var/lib/agenix/identity.txt`, backed up in 1Password |
| Desktop | KDE Plasma 6 on Wayland, Plasma Login Manager |
| Shell / editor | zsh, Ghostty; Zed is `$EDITOR` |

## Hosts

| Host | Role | Page |
| --- | --- | --- |
| `draba` | workstation | [wiki/architecture/draba.md](wiki/architecture/draba.md) |
| `pve` | the Proxmox server and its NixOS guests: declared in the private pve repo, not here | `~/Repos/pve` (its `AGENTS.md`) |

`hostname` tells you which host you are on. Read the host's page before
changing it; its **Invariants** section lists what must not change without
the user's request.

## Read first

1. `README.md`, then `wiki/README.md` (the wiki's map of contents).
2. The page of the host you change, and the wiki page for the component you
   touch (find it through `wiki/_sources.yaml`).
3. `memory/INDEX.md` if it exists (local, gitignored): the *why* behind decisions.
4. `git status --short` and the code itself. Code at the locked revision is the authority.

## Config boundaries

- `flake.nix` composes inputs, hosts and checks only. No inline config, no overlays.
- `hosts/<host>/`: that machine only (hardware, storage, GPU, monitor, boot,
  mounts, identity), gathered by its `default.nix`.
- `modules/nixos/`: shared system integration (desktop services, login, 1Password, local packages).
- `home/<user>/default.nix`: user identity plus an **explicit** HM import list.
- `modules/home/`: user programs. Package-only apps go in `apps/default.nix`;
  an app gets its own `apps/<app>.nix` only when it has managed config,
  an override or a service.
- `dotfiles/<app>/`: native, live-editable config, linked with the
  `dotfile "<app>"` helper (an absolute out-of-store path; never a Nix path,
  which would copy it into the store). Host-specific variants go in
  `dotfiles/<app>/<host>/`.
- `pkgs/<name>/`: hand-written packages. Each needs a provenance `README.md` and
  must be buildable on its own. Modules take them as `cixPkgs.<name>`
  (`modules/nixos/packages.nix`), never through relative imports.
- `secrets/`: only `.age` ciphertext and public recipients.
- The server (pve and its guests) is not configured here: the private pve repo is. Modules that
  need a server value take it from its registry (`registry`, `pveSrc`), never as a literal.
- Prefer native NixOS / Home Manager options over hand-written generators.

### Package placement (one home per package)

| Purpose | Location |
| --- | --- |
| Base system tools (git, gh, curl, nano) | `hosts/<host>/configuration.nix` |
| Desktop system services | `modules/nixos/desktop.nix` |
| Development tools | `modules/home/development.nix` |
| Package-only GUI/CLI apps | `modules/home/apps/default.nix` |
| Apps with config/override/service | `modules/home/apps/<app>.nix` |
| Plasma user settings (plasma-manager), KWin scripts, fonts | `modules/home/wayland/` |

Search the repo (`rg <pname>`) before adding a package. Duplicate declarations are forbidden.

## Skill routing

Project skills live in `.agents/skills/` (canonical, committed);
`.claude/skills` is a symlink to it. Use them; don't improvise their workflows.

| Task | Skill |
| --- | --- |
| Commit (and push, when asked) | `project-commit` |
| Build, test, switch, roll back; update flake inputs | `nixos-change` |
| Something is broken, slow or erroring | `troubleshoot` |
| Add, update, patch or retire a package or override | `nix-packaging` |
| Add, install or retire a host | `add-host` |
| Write, sync or audit wiki, memory, README, AGENTS | `wiki-maintainer` |
| End of session: decisions, open checks | `session-wrapup` |

## Validation ladder

Report each level separately. A lower level **never** proves a higher one.

| Level | Command | Who |
| --- | --- | --- |
| 1. Eval / checks | `nix flake check`, `git diff --check` | agent |
| 2. Build | `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths` | agent |
| 3. Preview | `nixos-rebuild dry-activate --store-path <out> --no-reexec` (root) | user, or agent if authorized |
| 4. Activate | `nixos-rebuild test` → `switch --store-path <out>` | user, or agent if authorized |
| 5. Runtime | the app or service actually works; `systemctl --failed` is empty | **user**-confirmed |

- Git flakes ignore untracked files: stage the new files themselves
  (`git add <path>`) or evaluate with `path:.`. Never stage unrelated work to
  make a build pass.
- Live dotfile edits need the app's reload, not a rebuild. A generation
  rollback does **not** revert live dotfiles.
- The user performs reboots. Driver and kernel changes are only proven by a reboot.

## Safety boundaries

- Identify disks by persistent ID (`/dev/disk/by-id`), never by `/dev/nvmeXnY`.
  Disko destructive modes are only for an explicitly approved reinstall.
- Get **exact-scope approval** for destructive storage operations, bootloader/EFI, Secure Boot, public exposure, large deletions, secret
  or key operations, and Git history rewrites. Preparation is not approval.
  Existing approval covers only an unchanged scope.
- Never commit plaintext credentials or private keys. Don't rotate keys during cleanup.
- Before any `test`, `switch` or `boot`, run `readlink -f /run/current-system`.
  If the path contains a specialisation tag (`draba`: `display-5090`), you are
  booted into that entry: activate the specialisation's own closure
  (`<out>/specialisation/<name>/bin/switch-to-configuration test`), never the
  base `<out>`. Activating the base from a specialisation swaps the display GPU
  under the running session and leaves a dead screen (2026-10-12). See
  [wiki/deployment.md](wiki/deployment.md#booted-into-a-specialisation).
- Preserve each host's **Invariants** (its wiki page), Zed as `$EDITOR`, and
  deliberate (never unattended) input updates. UI scale comes from the
  compositor only, never per-app scale flags or variables. Match displays by
  stable identity (EDID/serial), never by connector name.
- The repo is public. Commits use the GitHub noreply address, and nothing
  personal is committed: accounts, other people, logins on machines cix
  doesn't manage. Those live in untracked files (e.g. `~/.ssh/config.local`).
- Nothing about the server is committed here, in code or docs: no domains, public names, addresses,
  guest names, services or ports. It all lives in the private pve repo (`~/Repos/pve`); draba reads the
  few values it needs from that repo's registry through the `pve` input. `nix flake check` fails when
  any file here contains the domain or an address from that registry.
- Docs never repeat private identifiers: IP addresses, domains, serial numbers, disk
  IDs, MAC addresses. Code may hold draba's own hardware identifiers; docs name the file instead.
  `nix flake check` rejects IPv4 addresses in docs.
- Don't add deferred services or future-host configuration without a request.

## Git and docs

- Commit only when asked, through `project-commit`. Format:
  `type(scope): description`, where type ∈ feat/fix/refactor/chore/docs and
  scope = module or area (`plasma`, `kwin`, `brave`, `wiki`, `skills`, `flake`, …).
- Never `git add -A`, `reset --hard`, `checkout --`, or `clean` over the user's
  work. Push, amend, rebase and PRs only on explicit request.
- Branches, when used, are named by purpose (`feat/…`, `fix/…`, `docs/…`).
  Never use tool-name prefixes (`claude/`, `codex/`).
- A change to a `.nix` file or a user-visible behaviour must update the
  wiki pages bound to it in `wiki/_sources.yaml` **in the same commit**.
  New or removed modules update `_sources.yaml`, `wiki/README.md` and the
  README tree.
- Non-obvious decisions go into `memory/cards/` (local), never inline in the wiki.
- `memory/`, `issues/` and editor folders stay out of Git.

## Maintenance preferences

- Explicit imports. No module-discovery framework, no host factory, no
  abstraction for a single implementation.
- Before deleting, confirm nothing imports, references or needs it at runtime.
- Clean up only dead code, duplicates and stale docs. Don't remove apps or
  tools the user deliberately keeps.
- History lives in Git. Restore retired configs from history (see the
  `archive-custom1-retired` memory card), never by re-vendoring copies.

## Config style

Applies to every hand-written config: Nix, dotfiles, scripts.

- Comments only where the code can't speak for itself: a *why*, a gotcha, a
  link between files. Never restate the line below.
- One short line per comment, a fragment: capital first letter, no trailing
  period. No paragraphs, no history, no "we tried…".
- Group lines by what they do, one blank line between groups. Unrelated
  settings never share a group; related ones never get split.
- Long flat files use `# --- Section ---` headers; short files need none.
- Generated and app-written files are exempt.
