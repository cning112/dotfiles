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

`test.sh` checks symlinks, required CLI tools, shell config syntax, fzf/zoxide/git/zellij config, PATH hygiene, the history-analyzer test suite, and WSL2-specific tools. Run it after any change to verify nothing is broken. There is no CI, so `test.sh` is the only automated gate.

## Architecture

**Shell config loading order** (both zsh and bash source `.commonrc`):
1. `.commonrc` — OS detection (`$IS_MACOS`, `$IS_LINUX`, `$IS_WSL`); sources `.env.local` if present, then `.tools`, `.aliases`, `.functions`; sets PATH, FZF env vars, RIPGREP_CONFIG_PATH, fzf key bindings, and finishes by deduplicating `$PATH` (keeping the first occurrence)
2. `.tools` — nvm, rustup, conda, Homebrew, zoxide, direnv, atuin, warpify. nvm is **lazy** (a `nvm` stub loads `nvm.sh` on first use, because sourcing it eagerly costs ~0.35s of every shell start) but its default version *is* put on `PATH` eagerly, and the nvm block sits **after** the Homebrew block so that nvm's `node`/`npm`/`npx` win over Homebrew's.
3. `.aliases` — command aliases, bat/cat override, git shortcuts, platform-aware `o` alias
4. `.functions` — `mkcd`, `fkill`, `fenv`, `fcd`, `fshow`, `port`, `extract`, `y`, `frg`, `gco`, `fopen`, `fo`, `fstash`, `fssh`, `_cli_tip`, `hist-analyze`, `ccds`

**Symlink targets**: `setup.sh` creates symlinks for `.zshrc`, `.bashrc`, `.bash_profile`, `.commonrc`, `.aliases`, `.functions`, `.tools`, `.gitconfig`, `.vimrc`, `.ideavimrc`, `.editorconfig`, `.ripgreprc`, `bat/config`, `starship.toml`, `zellij/config.kdl`, `atuin/config.toml`, `ghostty/config`, `git/ignore` (→ `~/.config/git/ignore`), `claude/CLAUDE.md` and `claude/RTK.md` (→ `~/.claude/`), and `lazyvim/` (→ `~/.config/nvim`). All linking goes through the `link_path` helper, which moves any pre-existing real file to `<target>.backup.<timestamp>` instead of overwriting it.

**`git/ignore`** is the global git ignore. Git does not read `~/.gitignore` unless `core.excludesFile` points at it, which is why this file is linked to `~/.config/git/ignore`.

**`lazyvim/`** — LazyVim Neovim config (separate from the vim-plug `.vimrc`), symlinked to `~/.config/nvim` by `setup.sh`.

**`scripts/hist_analyze.py`** — the `hist-analyze` command. PEP 723 inline deps, run via `uv run --script`; behaviour tests in `tests/test_hist_analyze.py`, executed by `test.sh`.

**`scripts/ai-sync.mjs`** — the AI-tool config sync engine (Node ≥ 22, zero deps) for Claude Code, Codex, OpenCode, and dsh. It implements three modes: LINK (symlink/junction read-mostly files and dirs), MIRROR (repo ↔ machine copies for files the apps rewrite, e.g. `claude/settings.json`), and RENDER (generated files, e.g. `~/.codex/AGENTS.md`). Design, mapping table, and platform caveats live in `docs/ai-config-sync.md`.

## Editing conventions

- Anything that adds to `$PATH` **after** `.commonrc` (e.g. in `.zshrc`) must be duplicate-guarded, because the dedupe has already run by then. Follow the `case ":$PATH:" in *":$dir:"*) ;; *) ... ;; esac` pattern.
- Never hardcode `/Users/<name>` paths; use `$HOME` and gate machine-specific tools behind `$IS_MACOS`/`$IS_LINUX`.
- Shell functions must work in both zsh and bash. Note that zsh arrays are 1-based and bash arrays 0-based, and bash reads zero-padded numbers (`date +%j`) as octal — use `10#` to force base 10. Also note zsh's `type -t` prints nothing for functions; use `command -v` to test whether a function exists.
- Keep heavy tool initialisation lazy (see the `nvm` stub in `.tools`). Measure with `zsh -i -c exit` before and after rather than guessing — the absolute number swings with ambient load and filesystem cache, so always A/B the two states back to back.
- npm exports its whole computed config as `npm_config_*` into every process it spawns, so a shell started via `npx`/`npm exec` inherits it. `.tools` unsets the prefix values because `npm_config_prefix` makes nvm refuse to run; other `npm_config_*` values are left alone because they may be deliberate (registry, auth).
- When adding a new synced AI-tool config (Claude Code, Codex, OpenCode, dsh), add a mapping entry in `scripts/ai-sync.mjs` and document it in `docs/ai-config-sync.md`. Never commit symlinks or secrets — symlinks check out as plain text on Windows without Developer Mode, and credentials/machine-local files stay out of the repo (see the never-sync list in the design doc).

## Platform detection

Scripts use `$IS_MACOS`, `$IS_LINUX`, `$IS_WSL` booleans (set in `.commonrc`) for platform-specific behaviour. Always use these rather than re-detecting `uname`.

## Tool conventions

- **fzf** functions (`fcd`, `fkill`, etc.) are the primary interface. Ctrl+R / Ctrl+T / Alt+C key bindings are also enabled via `eval "$(fzf --zsh)"` in `.commonrc`, which overrides the zsh defaults.
- **bat** replaces `cat` and `less` via aliases when installed
- **zoxide** provides `z` and `zi`; `cd` is intentionally kept separate
- **git-delta** is installed as `delta` (Homebrew binary name); aliased as `git-delta`
- **ripgrep** is installed as `rg`; config in `.ripgreprc` (smart case, hidden files, ignores node_modules/dist)
