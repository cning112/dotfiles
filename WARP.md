# WARP.md

Guidance for WARP (warp.dev) when working in this repository.

**`CLAUDE.md` is the source of truth for this repo's architecture.** This file
covers only what is WARP-specific; if the two disagree, trust `CLAUDE.md` and
fix this one.

## Overview

Dotfiles for macOS and WSL2, managed as symlinks from `~/dev/dotfiles/` into
`$HOME`, so edits here take effect immediately without re-running setup.

There is no oh-my-zsh and no framework: `.zshrc` and `.bashrc` both source
`.commonrc`, which loads `.tools`, `.aliases` and `.functions`.

## Key commands

```bash
./setup.sh                                  # full setup: Homebrew, shells, tools, symlinks
./test.sh                                   # verify the setup (the only automated gate)
./install_brew_apps.sh                      # install brew-apps.txt (+ macOS casks on Darwin)
./install_brew_apps.sh brew-apps-macos.txt  # macOS-only cask apps
```

## Architecture

Shell config loading order (zsh and bash share `.commonrc`):

1. `.commonrc` — OS detection (`$IS_MACOS`, `$IS_LINUX`, `$IS_WSL`), sources
   `.env.local` / `.tools` / `.aliases` / `.functions`, sets PATH, FZF env,
   `RIPGREP_CONFIG_PATH`, then deduplicates `$PATH`
2. `.tools` — nvm, rustup, conda, Homebrew, zoxide, direnv, atuin, warpify
3. `.aliases` — aliases, `bat` overriding `cat`/`less`, git shortcuts
4. `.functions` — fzf helpers (`fcd`, `fkill`, `fenv`, `fshow`, `frg`, `fopen`,
   `fo`, `fstash`, `fssh`, `gco`), `mkcd`, `port`, `extract`, `y`,
   `hist-analyze`, `ccds`

Symlinks are created by the `link_path` helper in `setup.sh`, which moves any
pre-existing real file to `<target>.backup.<timestamp>` rather than overwriting
it. See `CLAUDE.md` for the full target list.

## Editors

- `vim` → `.vimrc`, which sources `.common_vimrc`. Plugins (vim-surround,
  vim-easymotion) are declared in `.vimrc` via vim-plug.
- IntelliJ / IdeaVim → `.ideavimrc`
- `nvim` → `lazyvim/`, symlinked to `~/.config/nvim`. **LazyVim manages its own
  plugins; do not run `nvim +PlugInstall`.**

## Environment management

Node via nvm, Python via uv and Miniconda (base auto-activation disabled), Rust
via rustup, JDK 21 and LLVM via Homebrew (macOS). Each tool is loaded
conditionally in `.tools` only when present.

## Multi-platform notes

- macOS: `/opt/homebrew`; Linux/WSL2: Linuxbrew at `/home/linuxbrew/.linuxbrew`
- Use `$IS_MACOS` / `$IS_LINUX` / `$IS_WSL` from `.commonrc` rather than
  re-detecting `uname`
- Never add absolute `/Users/<name>` paths; WSL2 support is a stated goal of
  this repo
