# --------------------------------------------------------
# Shell History — retain useful evidence and share across sessions
# --------------------------------------------------------
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt EXTENDED_HISTORY        # save timestamp + duration for each command
setopt INC_APPEND_HISTORY      # write to history file immediately
setopt APPEND_HISTORY          # append, don't overwrite history file
setopt SHARE_HISTORY           # import new commands + share across sessions
setopt HIST_IGNORE_DUPS        # don't record consecutive duplicates
setopt HIST_FIND_NO_DUPS       # don't show dupes in ctrl+r search
setopt HIST_IGNORE_SPACE       # skip commands starting with a space
setopt HIST_REDUCE_BLANKS      # compress extra whitespace
setopt HIST_VERIFY             # verify before executing expanded history

setopt autocd
unsetopt correct
unsetopt correct_all

source $HOME/.commonrc

export EDITOR='nvim'

# Warpify the subshell (only when running inside Warp)
if [ "$TERM_PROGRAM" = "WarpTerminal" ]; then
    printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh" }}\x9c'
fi

# zsh completion
fpath+=~/.zfunc; autoload -Uz compinit; compinit
zstyle ':completion:*' menu select

# Antigravity
if [ -d "$HOME/.antigravity/antigravity/bin" ]; then
    export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# Starship prompt (must be last)
command -v starship &>/dev/null && eval "$(starship init zsh)"


# Added by Antigravity CLI installer
export PATH="/Users/cning/.local/bin:$PATH"
