# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Shell and tool configuration for macOS and WSL2 (Ubuntu). All dotfiles are managed via symlinks from `~/dev/dotfiles/` to `$HOME`, so edits here take effect immediately without re-running setup.

## Key commands

```bash
# Full setup (installs Homebrew, shells, tools, creates symlinks)
./setup.sh

# Verify the setup is working correctly
./test.sh

# Install/update Homebrew packages
./install_brew_apps.sh                  # installs brew-apps.txt (cross-platform)
./install_brew_apps.sh brew-apps-macos.txt  # macOS-only cask apps
```

`test.sh` checks symlinks, required CLI tools, shell config syntax, fzf/zoxide/git/tmux config, and WSL2-specific tools. Run it after any change to verify nothing is broken.

## Architecture

**Shell config loading order** (both zsh and bash source `.commonrc`):
1. `.commonrc` — OS detection (`$IS_MACOS`, `$IS_LINUX`, `$IS_WSL`), then sources `.tools`, `.aliases`, `.functions`; sets PATH, FZF env vars, RIPGREP_CONFIG_PATH
2. `.tools` — initialises nvm, rustup, conda, zoxide (`eval "$(zoxide init zsh)"`), direnv
3. `.aliases` — command aliases, bat/cat override, git shortcuts, platform-aware `o` alias
4. `.functions` — shell functions: `mkcd`, `fcd`, `fkill`, `fenv`, `fshow`, `port`, `extract`

**Symlink targets**: `setup.sh` creates symlinks for `.zshrc`, `.bashrc`, `.bash_profile`, `.commonrc`, `.aliases`, `.functions`, `.tools`, `.gitconfig`, `.gitignore`, `.vimrc`, `.ideavimrc`, `.tmux.conf`, `.editorconfig`, `.ripgreprc`, `bat/config`, `starship.toml`.

**`lazyvim/`** — LazyVim Neovim config (separate from the vim-plug `.vimrc`). Not symlinked by `setup.sh`; intended to be copied/linked to `~/.config/nvim/` manually.

## Platform detection

Scripts use `$IS_MACOS`, `$IS_LINUX`, `$IS_WSL` booleans (set in `.commonrc`) for platform-specific behaviour. Always use these rather than re-detecting `uname`.

## Tool conventions

- **fzf functions** (`fcd`, `fkill`, etc.) are preferred over keybindings — keybindings were removed as unreliable
- **bat** replaces `cat` and `less` via aliases when installed
- **zoxide** provides `z` and `zi`; `cd` is intentionally kept separate
- **git-delta** is installed as `delta` (Homebrew binary name); aliased as `git-delta`
- **ripgrep** is installed as `rg`; config in `.ripgreprc` (smart case, hidden files, ignores node_modules/dist)
