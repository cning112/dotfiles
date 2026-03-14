# dotfiles

Shell configuration for macOS and WSL2 (Ubuntu). Managed via symlinks so changes in this repo take effect immediately.

## Installation

### macOS

```bash
# 1. Install Xcode CLI tools (if not already installed)
xcode-select --install

# 2. Clone this repo
git clone https://github.com/YOUR_USERNAME/dotfiles ~/dev/dotfiles
cd ~/dev/dotfiles

# 3. Run setup (installs Homebrew, shells, tools, creates symlinks)
./setup.sh

# 4. Verify
./test.sh
```

### WSL2 (Ubuntu)

```bash
# 1. Install Homebrew for Linux
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone this repo
git clone https://github.com/YOUR_USERNAME/dotfiles ~/dev/dotfiles
cd ~/dev/dotfiles

# 3. Run setup
./setup.sh

# 4. Install WSL2 clipboard utility
sudo apt install wslu

# 5. Verify
./test.sh
```

### Install / update brew apps

```bash
# Install all tools (auto-detects platform)
./install_brew_apps.sh

# Install specific list
./install_brew_apps.sh brew-apps-macos.txt
```

---

## File Structure

```
dotfiles/
├── .commonrc          # Shared config (sourced by both zsh and bash)
├── .zshrc             # Zsh-specific config
├── .bashrc            # Bash-specific config
├── .bash_profile      # Bash login shell
├── .aliases           # Command aliases
├── .functions         # Shell functions
├── .tools             # Tool initialisation (nvm, rust, conda, zoxide, direnv, mise…)
├── .gitconfig         # Git config with delta pager
├── .ripgreprc         # Ripgrep defaults
├── .tmux.conf         # Tmux config
├── starship.toml      # Starship prompt config
├── bat/config         # Bat config
├── brew-apps.txt      # Cross-platform CLI tools
├── brew-apps-macos.txt# macOS-only cask apps
├── setup.sh           # Full setup script
├── install_brew_apps.sh
└── test.sh            # Verify setup is working
```

---

## Tool Cheatsheet

### fzf — fuzzy finder

| Shortcut | Action |
|----------|--------|
| `Ctrl+T` | Fuzzy find files, paste into command line |
| `Ctrl+R` | Fuzzy search command history |
| `Alt+C`  | Fuzzy cd into a subdirectory |
| `Ctrl+/` | Toggle preview panel |
| `Shift+↑/↓` | Scroll preview panel |

Custom functions (defined in `.functions`):

| Command | Action |
|---------|--------|
| `fcd` | Fuzzy cd into any subdirectory |
| `fkill` | Fuzzy select and kill a process |
| `fenv` | Fuzzy search environment variables |
| `fshow` | Fuzzy browse git log with diff preview |

---

### zoxide — smart `cd`

```bash
z foo          # jump to most-visited directory matching "foo"
z foo bar      # match "foo" and "bar" in path
zi             # interactive jump with fzf
z -            # go back to previous directory
```

---

### tmux — terminal multiplexer

**Prefix key: `Ctrl+a`**

| Shortcut | Action |
|----------|--------|
| `prefix + \|` | Split pane vertically |
| `prefix + -` | Split pane horizontally |
| `prefix + h/j/k/l` | Navigate panes (vim-style) |
| `prefix + H/J/K/L` | Resize panes |
| `prefix + c` | New window (in current directory) |
| `prefix + < / >` | Swap window left/right |
| `prefix + r` | Reload tmux config |
| `prefix + [` | Enter copy mode |
| `prefix + z` | Zoom/unzoom current pane |
| `prefix + $` | Rename session |

**Copy mode (vi):**

| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `Ctrl+v` | Rectangle selection |
| `y` | Copy selection (to system clipboard) |
| `H / L` | Jump to start / end of line |

Mouse is enabled: click to focus, drag border to resize, scroll to scroll.

---

### bat — better `cat`

```bash
bat file.py          # view file with syntax highlighting
bat file1 file2      # view multiple files
bat --plain file     # no line numbers / decorations
bat --language=json  # force language
```

`cat` and `less` are aliased to `bat` automatically when installed.

---

### ripgrep (`rg`) — fast grep

```bash
rg pattern               # search in current directory
rg pattern src/          # search in specific directory
rg -t py pattern         # search only Python files
rg -l pattern            # show only matching filenames
rg -i pattern            # case-insensitive
rg -A 3 pattern          # 3 lines after each match
rg --no-ignore pattern   # ignore .gitignore / .ripgreprc
```

Configured in `.ripgreprc`: smart case, hidden files, ignores node_modules/dist/etc.

---

### git-delta — better git diffs

Automatically used by `git diff`, `git show`, `git log -p`. No extra commands needed.

| Key | Action |
|-----|--------|
| `n / N` | Jump to next / previous diff section |
| `q` | Quit |

```bash
git diff              # uses delta automatically
git show HEAD         # uses delta automatically
git log -p            # uses delta automatically
```

Git aliases (in `.gitconfig`):
```bash
git lg        # pretty graph log (all branches)
git adog      # compact graph log
git undo      # undo last commit, keep changes staged
git last      # show files changed in last commit
```

---

### starship — cross-platform prompt

The prompt shows automatically. What each element means:

```
~/dev/dotfiles  main [!+]  took 3s
❯
```

| Symbol | Meaning |
|--------|---------|
| `[!]` | Unstaged changes |
| `[+]` | Staged changes |
| `[?]` | Untracked files |
| `[⇡2]` | 2 commits ahead of remote |
| `[⇣1]` | 1 commit behind remote |
| `took 3s` | Command took longer than 2s |
| `✗ 1` | Previous command exited with code 1 |

Language versions (Node, Python, Rust, Go, Java) appear automatically when you're in a relevant project.

```bash
starship explain      # explain each module in current prompt
starship timings      # show how long each module took
starship config       # open starship.toml in editor
```

---

### direnv — per-directory environment

```bash
# Create an .envrc in your project
echo 'export DATABASE_URL=postgres://localhost/mydb' > .envrc
direnv allow          # approve the .envrc (required once per file change)
direnv deny           # revoke approval
direnv edit .         # safely edit .envrc (auto-approves on save)
direnv reload         # reload manually

# Common .envrc patterns:
# export FOO=bar
# source .env
# PATH_add bin
# layout node          # auto-activate Node version from .node-version
# layout python        # auto-activate virtualenv
```

---

### mise — polyglot version manager

Replaces nvm, pyenv, rbenv etc. with a single tool.

```bash
# Install a tool version
mise install node@lts
mise install python@3.12
mise install go@latest

# Set version for current project (creates .mise.toml)
mise use node@lts
mise use python@3.12

# Set global defaults
mise global node@lts
mise global python@3.12

# Show current active versions
mise current

# List installed versions
mise list

# Upgrade all tools
mise upgrade
```

---

### lazygit — TUI git client

```bash
lazygit    # or: lg (alias)
```

| Key | Action |
|-----|--------|
| `?` | Show help |
| `↑↓` / `j/k` | Navigate |
| `Space` | Stage / unstage file |
| `a` | Stage all |
| `c` | Commit |
| `C` | Commit with editor |
| `P` | Push |
| `p` | Pull |
| `b` | Branch menu |
| `d` | Diff |
| `z` | Undo last action |
| `q` | Quit |

---

### Shell functions (`.functions`)

| Function | Usage | Description |
|----------|-------|-------------|
| `mkcd` | `mkcd dirname` | Create directory and cd into it |
| `fcd` | `fcd` | Fuzzy cd (interactive) |
| `fkill` | `fkill` | Fuzzy process kill |
| `fenv` | `fenv` | Fuzzy search env vars |
| `fshow` | `fshow` | Fuzzy git log browser |
| `port` | `port 8080` | Show what's using a port |
| `extract` | `extract file.tar.gz` | Universal archive extractor |

---

## Updating

```bash
cd ~/dev/dotfiles
git pull
./test.sh    # verify everything still works
```
