setopt autocd

###################################
# set up oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
CASE_SENSITIVE="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

###################################
# disable auto-correction of command and args
unsetopt correct
unsetopt correct_all

###################################
source $HOME/.commonrc

export EDITOR='nvim'

# Warpify the subshell (only when running inside Warp)
if [ "$TERM_PROGRAM" = "WarpTerminal" ]; then
    printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh" }}\x9c'
fi

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select

# Antigravity
if [ -d "$HOME/.antigravity/antigravity/bin" ]; then
    export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi
