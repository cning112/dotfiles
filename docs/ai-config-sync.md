# AI tool config sync — design & spec

**Status:** agreed 2026-09-27. Phase 1 (repo content + engine) implemented on branch `omos/ai-config-sync`.
**Scope:** sync Claude Code, Codex, OpenCode, and dsh (DeepSeek Harness) config across macOS, WSL2, and native Windows via this public repo — per-device login, zero secrets committed, no new package manager.

---

## 1. Constraints this design must respect

Research findings (source-level, 2026-09):

| Fact | Consequence |
|---|---|
| Windows symlinks require Admin or Developer Mode; **junctions** (`mklink /J`) need no admin but are directories-only | Dirs → junctions on Windows; files → copy unless Dev Mode |
| Git checks committed symlinks out as plain text when `core.symlinks=false` (Windows default without Dev Mode) | **Never commit symlinks** |
| Atomic write (temp + rename) over a symlink replaces the link with a regular file; in-place writes preserve links | Link only files whose writer is in-place-safe |
| dsh `writeFileAtomic` explicitly replaces symlinked targets (upstream test asserts it) | dsh files: never file-symlinked; dir-level link OK (rename lands inside real dir) |
| Claude Code settings writer is symlink-hostile (temp+rename, one-hop resolution, plugin toggles rewrite it) | `claude/settings.json` is copy-managed (MIRROR) |
| Codex `config.toml` writer resolves the symlink chain and writes to the resolved target (POSIX verified in source) | `config.toml` is MIRROR on every platform; never symlink it or trust writes would land in the repo |
| OpenCode writes config in place (`fs.writeFileString`, no rename); plugin/skill installers stage + rename | File symlinks safe on POSIX; keep plugin dirs as a whole-dir junction on Windows |
| Codex `AGENTS.md` has **no** `@import` support (directory-walk concatenation only) | Live `AGENTS.md` is rendered from `AGENTS.base.md` + `claude/RTK.md` |
| All four tools put config under `%USERPROFILE%` on Windows (`\.claude`, `\.codex`, `\.config\opencode` + `\.local\share\opencode`, `\.dsh`) | Mapping is `$HOME`-relative on every platform |
| Claude Code on Windows: hooks run through Git Bash if present, else PowerShell; global instructions officially prefer `@AGENTS.md` import over symlinks | Keep hooks conditional; copies are acceptable |

## 2. Sync model: LINK / MIRROR / RENDER

- **LINK** — user-authored, read-mostly files/dirs. POSIX: symlink. Windows: junction (dirs); file symlink only if Developer Mode, else copy.
- **MIRROR** — files an app rewrites (atomically). Repo holds the canonical copy; `apply` writes repo→machine (with backup), `pull` captures machine→repo (with transforms below).
- **RENDER** — generated at apply time from repo sources (concatenation, conditional merges). Live files are not hand-edited.

Rules:
1. Link at directory level wherever possible.
2. Never commit symlinks.
3. Every overwrite is backed up to `<target>.backup.<timestamp>` (same contract as `link_path` in `setup.sh`).
4. **Machine-local state is preserved, not synced.** AI tools and the plugins that register into them write per-machine state — absolute `$HOME` paths, hook-trust hashes keyed by local path. That state is preserved on `apply`, dropped on `pull`, and ignored when comparing, so it can never become permanent drift and can never reach another machine. A table the repo already declares belongs to the repo and is never treated as machine-local, which keeps `apply` idempotent and stops `pull` deleting curated content.

   Detected as machine-local:
   - Claude `settings.json`: hook entries whose command names an absolute path outside the repo (e.g. `node "/Users/<you>/.hindsight/coding-agents/dist/claude-hook.js"`). Path-free hooks such as `rtk hook claude` are repo-managed.
   - Codex `config.toml`: `[projects.*]`, `[windows]`, `[hooks.state.*]` (local path + content hash), and any `[mcp_servers.*]` table whose body points outside the repo.

   A known consequence: on a machine where a plugin has registered, `apply` rewrites the file with those tables moved to the end. `status` therefore compares *live-with-machine-local-removed* against the repo rather than the whole file as text.

## 3. Mapping (source of truth for `scripts/ai-sync.mjs`)

| # | Repo source | Live target | Mode | Windows |
|---|---|---|---|---|
| 1 | `claude/CLAUDE.md`, `claude/RTK.md` | `~/.claude/CLAUDE.md`, `~/.claude/RTK.md` | LINK files | copy (file symlink if Dev Mode) |
| 2 | `claude/settings.json` | `~/.claude/settings.json` | MIRROR (+fragment merge, see §4) | same |
| 3 | `claude/settings.rtk-hook.json` | *(fragment; merged into #2 iff `rtk` on PATH)* | RENDER fragment | same |
| 4 | `claude/skills-enabled.txt` | `~/.claude/skills/<name>` links → `~/.agents/skills/<name>` | LINK per name (Claude Code does **not** read `~/.agents/skills` itself, so this allow-list is the only way a shared skill reaches it) | junction per name; fallback copy |
| 5 | `agents/skills/**` | `~/.agents/skills` | LINK dir | junction |
| 6 | `agents/.skill-lock.json` | `~/.agents/.skill-lock.json` | MIRROR | same |
| 7 | `codex/config.toml` | `~/.codex/config.toml` | MIRROR (preserve live `[projects.*]` + `[windows]`) | same |
| 8 | `codex/AGENTS.base.md` + `claude/RTK.md` | `~/.codex/AGENTS.md` | RENDER (concat) | same |
| 9 | `codex/skills/**` (exclude `.system` — machine-managed, recreated in place, git-ignored) | `~/.codex/skills` | LINK dir | junction |
| 10 | `codex/rules/**` (when non-empty) | `~/.codex/rules` | LINK dir | junction |
| 11 | `opencode/{opencode.jsonc, oh-my-opencode-slim.json, dcp.jsonc, tui.json, cli.json}` | `~/.config/opencode/<file>` | LINK files | copy (file symlink if Dev Mode) |
| 12 | `opencode/skills/**` | `~/.config/opencode/skills` | LINK dir (OpenCode's own curated set; the shared library reaches it separately via `skills.paths` — see §5) | junction |
| 13 | `dsh/settings.yaml`, `dsh/AGENTS.md` | `~/.dsh/<file>` | MIRROR | same |

`dsh/cordis.patch.yml` is deliberately **not** synced: the Hindsight plugin writes it between its own `HINDSIGHT_CODING_AGENTS_DSH_START/END` markers and it contains an absolute per-machine path, so the plugin recreates it locally instead.

**Never synced (machine-local / secret / runtime):**
- Claude: `.claude.json`, `.credentials.json`, `settings.local.json`, `projects/`, `plugins/`, `history.jsonl`, `shell-snapshots/`, `file-history/`, `backups/`, caches, `skills/synced/`
- Codex: `auth.json`, `sessions/`, `packages/`, `plugins/`, `cache/`, `*.sqlite*`, `history.jsonl`, `models_cache.json`, `.codex-global-state.json*`
- OpenCode: `service.json`, data dir (`auth.json`, `mcp-auth.json`, `opencode.db`, `log/`, `project/`), caches, `node_modules/`
- dsh: `.credentials.yaml`, `.env`, `profiles/`, `sessions/`, `storages/`, `cache/`, `attachments/`
- Root: `.env.local`

## 4. Engine contract — `scripts/ai-sync.mjs`

Node ≥ 22 or bun, zero dependencies, single file. Platform via `process.platform` (`darwin`/`linux`/`win32`).

`setup.sh` prefers `node` and falls back to `bun` (both produce identical output — the engine only uses `node:fs`, `node:path`, `node:os`, `node:url` and `node:child_process`). The fallback matters on a brand-new machine, where `node` is absent — it is not in `brew-apps.txt` and nvm has no version installed yet — while `bun` has just been installed. With neither on `PATH`, `setup.sh` reports the skip loudly instead of continuing silently.

```
node scripts/ai-sync.mjs <import|apply|pull|status> [--dry-run] [--json] [--verbose]
```

- **`import`** — seed repo from this machine: copy live files into repo paths, skipping anything in the never-sync list; convenient for onboarding new sync entries. Naive raw copies; hook/section extraction is manual (documented here) until automated.
- **`apply`** — repo → machine, idempotent:
  - LINK: if target is already a link/junction to the repo source → no-op. Else backup existing target, then symlink (POSIX) / `cmd /c mklink /J` (Windows dirs) / file-symlink-if-Dev-Mode-else-copy (Windows files).
  - MIRROR: backup existing live file, write repo content. For `codex/config.toml`, re-append the live machine-local sections (`[projects.*]`, `[windows]`) extracted before overwrite.
  - RENDER: build content (AGENTS.md = `AGENTS.base.md` + `\n` + `claude/RTK.md`; settings.json = repo JSON shallow-merged with `settings.rtk-hook.json` iff `rtk` resolves on PATH) and write with backup.
  - Skill links (#4): for each line in `skills-enabled.txt`, ensure `~/.claude/skills/<name>` is a link to `agents/skills/<name>`; never touch other entries (`synced/` etc.).
  - Failures are per-entry and reported; exit 1 if any entry failed.
- **`pull`** — machine → repo for MIRROR entries:
  - `claude/settings.json`: copy, then strip any `hooks.PreToolUse` entry whose command matches `/rtk hook claude/` (hook lives in the fragment).
  - `codex/config.toml`: copy minus `[projects.*]` tables and `[windows]` table (line-based section surgery; files are toml_edit-formatted and well-formed).
  - `agents/.skill-lock.json`, `dsh/*`: plain copy.
  - Prints a summary + `git diff --stat` hint. Exit 1 on error.
- **`status`** — verify, no writes:
  - Exit 0 = everything in sync; 1 = drift/mismatch/broken links; 2 = nothing applied yet on this machine (fresh machine — informational).
  - `--json` machine-readable `{state, entries:[{id, mode, ok, detail}]}` for `test.sh`.

Backup naming/format matches `link_path` in `setup.sh` (read it; use the same `<date +%Y%m%d%H%M%S>` style). All operations print one line per action. `--dry-run` prints planned actions, changes nothing.

## 5. Repo layout (new content)

```
agents/
  skills/                 # 44 tracked skill dirs — canonical shared library (LINK dir → ~/.agents/skills)
  .skill-lock.json        # skill manager lock (MIRROR)
claude/
  CLAUDE.md, RTK.md       # existing (LINK)
  settings.json           # MIRROR
  settings.rtk-hook.json  # fragment merged at apply iff rtk on PATH
  skills-enabled.txt      # names of the 13 shared skills linked into ~/.claude/skills
codex/
  config.toml             # MIRROR; [projects.*] / [windows] are machine-local and preserved
  AGENTS.base.md          # render source; live AGENTS.md = base + claude/RTK.md
  skills/                 # gh-address-comments, gh-fix-ci, pdf, playwright (.system excluded)
opencode/
  opencode.jsonc, oh-my-opencode-slim.json, dcp.jsonc, tui.json, cli.json
                          # opencode.jsonc sets skills.paths → {env:HOME}/.agents/skills
  skills/                 # 8 OpenCode-specific skills (a separate curated set)
dsh/
  settings.yaml, AGENTS.md      # MIRROR (copied at seed time when present)
                                # cordis.patch.yml is deliberately never synced: the Hindsight
                                # plugin recreates it locally, between its own markers
scripts/ai-sync.mjs
docs/ai-config-sync.md
env.example
.gitattributes
```

The 14 shared skill names (`claude/skills-enabled.txt`): adversarial-review, caveman, design-an-interface, diagnose, dotfiles-change, edit-article, obsidian-vault, request-refactor-plan, to-issues, to-prd, ubiquitous-language, write-a-skill, writing-great-skills, zoom-out.

### Skill discovery across agents (verified 2026-10-03)

The shared library reaches each agent by a **different mechanism**, so a new skill
is not uniformly visible. Verified against each tool on this machine rather than
inferred from docs:

| Agent | How it finds skills | New `agents/skills/<name>/` visible? |
|---|---|---|
| dsh | reads `~/.agents/skills` directly | yes, immediately — no `apply` needed |
| Codex | host root `~/.agents/skills` (evidence: its log lists `(file: ~/.agents/skills/<name>/SKILL.md)`) | yes, immediately — no `apply` needed |
| OpenCode | scans `~/.config/opencode/{skill,skills}` and `<project>/.opencode/{skill,skills}`, **plus** every path in `skills.paths` | yes — `opencode.jsonc` sets `skills.paths = ["{env:HOME}/.agents/skills"]` |
| Claude Code | only `~/.claude/skills/`, per name | **no** — add the name to `claude/skills-enabled.txt`, then `apply` |

Consequences worth remembering:

- Because `~/.agents/skills` is a **directory** LINK, dsh, Codex, and OpenCode see
  a new skill the moment it is written — there is no apply step to forget.
- Claude Code is the only agent needing the allow-list, and entry #4 is the entire
  mechanism; it never reads `~/.agents/skills` itself.
- `{env:HOME}` interpolation inside `skills.paths` is confirmed working: OpenCode
  resolved all 44 shared skills (up from its own 8) with no `~` expansion needed.
- `disable-model-invocation: true` removes a skill from the model-visible catalog
  (dsh hides all 22 such skills) while leaving it user-invocable via `/name`. Omit
  it for skills an agent should reach for on its own. OpenCode is the exception —
  it ignores the flag (see *Skill invocation across agents* below).
- Windows: junction-based `~/.agents/skills` discovery is still unverified for
  OpenCode's `skills.paths` (see the open items in §8).

### Skill invocation across agents (verified 2026-10-03)

Discovery answers whether an agent can *see* a skill; this answers how you
*reach* one, and the two are not the same question. Verified against each tool's
own binary rather than inferred from docs:

| Agent | `disable-model-invocation` honored? | How you invoke a skill |
|---|---|---|
| dsh | yes | the `/` menu — the only entry point for a user-only skill; matches an ordered subsequence of the name, prefix hits first |
| Claude Code | yes | `/name` |
| Codex | yes — the key is listed in its embedded skill-authoring guide, beside `user-invocable` and `argument-hint` | slash command, with `$ARGUMENTS` |
| OpenCode | **no** — the flag is ignored, not the skill | unverified; and the agent can reach the skill unprompted |

Consequences worth remembering:

- OpenCode parses `SKILL.md` frontmatter (its binary contains `SKILL.md`,
  `skills.paths` and `frontmatter`) but does not implement the flag. Because
  entry #12 points `skills.paths` at the whole library, all 22 user-only skills
  are **model-invocable** there — the agent can reach them unprompted.
- Evidence differs by row: dsh is read from its own bundle, Codex from the
  authoring guide embedded in its binary, OpenCode from the key's *absence* in a
  compiled binary. Absence is strong evidence for a literal frontmatter key, but
  it is not proof — re-probe after an OpenCode upgrade (see §8).

## 6. Secrets & per-device login

- No secret ever enters the repo; `env.example` lists key **names** only (`DEEPSEEK_API_KEY`, `MORPH_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`).
- POSIX: `~/.env.local` (already sourced by `.commonrc`); Windows: `[Environment]::SetEnvironmentVariable('NAME','…','User')`, then restart the shell.
- Each tool logs in per device (claude/codex/dsh interactive login; opencode provider auth in its data dir).

## 7. Windows bring-up

Prereqs: Git for Windows (recommended — supplies Claude Code's Bash tool and hook shell), Node ≥ 22 or bun, PowerShell 5.1+ (built-in). Developer Mode optional (only needed for file symlinks; junctions + copies cover the rest).

1. `git clone git@github.com:cning112/dotfiles.git && cd dotfiles`
2. `node scripts\ai-sync.mjs apply`
3. Per-tool install + login (see repo README).
4. `node scripts\ai-sync.mjs status` → expect exit 0.

Notes:
- Claude Code has no native sandbox on Windows (WSL2 if wanted); skills discovery with junctions is unverified — if broken, `apply` copies `~/.claude/skills/<name>` instead (flip a per-machine flag).
- OpenCode runs natively but WSL is its recommended path if native quirks bite (plugins/MCP).
- The `rtk` hook is merged only where `rtk` exists on PATH.
- Never `ln -s` from Git Bash (creates copies); the engine uses `mklink /J`.

## 8. Verification

- `test.sh` gains an "AI config sync" section: run `status --json` with whichever runtime is available (node, else bun); exit 2 → INFO (not applied yet), 1 → FAIL (drift), 0 → PASS. It also runs `tests/ai-sync.test.mjs` — via `node --test` or `bun test`, both of which accept the filename and fail correctly — which exercises the engine against a throwaway repo copy and a fake `$HOME` and asserts that plugin-registered hooks and machine-local Codex tables survive `apply`, never reach the repo on `pull`, and do not count as drift. It also checks the skill wiring: that `opencode.jsonc` declares `skills.paths` pointing at the shared library, and that every skill's frontmatter `name` matches its directory.
- Windows: manual checklist (status clean + per-tool smoke test).
- Empirical open items to confirm on real machines: (1) Claude settings writer vs symlink behavior on current version (could upgrade to LINK later); (2) junction-based skill discovery on Windows; (3) which OpenCode line is installed (v1 files vs v2 SQLite auth); (4) rtk availability on Windows; (5) whether OpenCode implements `disable-model-invocation` (2.0.22 does not — re-probe after upgrades).

## 9. Rollout

- **Phase 0** — housekeeping commits in main checkout (gstack section trim; in-flight shell edits).
- **Phase 1** — this branch: repo content, engine, docs, script integration.
- **Phase 2** — merge, then `apply` on macOS and WSL2, verify, iterate.
- **Phase 3** — Windows bring-up; resolve quirks.
- **Phase 4** — optionally promote more entries to dir-level links once writers are verified per machine.

## 10. Rejected alternatives

- **chezmoi / home-manager** — decent Windows story (copy mode), but replaces a working hand-rolled symlink scheme for the sake of four app folders.
- **WSL-only Windows support** — works today and stays supported, but all four tools now run natively; native is the goal, WSL the fallback.
