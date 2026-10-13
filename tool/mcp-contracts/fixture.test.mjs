import assert from 'node:assert/strict';
import { test } from 'node:test';

import { startHttpFixture } from './fixture.mjs';

test('HTTP fixture advertises only tools its stateless transport supports', async () => {
  const fixture = await startHttpFixture();
  try {
    async function request(method, params) {
      const response = await fetch(`${fixture.origin}/mcp`, { method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
      return await response.json();
    }
    const list = await request('tools/list', {});
    assert.deepEqual(list.result.tools.map(tool => tool.name), ['echo']);
    const unsupported = await request('tools/call', { name: 'form' });
    assert.equal(unsupported.error.code, -32601);
  } finally { await fixture.close(); }
});
