#!/bin/bash

# 定义当前脚本目录
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
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

# 安装必要的软件
install_software() {
    echo "Installing vim-plug for Vim..."
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    echo "Installing vim-plug for Neovim..."
    curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    # 安装 Vim
    if brew list --versions vim &> /dev/null 2>&1; then
        echo "Vim is already installed"
        INSTALLED_VIM_VERSION=$(brew list --versions vim | awk '{print $2}')
        LATEST_VIM_VERSION=$(brew info vim --json=v1 | jq -r '.[0].versions.stable')
        if [ "$INSTALLED_VIM_VERSION" != "$LATEST_VIM_VERSION" ]; then
            echo "Updating Vim to the latest version..."
            brew upgrade vim
        else
            echo "Vim is already the latest version ($INSTALLED_VIM_VERSION)"
        fi
    else
        echo "Installing the latest version of Vim..."
        brew install vim
    fi

    # 安装 Neovim
    if brew list --versions neovim &> /dev/null 2>&1; then
        echo "Neovim is already installed"
        INSTALLED_NVIM_VERSION=$(brew list --versions neovim | awk '{print $2}')
        LATEST_NVIM_VERSION=$(brew info neovim --json=v1 | jq -r '.[0].versions.stable')
        if [ "$INSTALLED_NVIM_VERSION" != "$LATEST_NVIM_VERSION" ]; then
            echo "Updating Neovim to the latest version..."
            brew upgrade neovim
        else
            echo "Neovim is already the latest version ($INSTALLED_NVIM_VERSION)"
        fi
    else
        echo "Installing the latest version of Neovim..."
        brew install neovim
    fi

    if [ -n "$ZSH_VERSION" ]; then
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            echo "Installing oh-my-zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
    fi

    if ! command -v zoxide &> /dev/null 2>&1; then
        echo "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi

    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh -o install.sh
        chmod +x install.sh
        if [ -n "$ZSH_VERSION" ]; then
            zsh install.sh
        elif [ -n "$BASH_VERSION" ]; then
            bash install.sh
        fi
        rm install.sh
    fi

    if ! command -v rustup &> /dev/null 2>&1; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    if [ ! -d "$HOME/miniconda3" ] || [ -z "$(ls -A $HOME/miniconda3)" ]; then
        echo "Installing Miniconda..."
        mkdir -p $HOME/miniconda3
        if [ "$OS_TYPE" = "Darwin" ]; then
            curl -o "$HOME/miniconda.sh" https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
        elif [ "$OS_TYPE" = "Linux" ]; then
            curl -o "$HOME/miniconda.sh" -sS https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        fi
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
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg "AWSCLIV2.pkg" -target /
            rm "AWSCLIV2.pkg"
        elif [ "$OS_TYPE" = "Linux" ]; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws
        fi
    else
        echo "AWS CLI is already installed."
    fi

    echo "Creating necessary directories..."
    mkdir -p "$HOME/.config/nvim"

    echo "Creating symbolic links..."
    ln -sf "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
    mkdir -p "$HOME/.config/nvim"
    ln -sf "$SCRIPT_DIR/.vimrc" "$HOME/.config/nvim/init.vim"
    ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    ln -sf "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
    ln -sf "$SCRIPT_DIR/.gitignore" "$HOME/.gitignore"
    ln -sf "$SCRIPT_DIR/.bash_profile" "$HOME/.bash_profile"
    ln -sf "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
    ln -sf "$SCRIPT_DIR/.commonrc" "$HOME/.commonrc"
    ln -sf "$SCRIPT_DIR/.common_vimrc" "$HOME/.common_vimrc"
    ln -sf "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
    ln -sf "$SCRIPT_DIR/.editorconfig" "$HOME/.editorconfig"
    ln -sf "$SCRIPT_DIR/.ideavimrc" "$HOME/.ideavimrc"
    ln -sf "$SCRIPT_DIR/.aliases" "$HOME/.aliases"
    ln -sf "$SCRIPT_DIR/.functions" "$HOME/.functions"
    ln -sf "$SCRIPT_DIR/.path" "$HOME/.path"

    echo "Installing Vim and Neovim plugins..."
    vim +PlugInstall +qall
    nvim +PlugInstall +qall

    echo "Sourcing shell configuration..."
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        source "$HOME/.bash_profile"
    fi
    
    echo "=================================================="
    echo "Dotfiles setup completed successfully."
    echo "Restrat your shell (bash or zsh) to apply the settings"
    echo "=================================================="
}

if [ "$OS_TYPE" = "Darwin" ]; then
    setup_brew
    setup_shells
    install_software
elif [ "$OS_TYPE" = "Linux" ]; then
    setup_brew
    setup_shells
    install_software
else
    echo "Unsupported operating system: $OS_TYPE"
    exit 1
fi
