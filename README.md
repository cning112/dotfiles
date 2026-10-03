# dotfiles

Shell configuration for macOS and WSL2 (Ubuntu). Managed via symlinks so changes in this repo take effect immediately.

## What's included

**Shell & Prompt**
- Zsh and Bash configuration with [Starship](https://starship.rs/) cross-platform prompt
- Git integration, command aliases, shell functions

**Development Tools**
- **Package managers**: Homebrew (system), uv (Python), npm/nvm (Node.js), bun (JavaScript/TypeScript)
- **Version managers**: rustup (Rust), nvm (Node.js), Miniconda (Python)
- **Productivity**: fzf (fuzzy finder), zoxide (smart cd), zellij (terminal multiplexer), lazygit (git UI)
- **CLI enhancement**: bat (syntax highlight), ripgrep (fast search), git-delta (better diffs)
- **Configuration**: direnv (per-directory env vars), Starship (prompt), Zellij (sessions)
- **Editors**: Vim for portable `.vimrc` settings, LazyVim for Neovim

**Cross-platform**
- Unified setup for macOS and WSL2 with platform detection
- Consistent experience: same tools, configs, and aliases on both

## Installation

### macOS

```bash
# 1. Install Xcode CLI tools (if not already installed)
xcode-select --install

# 2. Clone this repo
git clone https://github.com/cning112/dotfiles ~/dev/dotfiles
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
git clone https://github.com/cning112/dotfiles ~/dev/dotfiles
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

## AI tool configs (Claude Code · Codex · OpenCode · dsh)

Claude Code, Codex, OpenCode, and dsh (DeepSeek Harness) configs sync across machines from this repo via `scripts/ai-sync.mjs`. The engine **links** read-mostly files and directories, **mirrors** files the apps rewrite, and **renders** generated files such as `~/.codex/AGENTS.md`. The full mapping, modes, and platform caveats live in [`docs/ai-config-sync.md`](docs/ai-config-sync.md).

```bash
node scripts/ai-sync.mjs apply    # repo → this machine (backs up anything it replaces)
node scripts/ai-sync.mjs pull     # machine → repo (mirrored files only)
node scripts/ai-sync.mjs status   # verify sync state (no writes)
```

`./setup.sh` runs `apply` for you, with `node` if present and otherwise `bun` — either runtime works (the engine is verified to produce identical output on both), so a fresh machine needs only one of them. If neither is on `PATH`, setup says so and skips the sync instead of continuing silently.

**Secrets policy:** no secrets are ever committed — each tool logs in per device. Copy `env.example` to `~/.env.local` on macOS/WSL2 (already sourced by `.commonrc`); on Windows set the same names as user environment variables (`[Environment]::SetEnvironmentVariable('NAME','…','User')`, then restart the shell).

### Native Windows quickstart

Prereqs: [Git for Windows](https://git-scm.com/download/win) (also supplies Claude Code's Bash tool/hook shell) and Node ≥ 22 or bun.

```powershell
git clone https://github.com/cning112/dotfiles; cd dotfiles
node scripts\ai-sync.mjs apply   # link/junction/mirror configs into %USERPROFILE%
# then install and log in to each tool (claude/codex/opencode/dsh)
node scripts\ai-sync.mjs status  # expect exit 0
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
├── .tools             # Tool init (nvm [lazy, wins over brew's node], rust, conda, homebrew, bun, zoxide, direnv, atuin)
├── .gitconfig         # Git config with delta pager
├── .vimrc             # Portable Vim config shared with Vim/IdeaVim-style editors
├── .common_vimrc      # Shared Vim options sourced by .vimrc and .ideavimrc
├── .ideavimrc         # IDE Vim-mode config
├── .ripgreprc         # Ripgrep defaults
├── lazyvim/           # Neovim (LazyVim) config, symlinked to ~/.config/nvim
├── zellij/config.kdl  # Zellij config
├── ghostty/config     # Ghostty terminal config
├── starship.toml      # Starship prompt config
├── bat/config         # Bat config
├── atuin/config.toml  # Local-only Atuin history configuration
├── git/ignore         # Global git ignore, symlinked to ~/.config/git/ignore
├── claude/            # Global Claude Code instructions (CLAUDE.md, RTK.md)
├── agents/            # Shared agent skills library (skills/, .skill-lock.json)
├── codex/             # Codex config (config.toml, AGENTS.base.md, skills/)
├── opencode/          # OpenCode config (jsonc/json files, skills/)
├── dsh/               # DeepSeek Harness config (settings.yaml, AGENTS.md)
├── docs/              # Design docs (ai-config-sync.md)
├── env.example        # Example env var names (copy to ~/.env.local; no secrets)
├── brew-apps.txt      # Cross-platform CLI tools
├── brew-apps-macos.txt# macOS-only cask apps
├── setup.sh           # Full setup script
├── install_brew_apps.sh
├── scripts/ai-sync.mjs # AI-tool config sync engine (apply/pull/status)
├── scripts/hist_analyze.py # Isolated command-history analyzer
├── tests/test_hist_analyze.py # Analyzer behavior tests
└── test.sh            # Verify setup is working
```

---

## Tool Cheatsheet

### fzf — fuzzy finder

Use fzf via explicit function calls (more reliable than keybindings):

| Command | Action |
|---------|--------|
| `fcd` | Fuzzy cd into any subdirectory |
| `fkill` | Fuzzy select and kill a process |
| `fenv` | Fuzzy search environment variables |
| `fshow` | Fuzzy browse git log with diff preview |

Fzf is configured for fast file searching (uses `fd`, previews with `bat` if available) and can be piped to manually.

---

### zoxide — smart `cd`

```bash
z foo          # jump to most-visited directory matching "foo"
z foo bar      # match "foo" and "bar" in path
zi             # interactive jump with fzf
z -            # go back to previous directory
```

### Command-history analysis

Atuin stores detailed local history so `hist-analyze` can identify repeated
workflows, failures, slow commands, and parameterized function candidates.
Automatic sync is disabled in `atuin/config.toml`.

Import existing zsh history once after setup:

```bash
atuin import zsh
```

Analyze the last 30 days, or provide another window:

```bash
hist-analyze
hist-analyze 7
```

Recommendations are evidence-gated. The analyzer warns when Atuin has too few
records, normalizes aliases and command prefixes, and redacts common secret
arguments before displaying function candidates. It runs in an isolated
environment through `uv`; it never installs into the global Python environment.

The modern replacements it may suggest (`sd`, `xh`, `doggo`) are included in
`brew-apps.txt`, so `./install_brew_apps.sh` makes the suggestions actionable.

---

### zellij — terminal multiplexer

Zellij uses a built-in UI — no prefix key needed. The default keybindings are shown in the status bar at the bottom.

| Shortcut | Action |
|----------|--------|
| `Ctrl+p` then `n` | New pane |
| `Ctrl+p` then `d` | Down split |
| `Ctrl+p` then `r` | Right split |
| `Ctrl+p` then `x` | Close pane |
| `Ctrl+t` then `n` | New tab |
| `Ctrl+t` then `x` | Close tab |
| `Alt+←/→/↑/↓` | Move focus between panes |
| `Ctrl+s` then `s` | Enter scroll mode |
| `Ctrl+q` | Quit zellij |

Mouse is enabled: click to focus, scroll to scroll.

---

### Vim / Neovim

This repo uses a split editor model:

- `vim` uses [`.vimrc`](.vimrc) for a small, portable setup
- IntelliJ / IdeaVim uses [`.ideavimrc`](.ideavimrc)
- `nvim` uses [`lazyvim/`](lazyvim/), symlinked to `~/.config/nvim`

This avoids Neovim config conflicts and keeps `.vimrc` easy to reuse across IDEs.

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

### Version Management Strategy

Use language-specific, official version managers for clarity and control:

**Python:** `uv` (modern, integrated)
```bash
uv venv                   # create virtual environment
uv python pin 3.12        # pin version in project
uv add numpy pandas       # install packages
uv run script.py          # run script
```

**Node.js:** `nvm` (standard, familiar)
```bash
nvm install lts/*(latest LTS)
nvm use <version>         # set per-project
nvm alias default lts/*   # set global default
```

**Rust:** `rustup` (official, reliable)
```bash
rustup update
rustup toolchain install nightly
rustup default stable     # set default channel
```

Each tool is optimized for its ecosystem. No "magic" version switching.

---

### bun — JavaScript runtime & package manager

Bun ships via `brew-apps.txt` as a fast complement to `node`/`nvm` (not a
replacement), and repo tooling already relies on it — e.g. the `bun:test` suite
in `opencode/skills/codemap`.

| Command | Action |
|---------|--------|
| `bun run file.ts` | Run a TypeScript/JavaScript file directly |
| `bun x <cli>` | Run a package binary, installing it if needed (like `npx`) |
| `bun install` | Install dependencies from `package.json` |
| `bun add <pkg>` | Add a dependency (`-d` for a dev dependency) |
| `bun test` | Run `*.test.ts` files with the built-in test runner |

Globally installed CLIs (`bun add -g <pkg>`) land in `~/.bun/bin`, which `.tools`
puts on `$PATH` — Homebrew only installs bun's own binary, so that directory
would otherwise be missing. Bun itself is Homebrew-managed: upgrade it with
`brew upgrade bun` rather than `bun upgrade`.

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
| `frg` | `frg term` | Ripgrep contents, preview matches, open at the match in nvim |
| `fo` | `fo` | Fuzzy open a file by name in nvim |
| `fopen` | `fopen [dir]` | Fuzzy open a file with the OS default app |
| `fstash` | `fstash` | Browse git stashes and pop the selected one |
| `fssh` | `fssh` | Fuzzy pick a host from `~/.ssh/config` and connect |
| `gco` | `gco` | Fuzzy git branch checkout |
| `y` | `y` | Yazi file manager; cd to the last directory on exit |
| `port` | `port 8080` | Show what's using a port |
| `extract` | `extract file.tar.gz` | Universal archive extractor |
| `hist-analyze` | `hist-analyze [days]` | Evidence-backed workflow suggestions from Atuin history |
| `ccds` | `ccds` | Run Claude Code against the DeepSeek endpoint |
| `_cli_tip` | (automatic) | One rotating CLI practice tip per day at shell startup |

---

## Updating

```bash
cd ~/dev/dotfiles
git pull
./test.sh    # verify everything still works
```
