import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/api/archive_extractor_api.dart';
import 'package:test/test.dart';

void main() {
  // The extractor shells to `tar`/`Expand-Archive`; the security-hardening
  // (symlink + traversal rejection) is exercised here against a real `tar`.
  late Directory tempDir;
  late String payloadDir;
  late String archivePath;
  late String stagingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive-extractor');
    payloadDir = p.join(tempDir.path, 'payload');
    archivePath = p.join(tempDir.path, 'payload.tar.gz');
    stagingPath = p.join(tempDir.path, 'staging');
    Directory(payloadDir).createSync(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeFile(String relative, String contents) {
    final file = File(p.join(payloadDir, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  Future<void> tarPayload() async {
    final result = await Process.run('tar', ['-czf', archivePath, '-C', payloadDir, '.']);
    expect(result.exitCode, 0, reason: 'tar failed: ${result.stderr}');
  }

  test('extracts a regular-file payload', () async {
    if (Platform.isWindows) return; // uses POSIX tar
    writeFile(p.join('bin', 'sesori-bridge'), 'BIN');
    writeFile(p.join('lib', 'a.dll'), 'A');
    await tarPayload();

    final ok = await ArchiveExtractorApi(processRunner: ProcessRunner()).extract(
      archivePath: archivePath,
      stagingPath: stagingPath,
    );

    expect(ok, isTrue);
    expect(File(p.join(stagingPath, 'bin', 'sesori-bridge')).readAsStringSync(), 'BIN');
    expect(File(p.join(stagingPath, 'lib', 'a.dll')).readAsStringSync(), 'A');
  });

  test('rejects a payload containing a symlink and cleans staging', () async {
    if (Platform.isWindows) return; // uses POSIX tar + symlinks
    writeFile(p.join('lib', 'real.dll'), 'REAL');
    // A symlink that escapes the install root — the concrete attack vector.
    Link(p.join(payloadDir, 'lib', 'evil')).createSync('/etc/passwd');
    await tarPayload();

    final ok = await ArchiveExtractorApi(processRunner: ProcessRunner()).extract(
      archivePath: archivePath,
      stagingPath: stagingPath,
    );

    expect(ok, isFalse);
    // Fail-closed: nothing is left staged for the apply step.
    expect(Directory(stagingPath).existsSync(), isFalse);
  });
}
