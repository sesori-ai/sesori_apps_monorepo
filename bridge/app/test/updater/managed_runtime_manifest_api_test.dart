import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/managed_runtime_manifest_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('managed-runtime-manifest');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes a manifest the npm bootstrap can read', () async {
    await const ManagedRuntimeManifestApi().writeVersion(installRoot: tempDir.path, version: '1.2.3');

    final contents = File(p.join(tempDir.path, '.managed-runtime.json')).readAsStringSync();
    expect(jsonDecode(contents), {'version': '1.2.3'});
  });

  test('overwrites an existing manifest', () async {
    const api = ManagedRuntimeManifestApi();
    await api.writeVersion(installRoot: tempDir.path, version: '1.0.0');
    await api.writeVersion(installRoot: tempDir.path, version: '2.0.0');

    final contents = File(p.join(tempDir.path, '.managed-runtime.json')).readAsStringSync();
    expect((jsonDecode(contents) as Map)['version'], '2.0.0');
  });

  test('creates the install directory if missing', () async {
    final nested = p.join(tempDir.path, 'created', 'on', 'demand');
    await const ManagedRuntimeManifestApi().writeVersion(installRoot: nested, version: '3.0.0');

    expect(File(p.join(nested, '.managed-runtime.json')).existsSync(), isTrue);
  });
}
