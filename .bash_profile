# 加载系统范围的配置文件
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# 加载用户的 .bashrc
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/cning/.lmstudio/bin"
. "$HOME/.cargo/env"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/cning/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
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

