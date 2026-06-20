import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/platform_update_api.dart';
import 'package:sesori_bridge/src/updater/api/windows_update_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String installRoot;
  late String stagingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('windows-update-api');
    installRoot = p.join(tempDir.path, 'install');
    stagingPath = p.join(tempDir.path, 'staging');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeFile(String path, String contents) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  void seedInstall() {
    writeFile(p.join(installRoot, 'bin', 'sesori-bridge.exe'), 'OLD-BINARY');
    writeFile(p.join(installRoot, 'lib', 'a.dll'), 'OLD-A');
    writeFile(p.join(installRoot, 'lib', 'b.dll'), 'OLD-B');
  }

  void seedStaging() {
    writeFile(p.join(stagingPath, 'bin', 'sesori-bridge.exe'), 'NEW-BINARY');
    writeFile(p.join(stagingPath, 'lib', 'a.dll'), 'NEW-A');
    writeFile(p.join(stagingPath, 'lib', 'c.dll'), 'NEW-C');
  }

  test('applyInPlace swaps the binary and lib per-file, keeping .old residue', () async {
    seedInstall();
    seedStaging();
    const api = WindowsUpdateApi();

    await api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);

    // New binary + lib files are in place.
    expect(File(p.join(installRoot, 'bin', 'sesori-bridge.exe')).readAsStringSync(), 'NEW-BINARY');
    expect(File(p.join(installRoot, 'lib', 'a.dll')).readAsStringSync(), 'NEW-A');
    expect(File(p.join(installRoot, 'lib', 'c.dll')).readAsStringSync(), 'NEW-C');
    // The displaced original lib file is no longer in lib (moved to .old).
    expect(File(p.join(installRoot, 'lib', 'b.dll')).existsSync(), isFalse);

    // The displaced originals are kept for sweeping on the next launch.
    expect(File(p.join(installRoot, 'bin', '.sesori-bridge.old')).readAsStringSync(), 'OLD-BINARY');
    expect(File(p.join(installRoot, '.lib.old', 'a.dll')).readAsStringSync(), 'OLD-A');
    expect(File(p.join(installRoot, '.lib.old', 'b.dll')).readAsStringSync(), 'OLD-B');
  });

  test('swaps lib files inside subdirectories per-file (never renaming a directory)', () async {
    writeFile(p.join(installRoot, 'bin', 'sesori-bridge.exe'), 'OLD-BINARY');
    writeFile(p.join(installRoot, 'lib', 'plugins', 'p.dll'), 'OLD-P');
    writeFile(p.join(stagingPath, 'bin', 'sesori-bridge.exe'), 'NEW-BINARY');
    writeFile(p.join(stagingPath, 'lib', 'plugins', 'p.dll'), 'NEW-P');
    writeFile(p.join(stagingPath, 'lib', 'a.dll'), 'NEW-A');
    const api = WindowsUpdateApi();

    await api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);

    expect(File(p.join(installRoot, 'lib', 'plugins', 'p.dll')).readAsStringSync(), 'NEW-P');
    expect(File(p.join(installRoot, 'lib', 'a.dll')).readAsStringSync(), 'NEW-A');
    // The displaced nested original is preserved at its relative path.
    expect(File(p.join(installRoot, '.lib.old', 'plugins', 'p.dll')).readAsStringSync(), 'OLD-P');
  });

  test('applies a release where an old lib directory becomes a file at the same path', () async {
    // Old install: lib/foo is a DIRECTORY (lib/foo/bar.dll).
    writeFile(p.join(installRoot, 'bin', 'sesori-bridge.exe'), 'OLD-BINARY');
    writeFile(p.join(installRoot, 'lib', 'foo', 'bar.dll'), 'OLD-BAR');
    // New release: lib/foo is a FILE.
    writeFile(p.join(stagingPath, 'bin', 'sesori-bridge.exe'), 'NEW-BINARY');
    writeFile(p.join(stagingPath, 'lib', 'foo'), 'NEW-FOO');
    const api = WindowsUpdateApi();

    await api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);

    // The staged file replaced the old directory skeleton at lib/foo.
    final foo = File(p.join(installRoot, 'lib', 'foo'));
    expect(foo.existsSync(), isTrue);
    expect(foo.readAsStringSync(), 'NEW-FOO');
    expect(FileSystemEntity.isDirectorySync(p.join(installRoot, 'lib', 'foo')), isFalse);
    // The displaced original is preserved for sweeping.
    expect(File(p.join(installRoot, '.lib.old', 'foo', 'bar.dll')).readAsStringSync(), 'OLD-BAR');
  });

  test('applyInPlace throws and leaves the install intact when the payload is missing', () async {
    seedInstall();
    const api = WindowsUpdateApi();

    await expectLater(
      api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath),
      throwsA(isA<UpdateApplyException>()),
    );

    expect(File(p.join(installRoot, 'bin', 'sesori-bridge.exe')).readAsStringSync(), 'OLD-BINARY');
    expect(File(p.join(installRoot, 'lib', 'a.dll')).readAsStringSync(), 'OLD-A');
    expect(File(p.join(installRoot, 'lib', 'b.dll')).readAsStringSync(), 'OLD-B');
  });

  test('sweepResidue deletes leftover .old artifacts', () async {
    writeFile(p.join(installRoot, 'bin', '.sesori-bridge.old'), 'old');
    writeFile(p.join(installRoot, '.lib.old', 'a.dll'), 'old');
    const api = WindowsUpdateApi();

    await api.sweepResidue(installRoot: installRoot);

    expect(File(p.join(installRoot, 'bin', '.sesori-bridge.old')).existsSync(), isFalse);
    expect(Directory(p.join(installRoot, '.lib.old')).existsSync(), isFalse);
  });
}
