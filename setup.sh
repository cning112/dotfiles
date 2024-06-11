#! /bin/zsh

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
echo "The dotfiles directory is: $SCRIPT_DIR"


#################################################################
# Setup vim/neovim/ideavim

# Install vim-plug for Vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install vim-plug for Neovim
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Create necessary directories
mkdir -p ~/.config/nvim

# Create symbolic links for the configuration files
ln -sf "$SCRIPT_DIR/.common_vimrc" ~/.common_vimrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.vimrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.config/nvim/init.vim
ln -sf "$SCRIPT_DIR/.ideavimrc" ~/.ideavimrc

# Install plugins
vim +PlugInstall +qall
nvim +PlugInstall +qall


#################################################################
# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi


#################################################################
# Create symbolic links for other configuration files
ln -sf "$SCRIPT_DIR/.bash_profile" ~/.bash_profile
ln -sf "$SCRIPT_DIR/.gitconfig" ~/.gitconfig
ln -sf "$SCRIPT_DIR/.gitignore" ~/.gitignore
ln -sf "$SCRIPT_DIR/.zshrc" ~/.zshrc
#ln -sf "$SCRIPT_DIR/.bashrc" ~/.bashrc
#ln -sf "$SCRIPT_DIR/.tmux.conf" ~/.tmux.conf
#ln -sf "$SCRIPT_DIR/.editorconfig" ~/.editorconfig
#ln -sf "$SCRIPT_DIR/.aliases" ~/.aliases
#ln -sf "$SCRIPT_DIR/.functions" ~/.functions
#ln -sf "$SCRIPT_DIR/.path" ~/.path


#################################################################
# Reload shell configuration
source ~/.zshrc
source ~/.bash_profile


#################################################################
echo "Setup completed successfully."

