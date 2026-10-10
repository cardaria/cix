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
