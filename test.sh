#!/bin/bash
# test.sh - verify dotfiles setup is working correctly

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
reset='\033[0m'

ok()   { echo -e "  ${green}✓${reset} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${red}✗${reset} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${yellow}→${reset} $1"; }
section() { echo ""; echo "$1"; }

# --------------------------------------------------------
section "Platform detection"
# --------------------------------------------------------
source "$SCRIPT_DIR/.commonrc" 2>/dev/null

$IS_MACOS  && ok  "IS_MACOS=true"  || info "IS_MACOS=false (not macOS)"
$IS_LINUX  && ok  "IS_LINUX=true"  || info "IS_LINUX=false (not Linux)"
$IS_WSL    && ok  "IS_WSL=true"    || info "IS_WSL=false (not WSL2)"

if ! $IS_MACOS && ! $IS_LINUX; then
    fail "Neither IS_MACOS nor IS_LINUX is set — OS detection broken"
fi

# --------------------------------------------------------
section "Symlinks in \$HOME"
# --------------------------------------------------------
SYMLINKS=(
    .zshrc .bashrc .bash_profile
    .commonrc .aliases .functions .tools
    .gitconfig
    .vimrc .ideavimrc .editorconfig .common_vimrc
    .ripgreprc
)

for f in "${SYMLINKS[@]}"; do
    if [ -L "$HOME/$f" ]; then
        target=$(readlink "$HOME/$f")
        ok "$HOME/$f -> $target"
    else
        fail "$HOME/$f is not a symlink (run setup.sh)"
    fi
done

# --------------------------------------------------------
section "Required CLI tools"
# --------------------------------------------------------
TOOLS=(nvim fzf git zoxide uv atuin)
for t in "${TOOLS[@]}"; do
    command -v "$t" &>/dev/null && ok "$t found ($(command -v $t))" || fail "$t not found"
done

# --------------------------------------------------------
section "Recommended CLI tools"
# --------------------------------------------------------
OPTIONAL=(fd bat tree lazygit zellij starship direnv)
for t in "${OPTIONAL[@]}"; do
    command -v "$t" &>/dev/null && ok "$t found" || info "$t not installed (optional but recommended)"
done

# git-delta and ripgrep: Homebrew installs them as 'delta' and 'rg', but we alias them
if command -v delta &>/dev/null; then
    ok "git-delta (delta) found"
else
    info "git-delta not installed (optional but recommended)"
fi

if command -v rg &>/dev/null; then
    ok "ripgrep (rg) found"
else
    info "ripgrep not installed (optional but recommended)"
fi

# Config symlinks
if [ -L "$HOME/.config/bat/config" ]; then
    ok "~/.config/bat/config symlinked"
else
    info "~/.config/bat/config not symlinked (run setup.sh)"
fi

if [ -L "$HOME/.config/nvim" ]; then
    ok "~/.config/nvim symlinked"
else
    info "~/.config/nvim not symlinked (run setup.sh or link lazyvim/ manually)"
fi

if [ -f "$HOME/.config/nvim/init.lua" ]; then
    ok "~/.config/nvim/init.lua found"
else
    fail "~/.config/nvim/init.lua missing — LazyVim config may not be linked"
fi

if [ -L "$HOME/.config/starship.toml" ]; then
    ok "~/.config/starship.toml symlinked"
else
    info "~/.config/starship.toml not symlinked (run setup.sh)"
fi

if [ -L "$HOME/.config/ghostty/config" ]; then
    ok "~/.config/ghostty/config symlinked"
else
    info "~/.config/ghostty/config not symlinked (run setup.sh)"
fi

if [ -L "$HOME/.config/zellij/config.kdl" ]; then
    ok "~/.config/zellij/config.kdl symlinked"
else
    info "~/.config/zellij/config.kdl not symlinked (run setup.sh)"
fi

if [ -L "$HOME/.config/atuin/config.toml" ]; then
    ok "~/.config/atuin/config.toml symlinked"
else
    info "~/.config/atuin/config.toml not symlinked (run setup.sh)"
fi

# Git reads ~/.config/git/ignore by default; ~/.gitignore is not read unless
# core.excludesFile points at it, so this is the location that matters.
if [ -L "$HOME/.config/git/ignore" ]; then
    ok "~/.config/git/ignore symlinked (global git ignore)"
else
    info "~/.config/git/ignore not symlinked (run setup.sh)"
fi

for f in CLAUDE.md RTK.md; do
    if [ -L "$HOME/.claude/$f" ]; then
        ok "~/.claude/$f symlinked"
    else
        info "~/.claude/$f not symlinked (run setup.sh)"
    fi
done

# --------------------------------------------------------
section "Shell config syntax check"
# --------------------------------------------------------
for f in .commonrc .aliases .functions .tools .bashrc .bash_profile; do
    if bash -n "$SCRIPT_DIR/$f" 2>/dev/null; then
        ok "$f syntax OK"
    else
        fail "$f has syntax errors:"
        bash -n "$SCRIPT_DIR/$f"
    fi
done

if zsh -n "$SCRIPT_DIR/.zshrc" 2>/dev/null; then
    ok ".zshrc syntax OK"
else
    fail ".zshrc has syntax errors"
fi

# --------------------------------------------------------
section "History analyzer"
# --------------------------------------------------------
if ! command -v uv &>/dev/null; then
    fail "uv not found (needed to run hist-analyze and its tests)"
elif uv run --script "$SCRIPT_DIR/tests/test_hist_analyze.py" >/dev/null 2>&1; then
    ok "hist-analyze behavior tests pass"
else
    # An unwritable/read-only uv cache fails before the tests even start, so retry
    # once with a throwaway cache instead of reporting an environment problem as a
    # test failure.
    cache_dir=$(mktemp -d)
    if UV_CACHE_DIR="$cache_dir" uv run --script "$SCRIPT_DIR/tests/test_hist_analyze.py" >/dev/null 2>&1; then
        ok "hist-analyze behavior tests pass"
        info "default uv cache was not usable; a temporary cache was used"
    else
        fail "hist-analyze behavior tests failed"
        UV_CACHE_DIR="$cache_dir" uv run --script "$SCRIPT_DIR/tests/test_hist_analyze.py"
    fi
    rm -rf "$cache_dir"
fi

if command -v atuin &>/dev/null; then
    [ "$(ATUIN_CONFIG_DIR="$SCRIPT_DIR/atuin" atuin config get auto_sync --resolved 2>/dev/null)" = "false" ] \
        && ok "Atuin automatic sync disabled" \
        || fail "Atuin automatic sync must be disabled"
fi

# --------------------------------------------------------
section "FZF config"
# --------------------------------------------------------
if command -v fzf &>/dev/null; then
    [ -n "$FZF_DEFAULT_OPTS" ] && ok "FZF_DEFAULT_OPTS set" || fail "FZF_DEFAULT_OPTS not set (source .commonrc first)"
    if command -v fd &>/dev/null; then
        [ -n "$FZF_DEFAULT_COMMAND" ] && ok "FZF_DEFAULT_COMMAND set (using fd)" || fail "FZF_DEFAULT_COMMAND not set"
    fi
else
    info "fzf not installed, skipping FZF config checks"
fi

# --------------------------------------------------------
section "Zoxide"
# --------------------------------------------------------
if command -v zoxide &>/dev/null; then
    ok "zoxide installed: $(zoxide --version)"
else
    fail "zoxide not installed"
fi

# --------------------------------------------------------
section "Node / nvm"
# --------------------------------------------------------
if [ ! -d "$HOME/.nvm" ]; then
    info "nvm not installed, skipping nvm checks"
elif ! command -v zsh &>/dev/null; then
    info "zsh not available, skipping nvm checks"
else
    # nvm.sh defines many helper functions (nvm_echo, nvm_has, ...), so their
    # presence means nvm.sh was sourced at startup. NVM_BIN is NOT a reliable
    # signal: nvm's own "use default" step is skipped when npm_config_prefix is
    # set, so NVM_BIN stays unset even when nvm.sh did load.
    nvm_probe=$(env -u NVM_BIN -u NVM_PATH -u NVM_INC zsh -i -c \
        'printf "\n__NVM__%s|%s\n" "$(command -v nvm_echo)" "$(command -v nvm)"' 2>/dev/null |
        sed -n 's/^__NVM__//p')
    nvm_sourced=${nvm_probe%%|*}
    nvm_startup_cmd=${nvm_probe##*|}

    if [ -z "$nvm_startup_cmd" ]; then
        fail "nvm command not available in a new shell"
    elif [ -n "$nvm_sourced" ]; then
        fail "nvm.sh is sourced at startup; it costs ~0.35s per shell — expected lazy loading"
    else
        ok "nvm is lazy-loaded (nvm.sh not sourced at startup)"
    fi

    # Assert on the version: this proves the stub loaded the real nvm on demand.
    nvm_version=$(env -u NVM_BIN -u NVM_PATH -u NVM_INC zsh -i -c \
        'printf "\n__NVM__%s\n" "$(nvm --version 2>/dev/null)"' 2>/dev/null |
        sed -n 's/^__NVM__//p')
    case "$nvm_version" in
        [0-9]*.[0-9]*.[0-9]*) ok "nvm loads and works on first use (v$nvm_version)" ;;
        *) fail "nvm did not load when invoked (got '${nvm_version:-}')" ;;
    esac

    # nvm's default version must win over any other node on PATH (Homebrew ships
    # node/npm/npx too, and .tools orders its PATH prepends so that nvm is last).
    nvm_node=$(env -u NVM_BIN -u NVM_PATH -u NVM_INC zsh -i -c \
        'printf "\n__NVM__%s\n" "$(command -v node)"' 2>/dev/null |
        sed -n 's/^__NVM__//p')
    case "$nvm_node" in
        "") info "node not on PATH, skipping precedence check" ;;
        "$HOME/.nvm/"*) ok "nvm's node wins on \$PATH ($nvm_node)" ;;
        *) fail "node resolves to $nvm_node; expected nvm's version to take priority" ;;
    esac
fi

# --------------------------------------------------------
section "Git config"
# --------------------------------------------------------
git_email=$(git config --global user.email 2>/dev/null)
git_name=$(git config --global user.name 2>/dev/null)
[ -n "$git_name" ]  && ok "git user.name: $git_name"  || fail "git user.name not set"
[ -n "$git_email" ] && ok "git user.email: $git_email" || fail "git user.email not set"

if command -v delta &>/dev/null; then
    pager=$(git config --global core.pager 2>/dev/null)
    [ "$pager" = "delta" ] && ok "git core.pager = delta" || info "git core.pager not set to delta"
else
    info "git-delta not installed, skipping delta check"
fi

# --------------------------------------------------------
section "zellij"
# --------------------------------------------------------
if command -v zellij &>/dev/null; then
    ok "zellij installed: $(zellij --version)"
    [ -L "$HOME/.config/zellij/config.kdl" ] && ok "~/.config/zellij/config.kdl symlinked" || fail "~/.config/zellij/config.kdl not symlinked"
    if zellij setup --check 2>&1 | grep -qi "well defined"; then
        ok "zellij config.kdl parses"
    else
        info "could not confirm zellij config.kdl parses"
    fi
else
    info "zellij not installed"
fi

# --------------------------------------------------------
section "WSL2-specific checks"
# --------------------------------------------------------
if $IS_WSL; then
    command -v wslview &>/dev/null && ok "wslview available (wslu)" || fail "wslview not found — install wslu: sudo apt install wslu"
    command -v clip.exe &>/dev/null && ok "clip.exe accessible" || info "clip.exe not in PATH (Windows interop may be disabled)"
else
    info "Not WSL2, skipping WSL2 checks"
fi

# --------------------------------------------------------
section "PATH hygiene"
# --------------------------------------------------------
# A fresh interactive shell, not this script's inherited $PATH: .commonrc
# deduplicates, but .zshrc/.bashrc add entries afterwards, so this catches
# regressions where those additions are no longer duplicate-guarded.
path_dupes_for() {
    local shell_name="$1"
    command -v "$shell_name" &>/dev/null || return 0
    "$shell_name" -i -c 'printf "\n__PATH__%s\n" "$PATH"' 2>/dev/null |
        sed -n 's/^__PATH__//p' | tr ':' '\n' | sort | uniq -d
}

for shell_name in zsh bash; do
    command -v "$shell_name" &>/dev/null || continue
    dupes=$(path_dupes_for "$shell_name")
    if [ -z "$dupes" ]; then
        ok "no duplicate \$PATH entries in $shell_name"
    else
        fail "duplicate \$PATH entries in $shell_name: $(printf '%s' "$dupes" | tr '\n' ' ')"
    fi
done

# --------------------------------------------------------
echo ""
echo "========================================"
echo -e "  Results: ${green}${PASS} passed${reset}, ${red}${FAIL} failed${reset}"
echo "========================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
