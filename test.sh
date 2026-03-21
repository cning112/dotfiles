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
    .gitconfig .gitignore
    .vimrc .ideavimrc .editorconfig .tmux.conf
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
TOOLS=(nvim fzf git zoxide)
for t in "${TOOLS[@]}"; do
    command -v "$t" &>/dev/null && ok "$t found ($(command -v $t))" || fail "$t not found"
done

# --------------------------------------------------------
section "Recommended CLI tools"
# --------------------------------------------------------
OPTIONAL=(fd bat tree lazygit tmux starship direnv)
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

# --------------------------------------------------------
section "Shell config syntax check"
# --------------------------------------------------------
for f in .commonrc .aliases .functions .tools; do
    if bash -n "$SCRIPT_DIR/$f" 2>/dev/null; then
        ok "$f syntax OK"
    else
        fail "$f has syntax errors:"
        bash -n "$SCRIPT_DIR/$f"
    fi
done

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
section "tmux"
# --------------------------------------------------------
if command -v tmux &>/dev/null; then
    ok "tmux installed: $(tmux -V)"
    [ -L "$HOME/.tmux.conf" ] && ok "~/.tmux.conf symlinked" || fail "~/.tmux.conf not symlinked"
    tmux -f "$HOME/.tmux.conf" new-session -d -s test_session 2>/dev/null \
        && tmux kill-session -t test_session 2>/dev/null \
        && ok ".tmux.conf loads without errors" \
        || fail ".tmux.conf has errors (check: tmux source ~/.tmux.conf)"
else
    info "tmux not installed"
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
echo ""
echo "========================================"
echo -e "  Results: ${green}${PASS} passed${reset}, ${red}${FAIL} failed${reset}"
echo "========================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
