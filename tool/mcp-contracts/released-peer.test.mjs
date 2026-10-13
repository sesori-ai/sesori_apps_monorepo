import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

test('missing Dart executable preserves the launch error', () => {
  const runner = fileURLToPath(new URL('./released-peer.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [runner, '/nonexistent/sesori-fixture-dart'], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /ENOENT/);
  assert.doesNotMatch(result.stderr, /ERR_STREAM_NULL_VALUES/);
});
