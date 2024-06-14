#!/bin/bash

# 定义当前脚本目录
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
echo "Script directory: $SCRIPT_DIR"

# 检查操作系统类型
OS_TYPE=$(uname)
echo "Operating System: $OS_TYPE"

# 安装 Homebrew（如果尚未安装），并在 Linux 上添加 Linuxbrew 路径
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # 确保 Homebrew 路径被添加到 PATH
        if [ "$OS_TYPE" = "Darwin" ]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ "$OS_TYPE" = "Linux" ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi

    if [ "$OS_TYPE" = "Linux" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        test -d ~/.linuxbrew && eval $(~/.linuxbrew/bin/brew shellenv)
        test -d /home/linuxbrew/.linuxbrew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
    fi
}

# 安装 Bash 和 Zsh
install_bash_zsh() {
    echo "Installing jq..."
    brew install jq

    # 获取 Homebrew 的安装路径
    HOMEBREW_PREFIX=$(brew --prefix)

    if brew list --versions bash &> /dev/null; then
        echo "Bash is already installed"
        INSTALLED_BASH_VERSION=$(brew list --versions bash | awk '{print $2}')
        LATEST_BASH_VERSION=$(brew info bash --json=v1 | jq -r '.[0].versions.stable')
        if [ "$INSTALLED_BASH_VERSION" != "$LATEST_BASH_VERSION" ]; then
            echo "Updating Bash to the latest version..."
            brew upgrade bash
        else
            echo "Bash is already the latest version ($INSTALLED_BASH_VERSION)"
        fi
    else
        echo "Installing the latest version of Bash..."
        brew install bash
    fi

    if brew list --versions zsh &> /dev/null; then
        echo "Zsh is already installed"
        INSTALLED_ZSH_VERSION=$(brew list --versions zsh | awk '{print $2}')
        LATEST_ZSH_VERSION=$(brew info zsh --json=v1 | jq -r '.[0].versions.stable')
        if [ "$INSTALLED_ZSH_VERSION" != "$LATEST_ZSH_VERSION" ]; then
            echo "Updating Zsh to the latest version..."
            brew upgrade zsh
        else
            echo "Zsh is already the latest version ($INSTALLED_ZSH_VERSION)"
        fi
    else
        echo "Installing the latest version of Zsh..."
        brew install zsh
    fi

    # 添加 Bash 到 /etc/shells
    if ! grep -Fxq "$HOMEBREW_PREFIX/bin/bash" /etc/shells; then
        echo "Adding $HOMEBREW_PREFIX/bin/bash to /etc/shells..."
        sudo bash -c "echo $HOMEBREW_PREFIX/bin/bash >> /etc/shells"
    fi

    # 添加 Zsh 到 /etc/shells
    if ! grep -Fxq "$HOMEBREW_PREFIX/bin/zsh" /etc/shells; then
        echo "Adding $HOMEBREW_PREFIX/bin/zsh to /etc/shells..."
        sudo bash -c "echo $HOMEBREW_PREFIX/bin/zsh >> /etc/shells"
    fi

    # 更改默认 shell 为 Homebrew 安装的 Zsh
    if [ "$SHELL" != "$HOMEBREW_PREFIX/bin/zsh" ]; then
        echo "Changing the default shell to $HOMEBREW_PREFIX/bin/zsh..."
        chsh -s "$HOMEBREW_PREFIX/bin/zsh"
    else
        echo "Default shell is already $HOMEBREW_PREFIX/bin/zsh"
    fi
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
    if brew list --versions vim &> /dev/null; then
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
    if brew list --versions neovim &> /dev/null; then
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

    if ! command -v zoxide &> /dev/null; then
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

    if ! command -v rustup &> /dev/null; then
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

    echo "Creating necessary directories..."
    mkdir -p "$HOME/.config/nvim"

    echo "Creating symbolic links..."
    ln -sf "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
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
    install_homebrew
    install_bash_zsh
    install_software
elif [ "$OS_TYPE" = "Linux" ]; then
    install_homebrew
    install_bash_zsh
    install_software
else
    echo "Unsupported operating system: $OS_TYPE"
    exit 1
fi
