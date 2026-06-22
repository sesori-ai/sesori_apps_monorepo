import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/api/platform_update_api.dart';
import 'package:sesori_bridge/src/updater/api/posix_update_api.dart';
import 'package:test/test.dart';

class _FakeProcessRunner implements ProcessRunner {
  _FakeProcessRunner({this.chmodExitCode = 0});

  final int chmodExitCode;
  final List<List<String>> calls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add([executable, ...arguments]);
    if (executable == 'chmod') {
      return ProcessResult(0, chmodExitCode, '', '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late Directory tempDir;
  late String installRoot;
  late String stagingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('posix-update-api');
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
    writeFile(p.join(installRoot, 'bin', 'sesori-bridge'), 'OLD-BINARY');
    writeFile(p.join(installRoot, 'lib', 'libsqlite3.so'), 'OLD-LIB');
  }

  void seedStaging() {
    writeFile(p.join(stagingPath, 'bin', 'sesori-bridge'), 'NEW-BINARY');
    writeFile(p.join(stagingPath, 'lib', 'libsqlite3.so'), 'NEW-LIB');
    writeFile(p.join(stagingPath, 'lib', 'libnew.so'), 'BRAND-NEW');
  }

  test('applyInPlace swaps binary and lib wholesale', () async {
    seedInstall();
    seedStaging();
    final api = PosixUpdateApi(processRunner: _FakeProcessRunner());

    await api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);

    expect(File(p.join(installRoot, 'bin', 'sesori-bridge')).readAsStringSync(), 'NEW-BINARY');
    expect(File(p.join(installRoot, 'lib', 'libsqlite3.so')).readAsStringSync(), 'NEW-LIB');
    expect(File(p.join(installRoot, 'lib', 'libnew.so')).readAsStringSync(), 'BRAND-NEW');
    // Backups are removed on success.
    expect(File(p.join(installRoot, 'bin', '.sesori-bridge.rollback')).existsSync(), isFalse);
    expect(Directory(p.join(installRoot, '.lib.rollback')).existsSync(), isFalse);
  });

  test('applyInPlace marks the staged binary executable via chmod', () async {
    seedInstall();
    seedStaging();
    final runner = _FakeProcessRunner();
    final api = PosixUpdateApi(processRunner: runner);

    await api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);

    expect(runner.calls.any((call) => call.first == 'chmod' && call.contains('+x')), isTrue);
  });

  test('applyInPlace throws and leaves the install intact when the payload is missing', () async {
    seedInstall();
    // No staging payload at all.
    final api = PosixUpdateApi(processRunner: _FakeProcessRunner());

    await expectLater(
      api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath),
      throwsA(isA<UpdateApplyException>()),
    );

    expect(File(p.join(installRoot, 'bin', 'sesori-bridge')).readAsStringSync(), 'OLD-BINARY');
    expect(File(p.join(installRoot, 'lib', 'libsqlite3.so')).readAsStringSync(), 'OLD-LIB');
  });

  test('applyInPlace throws and leaves the install intact when chmod fails', () async {
    seedInstall();
    seedStaging();
    final api = PosixUpdateApi(processRunner: _FakeProcessRunner(chmodExitCode: 1));

    await expectLater(
      api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath),
      throwsA(isA<UpdateApplyException>()),
    );

    expect(File(p.join(installRoot, 'bin', 'sesori-bridge')).readAsStringSync(), 'OLD-BINARY');
  });

  test('rollback restores the original binary when the lib swap fails mid-apply', () async {
    if (Platform.isWindows) {
      return; // forces the mid-swap failure with a POSIX read-only directory
    }
    seedInstall();
    seedStaging();
    // installRoot read-only, but bin/ stays writable: the binary swap (renames
    // within bin/) succeeds, then renaming installRoot/lib (needs write on
    // installRoot) fails — triggering rollback after the binary already moved.
    await Process.run('chmod', ['555', installRoot]);
    addTearDown(() => Process.run('chmod', ['755', installRoot]));

    final api = PosixUpdateApi(processRunner: _FakeProcessRunner());

    await expectLater(
      api.applyInPlace(installRoot: installRoot, stagingPath: stagingPath),
      throwsA(anything),
    );

    // The binary swap was rolled back and the lib was never touched.
    expect(File(p.join(installRoot, 'bin', 'sesori-bridge')).readAsStringSync(), 'OLD-BINARY');
    expect(File(p.join(installRoot, 'lib', 'libsqlite3.so')).readAsStringSync(), 'OLD-LIB');
    expect(File(p.join(installRoot, 'lib', 'libnew.so')).existsSync(), isFalse);
  });

  test('sweepResidue deletes leftover rollback artifacts', () async {
    writeFile(p.join(installRoot, 'bin', '.sesori-bridge.rollback'), 'old');
    writeFile(p.join(installRoot, '.lib.rollback', 'libsqlite3.so'), 'old');
    final api = PosixUpdateApi(processRunner: _FakeProcessRunner());

    await api.sweepResidue(installRoot: installRoot);

    expect(File(p.join(installRoot, 'bin', '.sesori-bridge.rollback')).existsSync(), isFalse);
    expect(Directory(p.join(installRoot, '.lib.rollback')).existsSync(), isFalse);
  });
}
