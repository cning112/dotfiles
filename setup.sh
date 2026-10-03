#!/bin/bash

# 定义当前脚本目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
echo "Script directory: $SCRIPT_DIR"

# 检查操作系统类型
OS_TYPE=$(uname)
echo "Operating System: $OS_TYPE"

# 安装 Homebrew（如果尚未安装），并在 Linux 上添加 Linuxbrew 路径
setup_brew() {
    source "${SCRIPT_DIR}/setup_brew.sh"
}

# 安装 Bash 和 Zsh
setup_shells() {
    source "${SCRIPT_DIR}/setup_shells.sh"
}

# link_path <source> <target>
# Symlink a repo file or directory into $HOME. Anything already at <target> that
# is not already our symlink is moved aside first, so re-running setup.sh on a
# machine that already has real dotfiles cannot silently destroy them.
link_path() {
    local source="$1"
    local target="$2"
    local backup_path

    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            return 0
        fi
        rm -f "$target"
    elif [ -e "$target" ]; then
        backup_path="${target}.backup.$(date +%Y%m%d%H%M%S)"
        echo "Backing up existing $target to $backup_path"
        mv "$target" "$backup_path"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
}

# 安装必要的软件
install_software() {
    echo "Installing brew apps from brew-apps.txt..."
    bash "${SCRIPT_DIR}/install_brew_apps.sh"

    echo "Installing vim-plug for Vim..."
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    echo "Installing vim-plug for Neovim..."
    curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    if ! command -v zoxide &> /dev/null 2>&1; then
        echo "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi

    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing NVM..."
        curl -o install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh
        chmod +x install.sh
        bash install.sh
        rm install.sh
    fi

    if ! command -v rustup &> /dev/null 2>&1; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    if [ ! -d "$HOME/miniconda3" ] || [ -z "$(ls -A "$HOME/miniconda3")" ]; then
        echo "Installing Miniconda..."
        mkdir -p "$HOME/miniconda3"
        # Anaconda names the macOS builds "arm64" but the Linux builds "aarch64".
        ARCH=$(uname -m)
        if [ "$OS_TYPE" = "Darwin" ]; then
            [ "$ARCH" = "x86_64" ] || ARCH="arm64"
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-${ARCH}.sh"
        elif [ "$OS_TYPE" = "Linux" ]; then
            [ "$ARCH" = "x86_64" ] || ARCH="aarch64"
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh"
        fi
        curl -fLo "$HOME/miniconda.sh" "$MINICONDA_URL"
        bash "$HOME/miniconda.sh" -b -u -p "$HOME/miniconda3"
        if [ $? -ne 0 ]; then
            echo "Miniconda installation failed."
        else
            echo "Miniconda installation succeeded."
        fi
        rm "$HOME/miniconda.sh"
    else
        echo "Miniconda is already installed and not empty."
    fi

    # 安装 AWS CLI
    if ! command -v aws &> /dev/null 2>&1; then
        echo "Installing AWS CLI..."
        if [ "$OS_TYPE" = "Darwin" ]; then
            curl -fLo "AWSCLIV2.pkg" "https://awscli.amazonaws.com/AWSCLIV2.pkg"
            sudo installer -pkg "AWSCLIV2.pkg" -target /
            rm "AWSCLIV2.pkg"
        elif [ "$OS_TYPE" = "Linux" ]; then
            # Linux builds are published as x86_64 or aarch64.
            AWS_ARCH=$(uname -m)
            [ "$AWS_ARCH" = "x86_64" ] || AWS_ARCH="aarch64"
            curl -fLo "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws
        fi
    else
        echo "AWS CLI is already installed."
    fi

    echo "Creating necessary directories..."
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.config/bat"
    mkdir -p "$HOME/.config/ghostty"
    mkdir -p "$HOME/.config/zellij"
    mkdir -p "$HOME/.config/atuin"
    mkdir -p "$HOME/.config/git"
    mkdir -p "$HOME/.claude"
    # bun's global bin dir: `bun add -g` writes here, and .tools only puts it on
    # PATH once it exists, so create it up front to make that deterministic.
    mkdir -p "$HOME/.bun/bin"

    echo "Creating symbolic links..."
    # Neovim uses the LazyVim config in this repo. link_path backs up any
    # existing ~/.config/nvim so we do not end up with both init.lua and init.vim.
    link_path "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
    link_path "$SCRIPT_DIR/lazyvim" "$HOME/.config/nvim"
    link_path "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    link_path "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
    link_path "$SCRIPT_DIR/.bash_profile" "$HOME/.bash_profile"
    link_path "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
    link_path "$SCRIPT_DIR/.commonrc" "$HOME/.commonrc"
    link_path "$SCRIPT_DIR/.common_vimrc" "$HOME/.common_vimrc"
    link_path "$SCRIPT_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
    link_path "$SCRIPT_DIR/.editorconfig" "$HOME/.editorconfig"
    link_path "$SCRIPT_DIR/.ideavimrc" "$HOME/.ideavimrc"
    link_path "$SCRIPT_DIR/.aliases" "$HOME/.aliases"
    link_path "$SCRIPT_DIR/.functions" "$HOME/.functions"
    link_path "$SCRIPT_DIR/.tools" "$HOME/.tools"
    link_path "$SCRIPT_DIR/.ripgreprc" "$HOME/.ripgreprc"
    link_path "$SCRIPT_DIR/bat/config" "$HOME/.config/bat/config"
    link_path "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    link_path "$SCRIPT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    link_path "$SCRIPT_DIR/atuin/config.toml" "$HOME/.config/atuin/config.toml"
    # Global git ignore. Git reads this path by default; ~/.gitignore is NOT read
    # by git unless core.excludesFile points at it, so we link the real location.
    link_path "$SCRIPT_DIR/git/ignore" "$HOME/.config/git/ignore"
    link_path "$SCRIPT_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    link_path "$SCRIPT_DIR/claude/RTK.md" "$HOME/.claude/RTK.md"

    # Sync the Claude/Codex/OpenCode/dsh configs the shell setup above does not
    # cover. The engine is idempotent and backs up anything it replaces.
    #
    # Prefer node, fall back to bun. On a brand-new machine node is absent (it is
    # not in brew-apps.txt and nvm has no version installed yet) while bun has
    # just been installed above, so without the fallback a fresh laptop would
    # silently sync no AI configs at all.
    AI_SYNC_RUNNER=""
    if command -v node >/dev/null 2>&1; then
        AI_SYNC_RUNNER="node"
    elif command -v bun >/dev/null 2>&1; then
        AI_SYNC_RUNNER="bun"
    fi

    if [ -n "$AI_SYNC_RUNNER" ]; then
        echo "Syncing AI tool configs (with $AI_SYNC_RUNNER)..."
        "$AI_SYNC_RUNNER" "$SCRIPT_DIR/scripts/ai-sync.mjs" apply ||
            echo "  ai-sync apply reported issues (see above)"
    else
        echo "  Skipping AI config sync: neither node nor bun is on PATH."
        echo "  Install one, then run: bun $SCRIPT_DIR/scripts/ai-sync.mjs apply"
    fi

    if command -v atuin &>/dev/null && [ -s "$HOME/.zsh_history" ]; then
        echo "Existing zsh history detected. Import it once for useful analysis:"
        echo "  atuin import zsh"
    fi

    echo "Installing Vim and Neovim plugins..."
    vim +PlugInstall +qall
    nvim --headless "+Lazy! sync" +qa

    echo "=================================================="
    echo "Dotfiles setup completed successfully."
    echo "Restart your shell (bash or zsh) to apply the settings"
    echo "=================================================="
}


extra_macos_setup() {
    # turn off accent chars by holding a key
    defaults write -g ApplePressAndHoldEnabled -bool false
}


if [ "$OS_TYPE" = "Darwin" ]; then
    setup_brew
    setup_shells
    install_software
    extra_macos_setup
elif [ "$OS_TYPE" = "Linux" ]; then
    setup_brew
    setup_shells
    install_software
else
    echo "Unsupported operating system: $OS_TYPE"
    exit 1
fi

echo "Done. Run './test.sh' to verify the setup."
