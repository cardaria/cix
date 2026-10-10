PROMPT='%n@%m %~ %# '

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p -m 700 "${HISTFILE:h}"
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

bindkey -e

export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
source <(fzf --zsh)
