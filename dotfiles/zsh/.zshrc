# --- Prompt ---
PROMPT='%n@%m %~ %# '

# --- History ---
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p -m 700 "${HISTFILE:h}"
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# --- Keys ---
bindkey -e

# --- fzf ---
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
source <(fzf --zsh)

# --- eza ---
# Original ls stays reachable as \ls or command ls
alias ls='eza'
alias ll='eza -l'
alias la='eza -la'
alias lt='eza --tree'

# --- zoxide ---
# Replaces cd with the smart jump (cdi is the picker); original stays as builtin cd
eval "$(zoxide init zsh --cmd cd)"

# --- fastfetch ---
alias ff='fastfetch'

# --- AI CLIs ---
alias cc='claude'
alias cx='codex'

# --- cix ---
# Update inputs, preview, then apply; picks the right path for the booted entry
cix-update() {
  local out cur ans
  cd ~/Repos/cix || return
  nix flake update nixpkgs home-manager plasma-manager chandra-src chandra-model || return
  git diff --stat -- flake.lock
  out=$(nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel" \
    --no-link --print-out-paths --no-write-lock-file) || return
  cur=$(readlink -f /run/current-system)
  nix store diff-closures "$cur" "$out"
  if [[ $cur == *display-5090* ]]; then
    sudo "$out/specialisation/display-5090/bin/switch-to-configuration" dry-activate || return
  else
    sudo nixos-rebuild dry-activate --store-path "$out" --no-reexec || return
  fi
  read -q "ans?Apply now? [y/N] " || { print; print "Nothing applied; flake.lock stays updated"; return; }
  print
  if [[ $cur == *display-5090* ]]; then
    sudo "$out/specialisation/display-5090/bin/switch-to-configuration" test || return
  else
    sudo nixos-rebuild test --store-path "$out" --no-reexec || return
  fi
  systemctl --failed
  read -q "ans?Keep after reboot? [y/N] " || { print; print "Live only; a reboot returns to the old build"; return; }
  print
  if [[ $cur == *display-5090* ]]; then
    sudo nix-env -p /nix/var/nix/profiles/system --set "$out" || return
    sudo "$out/bin/switch-to-configuration" boot || return
  else
    sudo nixos-rebuild switch --store-path "$out" --no-reexec || return
  fi
  readlink -f /nix/var/nix/profiles/system
}
