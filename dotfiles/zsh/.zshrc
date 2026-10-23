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

# --- Windows ---
# One-shot EFI BootNext, so GRUB never shows; found by loader path, not entry number
windows() {
  local line entry part
  line=$(efibootmgr | grep -i -m1 'bootmgfw\.efi') || {
    print -u2 'windows: no Windows Boot Manager entry in the firmware'
    return 1
  }
  entry=${${line#Boot}[1,4]}
  part=${(L)${line#*GPT,}%%,*}
  [[ -e /dev/disk/by-partuuid/$part ]] || {
    print -u2 "windows: the Windows boot partition ($part) is not attached"
    return 1
  }
  sudo efibootmgr --bootnext "$entry" >/dev/null || return 1
  # A failed reboot must not leave Windows queued for a later boot
  systemctl reboot || sudo efibootmgr --delete-bootnext >/dev/null
}
