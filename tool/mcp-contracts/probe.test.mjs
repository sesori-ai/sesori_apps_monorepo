import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

test('unsupported native version fails before opening fixture servers', () => {
  const result = spawnSync(process.execPath, [
    new URL('./probe.mjs', import.meta.url).pathname,
    'codex', process.execPath, join(tmpdir(), 'sesori-unexpected-version.json'),
  ], { encoding: 'utf8', timeout: 3000 });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Unsupported codex probe version:/);
  assert.doesNotMatch(result.stderr, /listen|EPERM/);
});
