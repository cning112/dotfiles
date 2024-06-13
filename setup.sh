#! /bin/zsh

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
echo "The dotfiles directory is: $SCRIPT_DIR"

#################################################################
# Setup vim/neovim/ideavim

# Install vim-plug for Vim
curl -fLo $HOME/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install vim-plug for Neovim
curl -fLo $HOME/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Create necessary directories
mkdir -p $HOME/.config/nvim

# Create symbolic links for the configuration files
ln -sf "$SCRIPT_DIR/.common_vimrc" ~/.common_vimrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.vimrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.config/nvim/init.vim
ln -sf "$SCRIPT_DIR/.ideavimrc" ~/.ideavimrc

# Install vim plugins
vim +PlugInstall +qall
nvim +PlugInstall +qall

#################################################################
# Install oh-my-zsh
if [ -n "$ZSH_VERSION" ]; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
fi

# 安装 Miniconda（如果未安装）
if [ ! -d "$HOME/miniconda3" ]; then
    curl -o $HOME/miniconda.sh -sS https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash $HOME/miniconda.sh -b -p $HOME/miniconda3
    rm $HOME/miniconda.sh
fi

# 安装 NVM（如果未安装）
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
fi

# 安装 warpify（如果未安装）
if ! command -v warpify &> /dev/null; then
    curl -sS https://raw.githubusercontent.com/warpify/warpify/main/install.sh | bash
fi

# 安装 zoxide（如果未安装）
if ! command -v zoxide &> /dev/null; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# 安装 Rust（如果未安装）
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

#################################################################
# Create symbolic links for other configuration files
ln -sf "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
ln -sf "$SCRIPT_DIR/.gitignore" "$HOME/.gitignore"
ln -sf "$SCRIPT_DIR/.bash_profile" "$HOME/.bash_profile"
ln -sf "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
ln -sf "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$SCRIPT_DIR/.editorconfig" "$HOME/.editorconfig"
ln -sf "$SCRIPT_DIR/.ideavimrc" "$HOME/.ideavimrc"
ln -sf "$SCRIPT_DIR/.aliases" "$HOME/.aliases"
ln -sf "$SCRIPT_DIR/.functions" "$HOME/.functions"
ln -sf "$SCRIPT_DIR/.path" "$HOME/.path"
ln -sf "$SCRIPT_DIR/.commonrc" "$HOME/.commonrc"

#################################################################
# 检测当前运行的 shell 并重新加载相应的配置文件
if [ -n "$ZSH_VERSION" ]; then
    source $HOME/.zshrc
elif [ -n "$BASH_VERSION" ]; then
    source $HOME/.bash_profile
fi

#################################################################
echo "Setup completed successfully."
