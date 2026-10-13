import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const baseline = 'ffa5935c8363c6429fdf2e3c3fb95b3a906f5ab5'; // Public v1.9.0, build 970.
const source = path => {
  const result = spawnSync('git', ['show', `${baseline}:${path}`], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, `Released source must be available: ${path}`);
  return result.stdout;
};

// Current codecs are usable here only while byte-identical to the public release.
// Fail rather than accidentally running a newer decoder as the released peer.
for (const name of ['question', 'sesori_sse_event']) {
  for (const suffix of ['dart', 'g.dart', 'freezed.dart']) {
    const path = `shared/sesori_shared/lib/src/models/sesori/${name}.${suffix}`;
    assert.equal(await readFile(join(root, path), 'utf8'), source(path), `Released codec drift: ${path}`);
  }
}
const connection = source('client/module_core/lib/src/capabilities/server_connection/connection_service.dart');
const start = connection.indexOf('  void _onSseData(');
const end = connection.indexOf('  /// Tears down the active relay client', start);
assert.ok(start >= 0 && end > start, 'Released SSE parsing boundary must be found');
const template = await readFile(new URL('./released-peer.dart.in', import.meta.url), 'utf8');
const packageRoot = join(root, 'shared/sesori_shared');
const output = join(packageRoot, '.dart_tool', 'released_mcp_peer_probe.dart');
await writeFile(output, template.replace('/* RELEASED_SSE_METHODS */', connection.slice(start, end)));
const dart = process.argv[2];
assert.ok(dart, 'Usage: node released-peer.mjs <dart-executable>; run shared dart pub get first');
const result = spawnSync(dart, ['--packages=.dart_tool/package_config.json', output],
  { cwd: packageRoot, encoding: 'utf8' });
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
assert.equal(result.status, 0, 'Released-peer fixture must pass');
