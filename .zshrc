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
