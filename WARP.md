# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

This is a dotfiles repository for macOS and Linux systems that manages shell configurations, development tools, and editor settings through symbolic linking. The setup is primarily designed for zsh with oh-my-zsh, Neovim/Vim configuration, and automated installation of development tools via Homebrew.

## Key Components

### Core Setup Scripts
- **`setup.sh`**: Main installation script that orchestrates the entire dotfiles setup
- **`setup_brew.sh`**: Homebrew installation and environment setup for both macOS and Linux
- **`setup_shells.sh`**: Shell installation (bash/zsh) with Homebrew and default shell configuration
- **`install_brew_apps.sh`**: Batch installer for applications listed in `brew-apps.txt`

### Configuration Architecture
The configuration follows a modular structure:
- **`.commonrc`**: Shared configuration loaded by both bash and zsh
- **`.zshrc`**: Zsh-specific configuration that sources `.commonrc`
- **`.bash_profile/.bashrc`**: Bash configurations that source `.commonrc`

Key modularity components sourced by `.commonrc`:
- **`.tools`**: Development tool initialization (NVM, Rust, Conda, Homebrew, warpify, zoxide)
- **`.aliases`**: Command aliases and shortcuts
- **`.functions`**: Custom shell functions

### Editor Configuration
- **`.vimrc`**: Vim configuration that sources `.common_vimrc`
- **`.common_vimrc`**: Shared Vim/Neovim configuration with plugins (vim-surround, vim-easymotion)
- **`.ideavimrc`**: IntelliJ Vim plugin configuration

## Common Commands

### Initial Setup
```bash
# Full system setup (installs Homebrew, shells, tools, and creates symlinks)
./setup.sh

# Install additional applications from brew-apps.txt
./install_brew_apps.sh brew-apps.txt
```

### Individual Component Setup
```bash
# Setup only Homebrew
source ./setup_brew.sh

# Setup only shells (bash and zsh)
source ./setup_shells.sh
```

### Configuration Management
```bash
# Create symbolic links for all dotfiles (run from dotfiles directory)
ln -sf "$PWD/.zshrc" "$HOME/.zshrc"
ln -sf "$PWD/.vimrc" "$HOME/.vimrc"
# (Full list is in setup.sh install_software function)

# Install Vim plugins
vim +PlugInstall +qall
nvim +PlugInstall +qall
```

### Development Tools
The setup automatically configures paths and initialization for:
- **Node.js**: NVM for version management
- **Python**: Miniconda with auto-activation disabled
- **Rust**: Rustup and Cargo environment
- **Java**: OpenJDK 21 via Homebrew
- **LLVM**: Custom toolchain for WebAssembly compilation
- **Git**: Custom aliases and credential management

## Architecture Notes

### Environment Setup Flow
1. OS detection (Darwin/Linux)
2. Homebrew installation and environment configuration
3. Shell installation and default shell setting
4. Development tool installation (vim-plug, NVM, Rust, Miniconda, AWS CLI)
5. Symbolic link creation for all configuration files
6. Plugin installation for editors

### Path Management
The `.commonrc` includes sophisticated PATH deduplication to handle multiple tool installations without conflicts. Tools are loaded conditionally based on their presence.

### Shell Integration
- **Zsh**: Uses oh-my-zsh with robbyrussell theme, git plugin, and fzf integration
- **Warp Integration**: Includes Warpify initialization and proper shell hooks
- **Navigation**: zoxide for smart directory jumping

### Multi-Platform Support
Scripts detect and handle differences between:
- **macOS**: Uses `/opt/homebrew` and system-specific installations
- **Linux**: Uses Linuxbrew with appropriate path configurations

## Application Management

The `brew-apps.txt` file contains curated applications split into categories:
- Terminal tools (nvim, fzf, tree, tldr)
- System utilities (raycast, keka, stats)
- Development tools (kubectl, helm, docker alternatives)
- Language tools (ruff, uv for Python)

Commented entries (prefixed with #) are optional applications.

## Editor Plugins and Configuration

### Vim/Neovim Setup
- Leader key mapped to comma (,)
- System clipboard integration
- EasyMotion for navigation
- Surround plugin for text manipulation
- 4-space indentation with smart indenting
- Desert colorscheme with syntax highlighting

### Git Configuration
- Custom log aliases (lg1, lg2, adog) for better commit visualization
- Git LFS support
- Credential manager integration
- Default branch set to 'main'