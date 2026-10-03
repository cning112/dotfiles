// Behaviour tests for scripts/ai-sync.mjs.
//
// Every test runs against a throwaway copy of the repo plus a fake $HOME, because
// `pull` writes into the repo and `apply` writes into $HOME — neither may touch
// the real checkout or the developer's machine.
//
// Run directly:  node tests/test_ai_sync.mjs

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const REAL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REPO_DIRS = ['scripts', 'claude', 'codex', 'agents', 'opencode', 'dsh'];

const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const readText = (file) => fs.readFileSync(file, 'utf8');

function sandbox() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-sync-test-'));
  const repo = path.join(root, 'repo');
  const home = path.join(root, 'home');
  fs.mkdirSync(home, { recursive: true });
  for (const dir of REPO_DIRS) {
    fs.cpSync(path.join(REAL_ROOT, dir), path.join(repo, dir), {
      recursive: true,
      // .system skills are machine-managed and huge; irrelevant to these tests.
      filter: (src) => !src.includes(`${path.sep}.system`),
    });
  }
  return { root, repo, home, engine: path.join(repo, 'scripts', 'ai-sync.mjs') };
}

// PATH is trimmed so `which('rtk')` is false: the rtk render fragment is
// machine-dependent and would otherwise make these assertions flaky.
function engineEnv(home) {
  return { ...process.env, HOME: home, USERPROFILE: home, PATH: '/usr/bin:/bin' };
}

function run(box, args) {
  return execFileSync(process.execPath, [box.engine, ...args], {
    env: engineEnv(box.home),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runStatus(box) {
  try {
    const out = execFileSync(process.execPath, [box.engine, 'status'], {
      env: engineEnv(box.home),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { code: 0, out };
  } catch (err) {
    return { code: err.status ?? 1, out: `${err.stdout ?? ''}${err.stderr ?? ''}` };
  }
}

const withSandbox = (fn) => {
  const box = sandbox();
  try {
    fn(box);
  } finally {
    fs.rmSync(box.root, { recursive: true, force: true });
  }
};

const FOREIGN_HOOK = {
  matcher: 'Bash',
  hooks: [{ type: 'command', command: 'node "/opt/plugin-dist/hook.js"' }],
};

test('a fresh machine applies cleanly and reports in-sync', () => {
  withSandbox((box) => {
    assert.equal(runStatus(box).code, 2, 'a fresh machine reports "not applied yet"');
    run(box, ['apply']);
    assert.equal(runStatus(box).code, 0, 'after apply the machine is in sync');
    assert.ok(fs.existsSync(path.join(box.home, '.claude', 'settings.json')));
    assert.ok(fs.existsSync(path.join(box.home, '.codex', 'config.toml')));
    assert.ok(fs.existsSync(path.join(box.home, '.dsh', 'settings.yaml')));
  });
});

test('apply preserves a plugin hook registered with an absolute path', () => {
  withSandbox((box) => {
    run(box, ['apply']);
    const livePath = path.join(box.home, '.claude', 'settings.json');
    const live = readJson(livePath);
    live.hooks = { ...(live.hooks ?? {}), SessionStart: [FOREIGN_HOOK] };
    fs.writeFileSync(livePath, `${JSON.stringify(live, null, 2)}\n`);

    run(box, ['apply']);

    const after = readJson(livePath);
    const commands = JSON.stringify(after.hooks ?? {});
    assert.match(commands, /opt\/plugin-dist\/hook\.js/, 'the plugin hook must survive an apply');
    assert.equal(runStatus(box).code, 0, 'a plugin hook must not count as drift');
  });
});

test('apply preserves machine-local codex sections', () => {
  withSandbox((box) => {
    run(box, ['apply']);
    const livePath = path.join(box.home, '.codex', 'config.toml');
    const machineLocal = [
      '',
      '[hooks.state."/opt/plugin/hooks.json:session_start:0:0"]',
      'trusted_hash = "sha256:deadbeef"',
      '',
      '[mcp_servers.hindsight]',
      'command = "node"',
      'args = ["/opt/plugin-dist/mcp-server.js"]',
      '',
    ].join('\n');
    fs.appendFileSync(livePath, machineLocal);

    run(box, ['apply']);

    const after = readText(livePath);
    assert.match(after, /\[hooks\.state\./, 'hook-trust state must survive an apply');
    assert.match(after, /\[mcp_servers\.hindsight\]/, 'the plugin MCP server must survive an apply');
    assert.equal(runStatus(box).code, 0, 'machine-local codex sections must not count as drift');
  });
});

test('pull never writes machine-local plugin state into the repo', () => {
  withSandbox((box) => {
    run(box, ['apply']);
    const liveSettings = path.join(box.home, '.claude', 'settings.json');
    const settings = readJson(liveSettings);
    settings.hooks = { ...(settings.hooks ?? {}), SessionStart: [FOREIGN_HOOK] };
    fs.writeFileSync(liveSettings, `${JSON.stringify(settings, null, 2)}\n`);
    fs.appendFileSync(
      path.join(box.home, '.codex', 'config.toml'),
      '\n[hooks.state."/opt/plugin/hooks.json:stop:0:0"]\ntrusted_hash = "sha256:deadbeef"\n'
    );

    run(box, ['pull']);

    const repoSettings = readText(path.join(box.repo, 'claude', 'settings.json'));
    assert.doesNotMatch(repoSettings, /opt\/plugin-dist/, 'plugin hook path must not reach the repo');
    const repoCodex = readText(path.join(box.repo, 'codex', 'config.toml'));
    assert.doesNotMatch(repoCodex, /\[hooks\.state\./, 'hook-trust state must not reach the repo');
    assert.doesNotMatch(repoCodex, /plugin-dist/, 'plugin paths must not reach the repo');
  });
});

test('pull keeps repo-writable settings, including hooks with no foreign path', () => {
  withSandbox((box) => {
    run(box, ['apply']);
    const livePath = path.join(box.home, '.claude', 'settings.json');
    const live = readJson(livePath);
    live.model = 'haiku';
    live.hooks = {
      ...(live.hooks ?? {}),
      PostToolUse: [{ matcher: 'Edit', hooks: [{ type: 'command', command: 'echo repo-local-hook' }] }],
      SessionStart: [FOREIGN_HOOK],
    };
    fs.writeFileSync(livePath, `${JSON.stringify(live, null, 2)}\n`);

    run(box, ['pull']);

    const repo = readJson(path.join(box.repo, 'claude', 'settings.json'));
    assert.equal(repo.model, 'haiku', 'an ordinary setting is captured');
    const hooks = JSON.stringify(repo.hooks ?? {});
    assert.match(hooks, /repo-local-hook/, 'a path-free hook is captured');
    assert.doesNotMatch(hooks, /opt\/plugin-dist/, 'the plugin hook is not captured');
  });
});
