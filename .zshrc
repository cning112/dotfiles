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
# Guarded with a case match so sourcing this file twice cannot duplicate the entry
# ($PATH is deduplicated in .commonrc, which runs before this).
ANTIGRAVITY_BIN="$HOME/.antigravity/antigravity/bin"
if [ -d "$ANTIGRAVITY_BIN" ]; then
    case ":$PATH:" in *":$ANTIGRAVITY_BIN:"*) ;; *) export PATH="$ANTIGRAVITY_BIN:$PATH" ;; esac
fi

# taobao-native CLI (macOS only). $HOME-relative so this file stays portable.
if $IS_MACOS; then
    TBN_CLI_BIN="$HOME/Library/Application Support/taobao/cli/bin"
    if [ -d "$TBN_CLI_BIN" ]; then
        case ":$PATH:" in *":$TBN_CLI_BIN:"*) ;; *) export PATH="$PATH:$TBN_CLI_BIN" ;; esac
    fi
fi

# Starship prompt (must be last)
command -v starship &>/dev/null && eval "$(starship init zsh)"
