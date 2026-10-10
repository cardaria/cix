---
title: Shell
category: desktop
tags: [zsh, fzf, eza, zoxide, history, shell]
updated: 2026-10-10
---

# Shell

Zsh is the login shell, with fzf for fuzzy history and file search, eza in
place of `ls` and zoxide in place of `cd`. The config is plain native zsh in
`dotfiles/zsh/`, live-linked.

## Layout

| File | Linked to | Role |
| --- | --- | --- |
| `dotfiles/zsh/.zshenv` | `~/.zshenv` | sets `ZDOTDIR=~/.config/zsh`, loads Home Manager's session variables |
| `dotfiles/zsh/.zshrc` | `~/.config/zsh/.zshrc` | prompt, history, fzf, aliases |

- NixOS enables zsh and its completion support (`programs.zsh.enable` in
  `hosts/draba/configuration.nix`), and sets it as `cardaria`'s shell.
- History is saved in `~/.local/state/zsh/history`. Old Bash history stays in
  `~/.bash_history`.
- Bash stays installed for scripts with a Bash shebang.
- `$EDITOR` and `$VISUAL` are `zeditor --wait` (`modules/home/development.nix`).
- `.zshenv` sources `hm-session-vars.sh`, so every zsh, including the login
  shell the login manager starts Plasma from, gets `home.sessionVariables`
  ([Plasma](plasma.md#session-variables)).

## Keys

| Key | Action |
| --- | --- |
| `Ctrl+R` | fuzzy search command history |
| `Ctrl+T` | pick files and insert their paths |
| `Alt+C` | pick a directory and `cd` into it |

## Aliases

| Alias | Runs |
| --- | --- |
| `ls` | `eza` |
| `ll` | `eza -l` |
| `la` | `eza -la` |
| `lt` | `eza --tree` |
| `ff` | `fastfetch` |

The original `ls` stays available as `\ls` or `command ls`.

`cd` is zoxide's: it still changes directory by path, and jumps to the best
match from visited directories otherwise. `cdi` picks one interactively with
fzf. The builtin stays available as `builtin cd`.

## Workflows

**Edit the shell config:**

```sh
$EDITOR ~/Repos/cix/dotfiles/zsh/.zshrc
source "$ZDOTDIR/.zshrc"      # or open a new terminal
```

No rebuild is needed. Changing the shell integration itself (new plugins
from nixpkgs) needs a package and a rebuild.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `.zshrc` ignored | `echo $ZDOTDIR` should be `~/.config/zsh`; `readlink -f ~/.zshenv` |
| Completion slow or stale | delete `~/.config/zsh/.zcompdump*` (ignored by Git) and restart |
| `$EDITOR` is nano | `/etc/set-environment` ran after Home Manager's variables: `echo $__HM_SESS_VARS_SOURCED`, open a new shell |

## Related

- [Terminal](../apps/terminal.md) · [Plasma](plasma.md)
