import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

test('terminal helper kills and reaps a child that ignores termination', { timeout: 5000 }, async () => {
  const helper = fileURLToPath(new URL('./terminal.py', import.meta.url));
  const child = spawn('python3', [helper, 'python3', '-c',
    'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print("ready",flush=True); time.sleep(30)']);
  try {
    await once(child.stdout, 'data');
    const exited = once(child, 'exit');
    child.kill('SIGTERM');
    const [status] = await exited;
    assert.equal(status, 143);
  } finally { child.stdin.end(); if (child.exitCode === null) child.kill('SIGKILL'); }
});
