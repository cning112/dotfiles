#!/usr/bin/env node
/**
 * ai-sync.mjs — sync AI tool configs (Claude Code, Codex, OpenCode, dsh)
 * between this repo and $HOME.
 *
 * Engine contract + mapping table: docs/ai-config-sync.md (§3, §4).
 *
 *   node scripts/ai-sync.mjs <import|apply|pull|status> [--dry-run] [--json] [--verbose]
 *
 * Zero dependencies, Node >= 22, ESM single file.
 * Repo root is derived from this file's location (scripts/..); targets are
 * relative to os.homedir().
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const HOME = os.homedir();
const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const IS_WIN = process.platform === 'win32';

const OPENCODE_FILES = ['opencode.jsonc', 'oh-my-opencode-slim.json', 'dcp.jsonc', 'tui.json', 'cli.json'];
// cordis.patch.yml is deliberately excluded: the Hindsight plugin writes it
// between its own HINDSIGHT_CODING_AGENTS_DSH_START/END markers and it contains
// an absolute per-machine path, so syncing it would spread plugin state and
// break on every other machine. The plugin recreates it locally.
const DSH_FILES = ['settings.yaml', 'AGENTS.md'];

const p = (...parts) => path.join(...parts);
const claudePath = (name) => p(REPO, 'claude', name);

// ---------------------------------------------------------------------------
// Small filesystem helpers
// ---------------------------------------------------------------------------

function exists(target) {
  try {
    fs.lstatSync(target);
    return true;
  } catch {
    return false;
  }
}

function isSymlink(target) {
  try {
    return fs.lstatSync(target).isSymbolicLink();
  } catch {
    return false;
  }
}

function realpath(target) {
  try {
    return fs.realpathSync(target);
  } catch {
    return null;
  }
}

function readFileOrNull(target) {
  try {
    return fs.readFileSync(target, 'utf8');
  } catch {
    return null;
  }
}

function readlinkOrNull(target) {
  try {
    return fs.readlinkSync(target);
  } catch {
    return null;
  }
}

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function dirHasEntries(dir) {
  try {
    return fs.readdirSync(dir).length > 0;
  } catch {
    return false;
  }
}

// Same timestamp style as link_path in setup.sh: date +%Y%m%d%H%M%S.
function timestamp() {
  const d = new Date();
  const z = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${z(d.getMonth() + 1)}${z(d.getDate())}${z(
    d.getHours()
  )}${z(d.getMinutes())}${z(d.getSeconds())}`;
}

function backupPathFor(target) {
  return `${target}.backup.${timestamp()}`;
}

function which(cmd) {
  const tool = IS_WIN ? 'where' : 'which';
  try {
    const r = spawnSync(tool, [cmd], { encoding: 'utf8' });
    return r.status === 0 && String(r.stdout || '').trim() !== '';
  } catch {
    return false;
  }
}

// Links a --dry-run apply intends to create, so later entries in the same run
// resolve through them (e.g. ~/.claude/skills/<name> -> ~/.agents/skills/<name>
// once ~/.agents/skills is itself planned to point at the repo).
const plannedLinks = new Map();

// Remap a path through a planned link, including anything nested beneath a
// planned directory link (e.g. ~/.agents/skills/<name>).
function remapPlanned(cur) {
  for (const [from, to] of plannedLinks) {
    if (cur === from) return path.resolve(to);
    if (cur.startsWith(from + path.sep)) return path.resolve(to + cur.slice(from.length));
  }
  return null;
}

function effectiveRealpath(target) {
  if (plannedLinks.size === 0) return realpath(target);
  let cur = path.resolve(target);
  const seen = new Set();
  for (let i = 0; i < 64; i++) {
    const remapped = remapPlanned(cur);
    if (remapped !== null) {
      if (seen.has(remapped)) return null;
      seen.add(remapped);
      cur = remapped;
      continue;
    }
    if (!isSymlink(cur)) return realpath(cur);
    const raw = readlinkOrNull(cur);
    if (raw === null) return null;
    const next = path.resolve(path.dirname(cur), raw);
    if (seen.has(next)) return null;
    seen.add(next);
    cur = next;
  }
  return realpath(target);
}

// A target is "our link" if it resolves (through any symlink/junction chain)
// to the same real path as the repo source. Accepts both absolute and the
// relative ~/.agents/skills-style links the machine already uses.
function isLinkTo(target, source) {
  if (!isSymlink(target)) return false;
  const a = effectiveRealpath(target);
  const b = effectiveRealpath(source);
  return a !== null && b !== null && a === b;
}

function deepEqual(a, b) {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (a && b && typeof a === 'object') {
    if (Array.isArray(a) !== Array.isArray(b)) return false;
    if (Array.isArray(a)) {
      if (a.length !== b.length) return false;
      return a.every((v, i) => deepEqual(v, b[i]));
    }
    const ka = Object.keys(a);
    const kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    return ka.every((k) => Object.prototype.hasOwnProperty.call(b, k) && deepEqual(a[k], b[k]));
  }
  return false;
}

function contentsEqual(entry, actual, expected) {
  if (actual === null || expected === null) return false;
  if (entry.compare === 'json') {
    try {
      return deepEqual(JSON.parse(actual), JSON.parse(expected));
    } catch {
      return false;
    }
  }
  return actual === expected;
}

// ---------------------------------------------------------------------------
// toml / JSON transforms
// ---------------------------------------------------------------------------

// Machine-local Codex tables that must survive a Windows MIRROR overwrite.
// Split TOML into blocks: each table header plus the lines that follow it. The
// preamble before any header is a block with a null header.
function tomlBlocks(text) {
  const blocks = [];
  let current = { header: null, lines: [] };
  for (const line of String(text).split(/\r?\n/)) {
    if (/^\s*\[/.test(line)) {
      blocks.push(current);
      current = { header: line.trim(), lines: [line] };
    } else {
      current.lines.push(line);
    }
  }
  blocks.push(current);
  return blocks;
}

const blockText = (b) => b.lines.join('\n');

// Tables this machine owns and the repo must never carry:
//   - [projects.*]        keyed by absolute checkout path
//   - [windows]           machine-local Codex state
//   - [hooks.state.*]     hook trust, keyed by local path + content hash
//   - [mcp_servers.*]     plugin-registered, when it points outside the repo
//
// `repoText` is the repo's own copy: a table the repo already declares belongs to
// the repo, so it is never treated as machine-local. That keeps apply idempotent
// (no duplicate append) and stops pull deleting curated tables.
function machineLocalTomlMatcher(repoText) {
  const owned = new Set(
    tomlBlocks(repoText ?? '')
      .filter((b) => b.header !== null)
      .map((b) => b.header)
  );
  return (header, body) => {
    if (header === null || owned.has(header)) return false;
    if (/^\[\[?projects(\.|\]|$)/.test(header)) return true;
    if (/^\[\[?windows(\]|\.|$)/.test(header)) return true;
    if (/^\[\[?hooks\.state(\.|\]|$)/.test(header)) return true;
    if (/^\[\[?mcp_servers\./.test(header)) return commandReferencesForeignPath(body);
    return false;
  };
}

const normalizeToml = (text) => String(text).replace(/\r\n/g, '\n').replace(/\n+$/, '');

function extractTomlSections(text, match) {
  return tomlBlocks(text)
    .filter((b) => b.header !== null && match(b.header, blockText(b)))
    .map(blockText)
    .join('\n');
}

function stripTomlSections(text, match) {
  return tomlBlocks(text)
    .filter((b) => b.header === null || !match(b.header, blockText(b)))
    .map(blockText)
    .join('\n');
}

function renderCodexConfig(liveText, repoText) {
  const preserved =
    typeof liveText === 'string'
      ? extractTomlSections(liveText, machineLocalTomlMatcher(repoText))
      : '';
  let out = String(repoText).replace(/\n+$/, '') + '\n';
  if (preserved.trim() !== '') out += '\n' + preserved.replace(/\n+$/, '') + '\n';
  return out;
}

function hookCommands(entry) {
  const cmds = [];
  if (entry && typeof entry === 'object') {
    if (typeof entry.command === 'string') cmds.push(entry.command);
    if (Array.isArray(entry.hooks)) {
      for (const h of entry.hooks) {
        if (h && typeof h.command === 'string') cmds.push(h.command);
      }
    }
  }
  return cmds;
}

// True when a command string names an absolute path outside this repo. Plugins
// register themselves with absolute per-machine paths (e.g. Hindsight writes
//   node "/Users/<you>/.hindsight/coding-agents/dist/claude-hook.js"
// into every tool it supports), so those hook entries are machine-local.
// Repo/fragment-managed hooks such as `rtk hook claude` name no path at all and
// stay unaffected.
function commandReferencesForeignPath(command) {
  const found = String(command).match(/(?:[A-Za-z]:[\\/]|\/)[^\s"']+/g) || [];
  return found.some((raw) => {
    const abs = path.resolve(raw.replace(/\\/g, '/'));
    return abs !== REPO && !abs.startsWith(REPO + path.sep);
  });
}

function hookEntryIsMachineLocal(entry) {
  return hookCommands(entry).some(commandReferencesForeignPath);
}

function hookEntryHasRtk(entry) {
  return hookCommands(entry).some((c) => /rtk hook claude/.test(c));
}

// Machine -> repo: drop the rtk hook, which lives in the render fragment.
function stripRtkHooks(jsonText) {
  let obj;
  try {
    obj = JSON.parse(jsonText);
  } catch {
    return null;
  }
  if (obj && obj.hooks && Array.isArray(obj.hooks.PreToolUse)) {
    obj.hooks.PreToolUse = obj.hooks.PreToolUse.filter((e) => !hookEntryHasRtk(e));
    if (obj.hooks.PreToolUse.length === 0) delete obj.hooks.PreToolUse;
    if (Object.keys(obj.hooks).length === 0) delete obj.hooks;
  }
  return JSON.stringify(obj, null, 2) + '\n';
}

// Machine -> repo: drop hooks this machine owns. Committing them would apply
// absolute /Users/<you>/.hindsight/... paths on every other machine, where they
// do not exist.
function stripMachineLocalHooks(jsonText) {
  let obj;
  try {
    obj = JSON.parse(jsonText);
  } catch {
    return null;
  }
  if (obj && isPlainObject(obj.hooks)) {
    for (const [event, arr] of Object.entries(obj.hooks)) {
      if (!Array.isArray(arr)) continue;
      const kept = arr.filter((e) => !hookEntryIsMachineLocal(e));
      if (kept.length > 0) obj.hooks[event] = kept;
      else delete obj.hooks[event];
    }
    if (Object.keys(obj.hooks).length === 0) delete obj.hooks;
  }
  return JSON.stringify(obj, null, 2) + '\n';
}

// Repo -> machine: keep hook entries that a plugin registered locally, so an
// apply cannot delete an integration the repo knows nothing about (and so status
// does not report permanent drift for them).
function preserveMachineLocalHooks(rendered, live) {
  const liveHooks = live && live.hooks;
  if (!isPlainObject(liveHooks)) return rendered;
  const out = { ...rendered };
  const outHooks = isPlainObject(out.hooks) ? { ...out.hooks } : {};
  const key = (e) => JSON.stringify(e);
  for (const [event, arr] of Object.entries(liveHooks)) {
    if (!Array.isArray(arr)) continue;
    const existing = Array.isArray(outHooks[event]) ? outHooks[event] : [];
    const seen = new Set(existing.map(key));
    const extras = arr.filter((e) => hookEntryIsMachineLocal(e) && !seen.has(key(e)));
    if (extras.length > 0) outHooks[event] = [...existing, ...extras];
  }
  if (Object.keys(outHooks).length > 0) out.hooks = outHooks;
  return out;
}

// Shallow merge, with one safety exception: when both sides define a `hooks`
// object, merge its keys and concatenate same-named arrays instead of dropping
// the repo's non-rtk hooks. Everything else is plain fragment-wins.
function mergeSettings(base, fragment) {
  const out = { ...base };
  for (const [k, v] of Object.entries(fragment)) {
    if (k === 'hooks' && isPlainObject(out[k]) && isPlainObject(v)) {
      out[k] = { ...out[k] };
      for (const [hk, hv] of Object.entries(v)) {
        if (Array.isArray(out[k][hk]) && Array.isArray(hv)) out[k][hk] = [...out[k][hk], ...hv];
        else out[k][hk] = hv;
      }
    } else {
      out[k] = v;
    }
  }
  return out;
}

function isPlainObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

// ---------------------------------------------------------------------------
// Render builders
// ---------------------------------------------------------------------------

function buildClaudeSettings() {
  const basePath = claudePath('settings.json');
  if (!exists(basePath)) return null;
  let base;
  try {
    base = JSON.parse(fs.readFileSync(basePath, 'utf8'));
  } catch {
    return null;
  }
  let merged = base;
  const fragPath = claudePath('settings.rtk-hook.json');
  if (which('rtk') && exists(fragPath)) {
    try {
      merged = mergeSettings(base, JSON.parse(fs.readFileSync(fragPath, 'utf8')));
    } catch {
      /* fragment unreadable/invalid: fall through to the plain repo copy */
    }
  }
  // Carry over hooks a plugin registered on this machine. The repo does not own
  // them; dropping them here would break the integration on every apply and make
  // status report drift that can never be resolved.
  const liveText = readFileOrNull(p(HOME, '.claude', 'settings.json'));
  if (liveText !== null) {
    try {
      merged = preserveMachineLocalHooks(merged, JSON.parse(liveText));
    } catch {
      /* unreadable live settings: render without carrying hooks over */
    }
  }
  return JSON.stringify(merged, null, 2) + '\n';
}

function buildCodexAgents() {
  const basePath = p(REPO, 'codex', 'AGENTS.base.md');
  if (!exists(basePath)) return null;
  const rtkPath = claudePath('RTK.md');
  const base = fs.readFileSync(basePath, 'utf8');
  const rtk = exists(rtkPath) ? fs.readFileSync(rtkPath, 'utf8') : '';
  let out = base.replace(/\n+$/, '') + '\n';
  if (rtk !== '') out += '\n' + rtk.replace(/^\n+/, '');
  if (!out.endsWith('\n')) out += '\n';
  return out;
}

// ---------------------------------------------------------------------------
// Entry model
// ---------------------------------------------------------------------------

function linkFile(id, source, target) {
  return { id, mode: 'LINK', kind: 'linkFile', source, target, optional: true };
}

function linkDir(id, source, target, opts = {}) {
  return { id, mode: 'LINK', kind: 'linkDir', source, target, optional: true, ...opts };
}

function mirror(id, source, target, opts = {}) {
  return { id, mode: 'MIRROR', kind: 'mirror', source, target, optional: true, compare: 'text', ...opts };
}

function render(id, source, target, build, opts = {}) {
  return {
    id,
    mode: 'RENDER',
    kind: 'render',
    source,
    target,
    build,
    optional: true,
    compare: 'text',
    ...opts,
  };
}

function slug(name) {
  return name.replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();
}

function getEntries() {
  const E = [];

  // #1 claude global instructions (LINK files)
  E.push(linkFile('claude-claude-md', claudePath('CLAUDE.md'), p(HOME, '.claude', 'CLAUDE.md')));
  E.push(linkFile('claude-rtk-md', claudePath('RTK.md'), p(HOME, '.claude', 'RTK.md')));

  // #2/#3 settings.json (RENDER: repo JSON + rtk fragment iff rtk on PATH)
  E.push(
    render('claude-settings', claudePath('settings.json'), p(HOME, '.claude', 'settings.json'), buildClaudeSettings, {
      compare: 'json',
    })
  );

  // #5 agents shared skill library (LINK dir). Applied before #4 so pre-existing
  // relative ~/.claude/skills/<name> -> ../../.agents/skills/<name> links resolve
  // through it and stay untouched instead of being needlessly re-created.
  E.push(linkDir('agents-skills', p(REPO, 'agents', 'skills'), p(HOME, '.agents', 'skills')));

  // #4 per-name skill links (never touches unlisted entries such as synced/)
  E.push({
    id: 'claude-skills',
    mode: 'LINK',
    kind: 'skills',
    target: p(HOME, '.claude', 'skills'),
    listFile: claudePath('skills-enabled.txt'),
    skillsBase: p(REPO, 'agents', 'skills'),
  });

  // #6 skill manager lock (MIRROR)
  E.push(mirror('agents-lock', p(REPO, 'agents', '.skill-lock.json'), p(HOME, '.agents', '.skill-lock.json')));

  // #7 codex config.toml: MIRROR on every platform. Codex's writer resolves a
  // symlink chain and writes atomically onto the resolved target, so a POSIX
  // symlink would let machine-local [projects.*] tables pollute the public
  // repo. Preserve-mirror keeps live a real file and re-appends those tables.
  const codexConfigSrc = p(REPO, 'codex', 'config.toml');
  const codexConfigTgt = p(HOME, '.codex', 'config.toml');
  E.push({ id: 'codex-config', mode: 'MIRROR', kind: 'codex-preserve', source: codexConfigSrc, target: codexConfigTgt });

  // #8 codex AGENTS.md (RENDER: AGENTS.base.md + claude/RTK.md)
  E.push(
    render('codex-agents', p(REPO, 'codex', 'AGENTS.base.md'), p(HOME, '.codex', 'AGENTS.md'), buildCodexAgents)
  );

  // #9 codex skills (LINK dir; `.system` is codex-managed and excluded on import)
  E.push(linkDir('codex-skills', p(REPO, 'codex', 'skills'), p(HOME, '.codex', 'skills')));

  // #10 codex rules (LINK dir, only when the repo source exists and is non-empty)
  E.push(linkDir('codex-rules', p(REPO, 'codex', 'rules'), p(HOME, '.codex', 'rules'), { nonEmpty: true }));

  // #11 opencode config files (LINK files)
  for (const f of OPENCODE_FILES) {
    E.push(linkFile(`opencode-${slug(f)}`, p(REPO, 'opencode', f), p(HOME, '.config', 'opencode', f)));
  }

  // #12 opencode skills (LINK dir)
  E.push(linkDir('opencode-skills', p(REPO, 'opencode', 'skills'), p(HOME, '.config', 'opencode', 'skills')));

  // #13 dsh files (MIRROR)
  for (const f of DSH_FILES) {
    E.push(mirror(`dsh-${slug(f)}`, p(REPO, 'dsh', f), p(HOME, '.dsh', f)));
  }

  return E;
}

function readEnabledNames(listFile) {
  const text = readFileOrNull(listFile);
  if (text === null) return null;
  return text
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s !== '' && !s.startsWith('#'));
}

// ---------------------------------------------------------------------------
// Reporter
// ---------------------------------------------------------------------------

function makeReporter(json, dryRun) {
  const actions = [];
  const format = (a) => {
    const tag = String(a.action).toUpperCase();
    const id = a.id ? `${a.id} ` : '';
    return `  ${tag} ${id}${a.detail || ''}`.replace(/\s+$/, '');
  };
  return {
    dryRun,
    json,
    actions,
    action(a) {
      actions.push(a);
      if (!json) console.log(format(a));
    },
    note(s) {
      if (!json) console.log(s);
      else if (s !== '') actions.push({ action: 'note', detail: s });
    },
    finish(obj) {
      if (json) console.log(JSON.stringify({ ...obj, actions }, null, 2));
    },
  };
}

// ---------------------------------------------------------------------------
// Linking primitives
// ---------------------------------------------------------------------------

function winJunction(source, target) {
  const r = spawnSync('cmd', ['/c', 'mklink', '/J', target, source], { encoding: 'utf8' });
  if (r.status !== 0) {
    throw new Error(`mklink /J failed: ${String(r.stderr || r.stdout || '').trim()}`);
  }
}

function copyDir(src, dest, excludes = []) {
  mkdirp(dest);
  for (const ent of fs.readdirSync(src, { withFileTypes: true })) {
    if (excludes.includes(ent.name)) continue;
    const s = p(src, ent.name);
    const d = p(dest, ent.name);
    if (ent.isSymbolicLink()) {
      const r = realpath(s);
      if (r && fs.statSync(r).isDirectory()) copyDir(r, d, excludes);
      else if (r) {
        mkdirp(path.dirname(d));
        fs.copyFileSync(r, d);
      }
    } else if (ent.isDirectory()) {
      copyDir(s, d, excludes);
    } else {
      mkdirp(path.dirname(d));
      fs.copyFileSync(s, d);
    }
  }
}

function createLink(kind, source, target, rep, id) {
  const isDir = kind === 'linkDir';
  if (!IS_WIN) {
    fs.symlinkSync(source, target, isDir ? 'dir' : 'file');
    return;
  }
  if (isDir) {
    try {
      winJunction(source, target);
    } catch (err) {
      rep.action({ action: 'warn', id, detail: `junction failed (${err.message}); copying directory instead` });
      copyDir(source, target);
    }
    return;
  }
  // Windows file: try a symlink (needs Developer Mode), else copy.
  try {
    fs.symlinkSync(source, target, 'file');
  } catch (err) {
    if (err.code === 'EPERM' || err.code === 'EACCES' || err.code === 'UNKNOWN') {
      rep.action({ action: 'warn', id, detail: `no file-symlink privilege; copying ${target} instead` });
      mkdirp(path.dirname(target));
      fs.copyFileSync(source, target);
    } else {
      throw err;
    }
  }
}

function backupTarget(target, rep, id) {
  if (!exists(target)) return null;
  const bp = backupPathFor(target);
  fs.renameSync(target, bp);
  rep.action({ action: 'backup', id, detail: bp });
  return bp;
}

// ---------------------------------------------------------------------------
// apply
// ---------------------------------------------------------------------------

function entryContent(entry) {
  if (entry.build) return entry.build();
  return readFileOrNull(entry.source);
}

function applyLink(entry, rep) {
  const { source, target } = entry;
  if (isLinkTo(target, source)) {
    rep.action({ action: 'noop', id: entry.id, detail: 'already linked' });
    return 'ok';
  }
  // Windows falls back to copying files when there is no symlink privilege;
  // treat an identical copy as in sync so apply stays idempotent.
  if (IS_WIN && entry.kind === 'linkFile' && exists(target) && !isSymlink(target)) {
    const current = readFileOrNull(target);
    const wanted = readFileOrNull(source);
    if (current !== null && current === wanted) {
      rep.action({ action: 'noop', id: entry.id, detail: 'copy matches (no symlink privilege)' });
      return 'ok';
    }
  }
  if (rep.dryRun) {
    if (exists(target)) rep.action({ action: 'backup', id: entry.id, detail: `would move to ${backupPathFor(target)}` });
    rep.action({ action: 'link', id: entry.id, detail: `${target} -> ${source}` });
    plannedLinks.set(path.resolve(target), path.resolve(source));
    return 'ok';
  }
  backupTarget(target, rep, entry.id);
  mkdirp(path.dirname(target));
  createLink(entry.kind, source, target, rep, entry.id);
  rep.action({ action: 'link', id: entry.id, detail: `${target} -> ${source}` });
  return 'ok';
}

function applyContent(entry, rep) {
  const expected = entryContent(entry);
  if (expected === null) {
    rep.action({ action: 'skip', id: entry.id, detail: 'no content (source not in repo)' });
    return 'skipped';
  }
  if (exists(entry.target) && !isSymlink(entry.target) && contentsEqual(entry, readFileOrNull(entry.target), expected)) {
    rep.action({ action: 'noop', id: entry.id, detail: 'up to date' });
    return 'ok';
  }
  if (rep.dryRun) {
    if (exists(entry.target)) rep.action({ action: 'backup', id: entry.id, detail: `would move to ${backupPathFor(entry.target)}` });
    rep.action({ action: 'write', id: entry.id, detail: `would write ${entry.target}` });
    return 'ok';
  }
  backupTarget(entry.target, rep, entry.id);
  mkdirp(path.dirname(entry.target));
  fs.writeFileSync(entry.target, expected);
  rep.action({ action: 'write', id: entry.id, detail: entry.target });
  return 'ok';
}

function applyCodexConfig(entry, rep) {
  const repoText = readFileOrNull(entry.source);
  if (repoText === null) {
    rep.action({ action: 'skip', id: entry.id, detail: 'source not in repo' });
    return 'skipped';
  }
  const liveText = exists(entry.target) ? readFileOrNull(entry.target) : null;
  const expected = renderCodexConfig(liveText, repoText);
  if (liveText !== null && !isSymlink(entry.target) && liveText === expected) {
    rep.action({ action: 'noop', id: entry.id, detail: 'up to date' });
    return 'ok';
  }
  if (rep.dryRun) {
    if (exists(entry.target)) rep.action({ action: 'backup', id: entry.id, detail: `would move to ${backupPathFor(entry.target)}` });
    rep.action({ action: 'write', id: entry.id, detail: `would write ${entry.target} (preserving [projects.*] + [windows])` });
    return 'ok';
  }
  backupTarget(entry.target, rep, entry.id);
  mkdirp(path.dirname(entry.target));
  fs.writeFileSync(entry.target, expected);
  rep.action({ action: 'write', id: entry.id, detail: `${entry.target} (preserved machine-local sections)` });
  return 'ok';
}

function applySkills(entry, rep) {
  const names = readEnabledNames(entry.listFile);
  if (names === null) {
    rep.action({ action: 'skip', id: entry.id, detail: 'skills-enabled.txt not in repo' });
    return 'skipped';
  }
  let handled = 0;
  for (const name of names) {
    const src = p(entry.skillsBase, name);
    const tgt = p(entry.target, name);
    const id = `${entry.id}:${name}`;
    if (!exists(src)) {
      rep.action({ action: 'skip', id, detail: 'not in repo' });
      continue;
    }
    if (isLinkTo(tgt, src)) {
      rep.action({ action: 'noop', id, detail: 'already linked' });
      handled++;
      continue;
    }
    if (rep.dryRun) {
      if (exists(tgt)) rep.action({ action: 'backup', id, detail: `would move to ${backupPathFor(tgt)}` });
      rep.action({ action: 'link', id, detail: `${tgt} -> ${src}` });
      plannedLinks.set(path.resolve(tgt), path.resolve(src));
      handled++;
      continue;
    }
    backupTarget(tgt, rep, id);
    mkdirp(entry.target);
    createLink('linkDir', src, tgt, rep, id);
    rep.action({ action: 'link', id, detail: `${tgt} -> ${src}` });
    handled++;
  }
  if (handled === 0) {
    rep.action({ action: 'skip', id: entry.id, detail: 'no skill sources in repo' });
    return 'skipped';
  }
  return 'ok';
}

function applyEntry(entry, rep) {
  if (entry.kind === 'skills') return applySkills(entry, rep);
  if (entry.optional && !exists(entry.source)) {
    rep.action({ action: 'skip', id: entry.id, detail: 'source not in repo' });
    return 'skipped';
  }
  if (entry.nonEmpty && !dirHasEntries(entry.source)) {
    rep.action({ action: 'skip', id: entry.id, detail: 'source is empty' });
    return 'skipped';
  }
  switch (entry.kind) {
    case 'linkFile':
    case 'linkDir':
      return applyLink(entry, rep);
    case 'mirror':
    case 'render':
      return applyContent(entry, rep);
    case 'codex-preserve':
      return applyCodexConfig(entry, rep);
    default:
      rep.action({ action: 'error', id: entry.id, detail: `unknown kind ${entry.kind}` });
      return 'error';
  }
}

function runApply(opts) {
  const rep = makeReporter(opts.json, opts.dryRun);
  if (!opts.json) console.log(opts.dryRun ? 'ai-sync apply (dry-run)' : 'ai-sync apply');
  const entries = getEntries();
  let failed = 0;
  let applied = 0;
  for (const entry of entries) {
    try {
      const result = applyEntry(entry, rep);
      if (result === 'error') failed++;
      if (result === 'ok') applied++;
    } catch (err) {
      failed++;
      rep.action({ action: 'error', id: entry.id, detail: err.message });
    }
  }
  rep.note('');
  if (failed > 0) rep.note(`ISSUES: ${failed} entries failed`);
  else rep.note(opts.dryRun ? `OK: ${applied} entries would be applied` : `OK: ${applied} entries processed`);
  rep.finish({ command: 'apply', dryRun: opts.dryRun, ok: failed === 0, failed });
  return failed === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------
// status
// ---------------------------------------------------------------------------

function statusLink(entry) {
  if (entry.optional && !exists(entry.source)) return { state: 'skipped', detail: 'source not in repo' };
  if (entry.nonEmpty && !dirHasEntries(entry.source)) return { state: 'skipped', detail: 'source is empty' };
  if (!exists(entry.target)) return { state: 'missing', detail: 'not applied' };
  if (isLinkTo(entry.target, entry.source)) return { state: 'ok', detail: 'linked' };
  if (isSymlink(entry.target)) return { state: 'drift', detail: `link points elsewhere: ${readlinkOrNull(entry.target)}` };
  if (IS_WIN && entry.kind === 'linkFile') {
    const current = readFileOrNull(entry.target);
    const wanted = readFileOrNull(entry.source);
    if (current !== null && current === wanted) return { state: 'ok', detail: 'copy matches (no symlink privilege)' };
  }
  return { state: 'drift', detail: 'not a link to the repo' };
}

function statusContent(entry) {
  if (entry.optional && !exists(entry.source)) return { state: 'skipped', detail: 'source not in repo' };
  const expected = entryContent(entry);
  if (expected === null) return { state: 'skipped', detail: 'no source content' };
  if (!exists(entry.target)) return { state: 'missing', detail: 'not applied' };
  if (isSymlink(entry.target)) return { state: 'drift', detail: 'is a symlink; expected a regular file' };
  const actual = readFileOrNull(entry.target);
  if (actual === null) return { state: 'error', detail: 'unreadable' };
  return contentsEqual(entry, actual, expected)
    ? { state: 'ok', detail: 'up to date' }
    : { state: 'drift', detail: 'content differs' };
}

function statusCodexConfig(entry) {
  const repoText = readFileOrNull(entry.source);
  if (repoText === null) return { state: 'skipped', detail: 'source not in repo' };
  if (!exists(entry.target)) return { state: 'missing', detail: 'not applied' };
  const liveText = readFileOrNull(entry.target);
  if (liveText === null) return { state: 'error', detail: 'unreadable' };
  // Compare live-with-machine-local-tables-removed against the repo. A plain text
  // comparison against repo+appended-sections never settles: apply moves those
  // tables to the end of the file, so the order would keep differing.
  const stripped = stripTomlSections(liveText, machineLocalTomlMatcher(repoText));
  if (!isSymlink(entry.target) && normalizeToml(stripped) === normalizeToml(repoText)) {
    return { state: 'ok', detail: 'up to date' };
  }
  return { state: 'drift', detail: 'content differs' };
}

function statusSkills(entry) {
  const names = readEnabledNames(entry.listFile);
  if (names === null) return { state: 'skipped', detail: 'skills-enabled.txt not in repo' };
  if (!exists(entry.skillsBase)) return { state: 'skipped', detail: 'agents/skills not in repo' };
  const present = names.filter((n) => exists(p(entry.skillsBase, n)));
  if (present.length === 0) return { state: 'skipped', detail: 'no skill sources in repo' };
  const bad = [];
  let okCount = 0;
  for (const name of present) {
    if (isLinkTo(p(entry.target, name), p(entry.skillsBase, name))) okCount++;
    else bad.push(name);
  }
  if (bad.length === 0) return { state: 'ok', detail: `${okCount}/${present.length} linked` };
  if (okCount === 0) return { state: 'missing', detail: `0/${present.length} linked` };
  return {
    state: 'drift',
    detail: `${okCount}/${present.length} linked; missing/wrong: ${bad.slice(0, 5).join(', ')}`,
  };
}

function statusEntry(entry) {
  try {
    switch (entry.kind) {
      case 'skills':
        return statusSkills(entry);
      case 'linkFile':
      case 'linkDir':
        return statusLink(entry);
      case 'mirror':
      case 'render':
        return statusContent(entry);
      case 'codex-preserve':
        return statusCodexConfig(entry);
      default:
        return { state: 'error', detail: `unknown kind ${entry.kind}` };
    }
  } catch (err) {
    return { state: 'error', detail: err.message };
  }
}

function runStatus(opts) {
  const results = getEntries().map((entry) => ({ entry, ...statusEntry(entry) }));
  const active = results.filter((r) => r.state !== 'skipped');
  const skipped = results.length - active.length;
  const okCount = active.filter((r) => r.state === 'ok').length;
  const drift = active.filter((r) => r.state === 'drift' || r.state === 'error').length;
  const missing = active.filter((r) => r.state === 'missing').length;
  // "Applied" evidence is a link the engine created. Mirrored/rendered files
  // often exist on a fresh machine before the engine ever ran, so their mere
  // presence must not mask a never-applied machine.
  const linkApplied = active.some(
    (r) => r.entry.mode === 'LINK' && (r.state === 'ok' || isSymlink(r.entry.target))
  );

  let state;
  let code;
  if (active.length > 0 && drift === 0 && missing === 0) {
    state = 'in-sync';
    code = 0;
  } else if (!linkApplied) {
    // Fresh machine: nothing the engine links is in place yet.
    state = 'not-applied';
    code = 2;
  } else {
    state = 'drift';
    code = 1;
  }

  if (opts.json) {
    const payload = {
      state,
      entries: active.map((r) => ({
        id: r.entry.id,
        mode: r.entry.mode,
        ok: r.state === 'ok',
        status: r.state,
        detail: r.detail,
      })),
      summary: { total: active.length, ok: okCount, missing, drift, skipped },
    };
    if (opts.verbose) {
      payload.skippedEntries = results
        .filter((r) => r.state === 'skipped')
        .map((r) => ({ id: r.entry.id, mode: r.entry.mode, detail: r.detail }));
    }
    console.log(JSON.stringify(payload, null, 2));
  } else {
    console.log(`ai-sync status on ${process.platform} (${HOME})`);
    for (const r of active) {
      const tag = r.state === 'ok' ? 'OK' : r.state === 'missing' ? 'MISSING' : r.state.toUpperCase();
      console.log(`  [${tag}] ${r.entry.id} (${r.entry.mode})${r.detail ? ` — ${r.detail}` : ''}`);
    }
    if (opts.verbose) {
      for (const r of results.filter((x) => x.state === 'skipped')) {
        console.log(`  [SKIP] ${r.entry.id} (${r.entry.mode})${r.detail ? ` — ${r.detail}` : ''}`);
      }
    }
    console.log('');
    console.log(
      `  ${state}: ${okCount}/${active.length} ok, ${missing} missing, ${drift} drift, ${skipped} skipped`
    );
  }
  return code;
}

// ---------------------------------------------------------------------------
// pull (machine -> repo, MIRROR entries only)
// ---------------------------------------------------------------------------

function runPull(opts) {
  const rep = makeReporter(opts.json, opts.dryRun);
  if (!opts.json) console.log(opts.dryRun ? 'ai-sync pull (dry-run)' : 'ai-sync pull');

  const pullers = [
    {
      id: 'claude-settings',
      from: p(HOME, '.claude', 'settings.json'),
      to: claudePath('settings.json'),
      transform: (t) => {
        const withoutRtk = stripRtkHooks(t);
        return withoutRtk === null ? null : stripMachineLocalHooks(withoutRtk);
      },
      note: 'stripped rtk + machine-local plugin hooks',
    },
    {
      id: 'codex-config',
      from: p(HOME, '.codex', 'config.toml'),
      to: p(REPO, 'codex', 'config.toml'),
      transform: (t) =>
        stripTomlSections(t, machineLocalTomlMatcher(readFileOrNull(p(REPO, 'codex', 'config.toml')) ?? '')),
      note: 'stripped machine-local tables',
    },
    {
      id: 'agents-lock',
      from: p(HOME, '.agents', '.skill-lock.json'),
      to: p(REPO, 'agents', '.skill-lock.json'),
      transform: null,
      note: '',
    },
  ];
  for (const f of DSH_FILES) {
    pullers.push({ id: `dsh-${slug(f)}`, from: p(HOME, '.dsh', f), to: p(REPO, 'dsh', f), transform: null, note: '' });
  }

  let failed = 0;
  for (const item of pullers) {
    if (!exists(item.from)) {
      rep.action({ action: 'skip', id: item.id, detail: 'live file not present' });
      continue;
    }
    try {
      const raw = fs.readFileSync(item.from, 'utf8');
      const content = item.transform ? item.transform(raw) : raw;
      if (content === null) {
        failed++;
        rep.action({ action: 'error', id: item.id, detail: 'could not parse live file' });
        continue;
      }
      const current = readFileOrNull(item.to);
      if (current === content) {
        rep.action({ action: 'noop', id: item.id, detail: 'repo already matches' });
        continue;
      }
      if (opts.dryRun) {
        rep.action({ action: 'copy', id: item.id, detail: `would copy ${item.from} -> ${item.to}` });
        continue;
      }
      mkdirp(path.dirname(item.to));
      fs.writeFileSync(item.to, content);
      rep.action({ action: 'copy', id: item.id, detail: `${item.to}${item.note ? ` (${item.note})` : ''}` });
    } catch (err) {
      failed++;
      rep.action({ action: 'error', id: item.id, detail: err.message });
    }
  }

  rep.note('');
  rep.note(`Review captured changes with:  git -C "${REPO}" diff --stat`);
  rep.finish({ command: 'pull', dryRun: opts.dryRun, ok: failed === 0, failed });
  return failed === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------
// import (this machine -> repo seed)
// ---------------------------------------------------------------------------

function runImport(opts) {
  const rep = makeReporter(opts.json, opts.dryRun);
  if (!opts.json) console.log(opts.dryRun ? 'ai-sync import (dry-run)' : 'ai-sync import');
  let failed = 0;
  let copied = 0;
  for (const entry of getEntries()) {
    try {
      if (entry.kind === 'render' || entry.kind === 'codex-preserve') {
        rep.action({ action: 'skip', id: entry.id, detail: 'generated/manual — not imported' });
        continue;
      }
      if (entry.kind === 'skills') {
        rep.action({ action: 'skip', id: entry.id, detail: 'managed by skills-enabled.txt' });
        continue;
      }
      if (!exists(entry.target)) {
        rep.action({ action: 'skip', id: entry.id, detail: 'live target not present' });
        continue;
      }
      if (isSymlink(entry.target)) {
        rep.action({ action: 'skip', id: entry.id, detail: 'live target already repo-backed' });
        continue;
      }
      if (opts.dryRun) {
        rep.action({ action: 'copy', id: entry.id, detail: `would copy ${entry.target} -> ${entry.source}` });
        copied++;
        continue;
      }
      if (entry.kind === 'linkDir') {
        const excludes = entry.id === 'codex-skills' ? ['.system'] : [];
        copyDir(entry.target, entry.source, excludes);
      } else {
        mkdirp(path.dirname(entry.source));
        fs.copyFileSync(entry.target, entry.source);
      }
      rep.action({ action: 'copy', id: entry.id, detail: `${entry.source}` });
      copied++;
    } catch (err) {
      failed++;
      rep.action({ action: 'error', id: entry.id, detail: err.message });
    }
  }
  rep.note('');
  rep.note(failed === 0 ? `OK: ${copied} entries captured into the repo` : `ISSUES: ${failed} entries failed`);
  rep.finish({ command: 'import', dryRun: opts.dryRun, ok: failed === 0, failed });
  return failed === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const out = { cmd: null, dryRun: false, json: false, verbose: false, help: false };
  for (const a of argv) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a === '--json') out.json = true;
    else if (a === '--verbose') out.verbose = true;
    else if (a === '-h' || a === '--help') out.help = true;
    else if (out.cmd === null) out.cmd = a;
  }
  return out;
}

function usage() {
  console.log(
    [
      'Usage: node scripts/ai-sync.mjs <import|apply|pull|status> [--dry-run] [--json] [--verbose]',
      '',
      '  import   seed the repo from this machine (raw copies)',
      '  apply    repo -> machine (LINK / MIRROR / RENDER)',
      '  pull     machine -> repo for MIRROR entries',
      '  status   verify; exit 0 in sync, 1 drift, 2 not applied yet',
    ].join('\n')
  );
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help || opts.cmd === null) {
    usage();
    return opts.cmd === null && !opts.help ? 2 : 0;
  }
  switch (opts.cmd) {
    case 'status':
      return runStatus(opts);
    case 'apply':
      return runApply(opts);
    case 'pull':
      return runPull(opts);
    case 'import':
      return runImport(opts);
    default:
      console.error(`unknown command: ${opts.cmd}`);
      usage();
      return 2;
  }
}

process.exitCode = main();
