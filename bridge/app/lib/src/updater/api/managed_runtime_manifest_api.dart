import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes `installRoot/.managed-runtime.json`, the version manifest the npm
/// bootstrap (`runtime_install.js` / `bootstrap.js`) reads to decide whether to
/// (re)install the managed runtime.
///
/// After an in-place update the on-disk binary is newer than this manifest, so
/// it MUST be bumped — otherwise the next `npx @sesori/bridge` compares the
/// stale manifest version against the npm payload and can clobber/downgrade the
/// freshly updated binary.
class ManagedRuntimeManifestApi {
  const ManagedRuntimeManifestApi();

  static const String _fileName = '.managed-runtime.json';

  Future<void> writeVersion({required String installRoot, required String version}) async {
    final Directory dir = Directory(installRoot);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final String filePath = p.join(installRoot, _fileName);
    final File tmpFile = File('$filePath.tmp');
    // Match the bootstrap's `{ "version": "X" }` + newline shape.
    await tmpFile.writeAsString('${jsonEncode(<String, String>{'version': version})}\n', flush: true);

    // tmp-write then rename; pre-delete because Windows File.rename fails over
    // an existing destination (same convention as UpdateCacheApi).
    final File target = File(filePath);
    if (target.existsSync()) {
      target.deleteSync();
    }
    await tmpFile.rename(target.path);
  }
}
