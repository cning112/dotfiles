setopt autocd

###################################
# set up oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
CASE_SENSITIVE="true"
ENABLE_CORRECTION="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

###################################
# disable auto-correction of command and args
unsetopt correct
unsetopt correct_all

###################################
source $HOME/.commonrc

export EDITOR='vi'

# Always Warpify the subshell
printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh" }}\x9c'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)



fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select
