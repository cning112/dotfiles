---
name: dotfiles-change
description: Safely change the dotfiles repo at ~/dev/dotfiles — its symlink model, the test.sh gate, zsh/bash portability rules, and how to add a shared skill or a synced AI-tool config. Use when editing shell config or a dotfile, wiring a new AI agent config into scripts/ai-sync.mjs, adding a skill under agents/skills/, or verifying a change before committing.
---

# Changing the dotfiles repo

## The one fact that matters most

Every tracked file is **symlinked** from `~/dev/dotfiles/` into `$HOME`, so an edit
here is live immediately. There is no install or build step — which also means a
broken edit breaks your next shell. Verify before you commit.

## Quick start

```bash
./test.sh                        # the only automated gate (this repo has no CI)
node scripts/ai-sync.mjs status  # AI config sync: expect exit 0
git status                       # tree should be clean of stray files
```

## Making a change

1. Edit the file in the repo — never edit through the `$HOME` symlink.
2. If it affects shell loading (`.zshrc`, `.bashrc`, `.commonrc`, `.tools`,
   `.aliases`, `.functions`), test **both** shells and read the output:
   `zsh -i -c exit` and `bash -i -c exit`. Silence is the pass condition.
3. Run `./test.sh` and require **0 failed**.
4. Commit with a conventional message (`feat(scope): ...`, `fix(scope): ...`).

## Adding a shared skill

The library is `agents/skills/`, symlinked to `~/.agents/skills`. Discovery is
**not** uniform across agents — this matrix was verified against each tool, not
assumed from docs:

| Agent | Sees a new `agents/skills/<name>/`? | Extra step needed |
| --- | --- | --- |
| dsh | yes, instantly | none |
| Codex | yes, instantly | none |
| OpenCode | yes, via `skills.paths` | none (already wired) |
| Claude Code | no | add `<name>` to `claude/skills-enabled.txt`, then `node scripts/ai-sync.mjs apply` |

Because the library is reached through a **directory** link, dsh, Codex, and
OpenCode pick up a new skill with no `apply` at all. Claude Code is per-name and
allow-listed, so it always needs the extra step.

Two frontmatter rules:

- `name` must match the directory name.
- Omit `disable-model-invocation` to let agents auto-invoke the skill. Set it to
  `true` to keep the skill user-invocable only (`/name`); the agents that honour
  the flag then hide it from their own catalog entirely. OpenCode ignores it
  (`docs/ai-config-sync.md` §5), so "user-only" is not universal — a skill that
  acts on its own has to guard itself.

Skills named in `agents/.skill-lock.json` are **upstream-installed**. The lock stores each one's folder
hash as the manager's record of what it installed, so never edit one in place: a local edit drifts from
that record and is discarded at the next update. Record the problem and hand it to the user.

Then the rule that catches the most:

**Every imperative names its executor.** A skill is read by an agent, not a human
at a terminal. Before writing a command, name the agent that runs it and confirm
that agent can. Two blockers in this library came from skipping that step:

- An agent cannot invoke a `disable-model-invocation` skill **where that flag is
  honoured** — OpenCode ignores it (`docs/ai-config-sync.md` §5). To reuse another
  skill's method, have the agent read `~/.agents/skills/<other>/SKILL.md` and
  follow it, the way `harden` §6 reaches `polish`.
- An agent's shell has no terminal, and a command that reads its answers from
  stdin fails *silently* without one: `git add -p` hits EOF, stages nothing, and
  still exits 0. Piping the answers works but is brittle, so prefer a route that
  needs no input at all — and always `git commit -m`, never a bare `git commit`,
  which opens the configured editor and hangs.

## Portability rules

- Never hardcode `/Users/<name>` — use `$HOME`, and gate machine-specific tools
  behind `$IS_MACOS` / `$IS_LINUX` / `$IS_WSL` (set in `.commonrc`).
- Never re-detect the platform with `uname`; reuse those booleans.
- Functions must work in **both** zsh and bash: zsh arrays are 1-based and bash
  0-based; bash reads zero-padded numbers (`date +%j`) as octal, so force `10#`.
  `type -t` prints nothing for a zsh function — use `command -v` instead.
- Anything added to `$PATH` *after* `.commonrc` needs the
  `case ":$PATH:" in *":$dir:"*) ;; *) ... ;; esac` guard, because the end-of-file
  dedupe has already run.
- Never commit symlinks or secrets.

## Adding a synced AI-tool config

See [SYNC-ENGINE.md](SYNC-ENGINE.md) for the LINK/MIRROR/RENDER modes, where the
mapping table lives, and the machine-local state policy.
