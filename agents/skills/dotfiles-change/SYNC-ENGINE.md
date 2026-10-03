# The AI config sync engine

`scripts/ai-sync.mjs` (Node ≥ 22 or bun, zero dependencies) keeps Claude Code,
Codex, OpenCode, and dsh configs in sync between this repo and `$HOME`. Full
design and the mapping table live in `docs/ai-config-sync.md`.

## Commands

```bash
node scripts/ai-sync.mjs apply          # repo -> machine (backs up before writing)
node scripts/ai-sync.mjs status --json  # verify only; exit 0 = in sync, 1 = drift, 2 = never applied
node scripts/ai-sync.mjs pull           # machine -> repo, for MIRROR entries only
node scripts/ai-sync.mjs apply --dry-run
```

## The three modes

Pick the mode from **what the writing application does to the file**, not from
what you wish it did:

| Mode | Use when | Example |
| --- | --- | --- |
| **LINK** | the app reads the file and does not rewrite it | `claude/CLAUDE.md`, `agents/skills/**`, `codex/skills/**` |
| **MIRROR** | the app rewrites the file, so a symlink would let machine-local state land in the repo | `codex/config.toml`, `claude/settings.json` |
| **RENDER** | the live file is generated from repo sources | `~/.codex/AGENTS.md` = `AGENTS.base.md` + `claude/RTK.md` |

The trap: an app that writes with *temp-file + rename*, or that resolves a
symlink chain and writes to the resolved target, will silently write **into the
repo** through a LINK. Those must be MIRROR. `docs/ai-config-sync.md` records
which tool does what, with the source evidence.

## Adding an entry

1. Add a mapping in `buildEntries()` in `scripts/ai-sync.mjs` (the `E.push(...)`
   block, roughly lines 470–525).
2. Document it in the mapping table in `docs/ai-config-sync.md`.
3. If the app writes machine-local state into the file, follow rule 4 of that
   doc: preserve on `apply`, drop on `pull`, ignore for drift. Otherwise a
   one-machine plugin path becomes permanent repo drift.
4. Add a test in `tests/ai-sync.test.mjs` (runs under both `node --test` and
   `bun test`; the filename must contain `.test.` for bun to collect it).

## Never sync

Secrets and machine-local runtime state: credentials, `auth.json`, sessions,
history, caches, `*.sqlite*`, `plugins/`, and anything holding an absolute
per-machine path. The never-sync lists are in section 5 of the design doc.

## Verifying

```bash
node scripts/ai-sync.mjs status --json   # expect in-sync, 0 drift
./test.sh                                # includes the sync section
node --test tests/ai-sync.test.mjs       # or: bun test tests/ai-sync.test.mjs
```

Always confirm `apply` is **idempotent** — a second `apply` must report no
writes. A rule that re-appends what it just stripped passes a single run and
fails forever after, so test the second run, not the first.
