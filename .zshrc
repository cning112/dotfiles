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
source $HOME/.commonrc

export EDITOR='vi'

# Always Warpify the subshell
printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh" }}\x9c'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/cning/.lmstudio/bin"
. "$HOME/.cargo/env"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/cning/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/cning/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/cning/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/cning/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

