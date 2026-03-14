shopt -s autocd
shopt -s histappend

export HISTSIZE=5000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups   # skip duplicate entries

# Prefix history search with typed text (up/down arrows)
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

source ~/.commonrc

# Warpify the subshell (only when running inside Warp)
if [ "$TERM_PROGRAM" = "WarpTerminal" ]; then
    printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "bash" }}\x9c'
fi

# Starship prompt (must be last)
eval "$(starship init bash)"
