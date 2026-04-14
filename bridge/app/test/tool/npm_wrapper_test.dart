import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _currentPlatformPackage() {
  const packages = <String, String>{
    'darwin arm64': '@sesori/bridge-darwin-arm64',
    'darwin x64': '@sesori/bridge-darwin-x64',
    'linux x64': '@sesori/bridge-linux-x64',
    'linux arm64': '@sesori/bridge-linux-arm64',
    'win32 x64': '@sesori/bridge-win32-x64',
  };

  if (Platform.isWindows) {
    return '@sesori/bridge-win32-x64';
  }

  final uname = Process.runSync('uname', ['-m']);
  final machine = '${uname.stdout}'.toLowerCase().trim();
  final arch = machine.contains('arm64') || machine.contains('aarch64') ? 'arm64' : 'x64';
  final platform = Platform.isMacOS ? 'darwin' : Platform.operatingSystem;
  return packages['$platform $arch']!;
}

String _wrapperPackageRoot() {
  return p.join(Directory.current.path, 'npm', 'sesori-bridge');
}

String _managedInstallRoot({required String homePath}) {
  return Platform.isWindows ? p.join(homePath, 'AppData', 'Local', 'sesori') : p.join(homePath, '.sesori');
}

String _managedBinaryPath({required String homePath}) {
  return p.join(
    _managedInstallRoot(homePath: homePath),
    'bin',
    Platform.isWindows ? 'sesori-bridge.exe' : 'sesori-bridge',
  );
}

String _bootstrapLockPath({required String homePath}) {
  return p.join(p.dirname(_managedInstallRoot(homePath: homePath)), '.sesori-bootstrap.lock');
}

Future<ProcessResult> _runNodeHarness({required String source}) async {
  final tempDir = await Directory.systemTemp.createTemp('npm-wrapper-harness-');
  addTearDown(() => tempDir.delete(recursive: true));
  final harnessPath = p.join(tempDir.path, 'harness.js');
  await File(harnessPath).writeAsString(source);
  return Process.run('node', [harnessPath], workingDirectory: tempDir.path);
}

Future<ProcessResult> _runWrapperProcess({
  required Directory packageRoot,
  required String homePath,
  required List<String> args,
  Map<String, String> environment = const {},
}) {
  return Process.run(
    'node',
    [p.join(packageRoot.path, 'bin', 'bridge.js'), ...args],
    environment: {
      'HOME': homePath,
      if (Platform.isWindows) 'LOCALAPPDATA': p.join(homePath, 'AppData', 'Local'),
      ...environment,
    },
  );
}

Future<Process> _startWrapperProcess({
  required Directory packageRoot,
  required String homePath,
  required List<String> args,
  Map<String, String> environment = const {},
}) {
  return Process.start(
    'node',
    [p.join(packageRoot.path, 'bin', 'bridge.js'), ...args],
    environment: {
      'HOME': homePath,
      if (Platform.isWindows) 'LOCALAPPDATA': p.join(homePath, 'AppData', 'Local'),
      ...environment,
    },
  );
}

Future<Directory> _createWrapperFixture() async {
  final tempDir = await Directory.systemTemp.createTemp('npm-wrapper-fixture-');
  addTearDown(() => tempDir.delete(recursive: true));

  final wrapperRoot = Directory(p.join(tempDir.path, 'wrapper'));
  await _copyRecursive(
    sourcePath: _wrapperPackageRoot(),
    targetPath: wrapperRoot.path,
  );
  return wrapperRoot;
}

Future<void> _copyRecursive({
  required String sourcePath,
  required String targetPath,
}) async {
  final entityType = FileSystemEntity.typeSync(sourcePath);
  switch (entityType) {
    case FileSystemEntityType.directory:
      await Directory(targetPath).create(recursive: true);
      await for (final entity in Directory(sourcePath).list()) {
        await _copyRecursive(
          sourcePath: entity.path,
          targetPath: p.join(targetPath, p.basename(entity.path)),
        );
      }
      return;
    case FileSystemEntityType.file:
      await File(targetPath).parent.create(recursive: true);
      await File(sourcePath).copy(targetPath);
      return;
    case FileSystemEntityType.notFound:
    case FileSystemEntityType.link:
    case FileSystemEntityType.unixDomainSock:
    case FileSystemEntityType.pipe:
      throw StateError('Unsupported fixture entity: $sourcePath');
  }
}

Future<void> _createPlatformPayload({
  required Directory wrapperRoot,
  required String version,
  required String binaryMarker,
  required String libMarker,
}) async {
  final packageName = _currentPlatformPackage();
  final packageDir = Directory(
    p.joinAll([wrapperRoot.path, 'node_modules', ...packageName.split('/')]),
  );
  final runtimeRoot = p.join(packageDir.path, 'lib', 'runtime');
  final binaryPath = p.join(
    runtimeRoot,
    'bin',
    Platform.isWindows ? 'sesori-bridge.exe' : 'sesori-bridge',
  );
  final libPath = p.join(runtimeRoot, 'lib', 'runtime-marker.txt');

  await Directory(p.dirname(binaryPath)).create(recursive: true);
  await Directory(p.dirname(libPath)).create(recursive: true);
  await File(p.join(packageDir.path, 'package.json')).writeAsString(
    jsonEncode({
      'name': packageName,
      'version': version,
      'sesoriBridge': {'runtimeBundlePath': 'lib/runtime'},
    }),
  );
  await File(libPath).writeAsString(libMarker);
  await File(binaryPath).writeAsString(_runtimeBinarySource(marker: binaryMarker));
  final chmod = await Process.run('chmod', ['+x', binaryPath]);
  expect(chmod.exitCode, equals(0), reason: '${chmod.stdout}\n${chmod.stderr}');
}

String _runtimeBinarySource({required String marker}) {
  return '''
#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const executablePath = process.argv[1];
if (executablePath.includes('node_modules')) {
  console.error('sesori-bridge: Direct execution from npm-owned package payloads is unsupported. Run `npx @sesori/bridge` to bootstrap or refresh the managed install, then use `sesori-bridge` from your PATH.');
  process.exit(1);
}
const recordPath = process.env.SESORI_BRIDGE_RECORD_PATH;
const libMarkerPath = path.join(__dirname, '..', 'lib', 'runtime-marker.txt');
const payload = {
  marker: ${jsonEncode(marker)},
  executedPath: executablePath,
  args: process.argv.slice(2),
  path: process.env.PATH,
  libMarker: fs.readFileSync(libMarkerPath, 'utf8'),
};
if (recordPath) {
  fs.writeFileSync(recordPath, JSON.stringify(payload));
}
''';
}

Future<void> _seedManagedRuntime({
  required String homePath,
  required String version,
  required String binaryMarker,
  required String libMarker,
  required bool includeBinary,
  required bool includeLib,
}) async {
  final installRoot = _managedInstallRoot(homePath: homePath);
  await Directory(installRoot).create(recursive: true);
  await File(p.join(installRoot, '.managed-runtime.json')).writeAsString(
    jsonEncode({'version': version}),
  );

  if (includeBinary) {
    final binaryPath = _managedBinaryPath(homePath: homePath);
    await File(binaryPath).parent.create(recursive: true);
    await File(binaryPath).writeAsString(_runtimeBinarySource(marker: binaryMarker));
    final chmod = await Process.run('chmod', ['+x', binaryPath]);
    expect(chmod.exitCode, equals(0), reason: '${chmod.stdout}\n${chmod.stderr}');
  }

  if (includeLib) {
    final libPath = p.join(installRoot, 'lib', 'runtime-marker.txt');
    await File(libPath).parent.create(recursive: true);
    await File(libPath).writeAsString(libMarker);
  }
}

Future<Map<String, dynamic>> _readRecordedInvocation({required String recordPath}) async {
  return jsonDecode(await File(recordPath).readAsString()) as Map<String, dynamic>;
}

Future<({int exitCode, String stdout, String stderr})> _waitForProcess(Process process) async {
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  return (exitCode: exitCode, stdout: await stdoutFuture, stderr: await stderrFuture);
}

void main() {
  group('bridge.js', () {
    test('fails with a clear message for unsupported platforms', () async {
      final scriptPath = p.join(_wrapperPackageRoot(), 'bin', 'bridge.js');
      final bootstrapPath = p.join(_wrapperPackageRoot(), 'lib', 'bootstrap.js');
      final result = await _runNodeHarness(
        source:
            '''
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const source = fs.readFileSync(${jsonEncode(scriptPath)}, 'utf8');
const stderr = [];
let exitCode = null;
const sandbox = {
  require(name) {
    if (name === '../lib/bootstrap') {
      return require(${jsonEncode(bootstrapPath)});
    }
    throw new Error('unexpected require: ' + name);
  },
  process: {
    platform: 'sunos',
    arch: 'sparc',
    argv: ['node', 'bridge.js'],
    exit(code) { exitCode = code; throw new Error('__EXIT__'); },
  },
  console: { error(message) { stderr.push(String(message)); } },
};
try {
  vm.runInNewContext(source, sandbox, { filename: 'bridge.js' });
} catch (error) {
  if (error.message !== '__EXIT__') throw error;
}
console.log(JSON.stringify({ exitCode, stderr: stderr.join('\\n') }));
''',
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final decoded = jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(decoded['exitCode'], equals(1));
      final stderr = decoded['stderr'] as String;
      expect(stderr, contains('sesori-bridge: Unsupported platform: sunos sparc'));
      expect(stderr, contains('Supported platforms: darwin arm64, darwin x64, linux x64, linux arm64, win32 x64'));
      expect(stderr, contains('npm install @sesori/bridge-darwin-arm64'));
    });

    test('fails when the optional platform package cannot be resolved', () async {
      final wrapperRoot = await _createWrapperFixture();
      final expectedPackage = _currentPlatformPackage();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['--version'],
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains("Failed to find platform package '$expectedPackage'."));
      expect(result.stderr, contains('npm install $expectedPackage'));
    });

    test('bootstraps a missing managed install and executes the managed binary', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve', '--port', '4096'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      final managedBinary = _managedBinaryPath(homePath: homeDir.path);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['executedPath'], equals(managedBinary));
      expect(recorded['args'], equals(['serve', '--port', '4096']));
      expect(
        (recorded['path'] as String).split(Platform.isWindows ? ';' : ':').first,
        equals(p.dirname(managedBinary)),
      );
      expect(recorded['libMarker'], equals('payload-lib'));
      expect(File(p.join(_managedInstallRoot(homePath: homeDir.path), '.managed-runtime.json')).existsSync(), isTrue);
    });

    test('bootstrap makes sesori-bridge discoverable in a fresh shell', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final bootstrapRecordPath = p.join(homeDir.path, 'bootstrap-record.json');
      final freshShellRecordPath = p.join(homeDir.path, 'fresh-shell-record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final bootstrapResult = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve'],
        environment: {
          'SHELL': '/bin/bash',
          'SESORI_BRIDGE_RECORD_PATH': bootstrapRecordPath,
        },
      );

      expect(bootstrapResult.exitCode, equals(0), reason: '${bootstrapResult.stdout}\n${bootstrapResult.stderr}');
      expect(
        File(p.join(homeDir.path, '.bashrc')).readAsStringSync(),
        contains(r'export PATH="$HOME/.sesori/bin:$PATH"'),
      );

      final shellResult = await Process.run(
        '/bin/bash',
        [
          '--rcfile',
          p.join(homeDir.path, '.bashrc'),
          '-i',
          '-c',
          'command -v sesori-bridge && sesori-bridge fresh-shell',
        ],
        environment: {
          'HOME': homeDir.path,
          'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
          'SESORI_BRIDGE_RECORD_PATH': freshShellRecordPath,
        },
      );

      expect(shellResult.exitCode, equals(0), reason: '${shellResult.stdout}\n${shellResult.stderr}');
      expect(shellResult.stdout as String, contains(_managedBinaryPath(homePath: homeDir.path)));
      final recorded = await _readRecordedInvocation(recordPath: freshShellRecordPath);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['executedPath'], equals(_managedBinaryPath(homePath: homeDir.path)));
      expect(recorded['args'], equals(['fresh-shell']));
    });

    test('same-version managed runtime is a no-op', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await _seedManagedRuntime(
        homePath: homeDir.path,
        version: '1.2.3',
        binaryMarker: 'existing-managed',
        libMarker: 'existing-lib',
        includeBinary: true,
        includeLib: true,
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      expect(recorded['marker'], equals('existing-managed'));
      expect(recorded['libMarker'], equals('existing-lib'));
    });

    test('newer managed runtime is not downgraded by an older npm payload', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await _seedManagedRuntime(
        homePath: homeDir.path,
        version: '9.9.9',
        binaryMarker: 'newer-managed',
        libMarker: 'newer-lib',
        includeBinary: true,
        includeLib: true,
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['doctor'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      expect(recorded['marker'], equals('newer-managed'));
      expect(recorded['libMarker'], equals('newer-lib'));
      final manifest =
          jsonDecode(
                await File(p.join(_managedInstallRoot(homePath: homeDir.path), '.managed-runtime.json')).readAsString(),
              )
              as Map<String, dynamic>;
      expect(manifest['version'], equals('9.9.9'));
    });

    test('older managed runtime is upgraded to the npm payload version', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await _seedManagedRuntime(
        homePath: homeDir.path,
        version: '1.0.0',
        binaryMarker: 'older-managed',
        libMarker: 'older-lib',
        includeBinary: true,
        includeLib: true,
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['libMarker'], equals('payload-lib'));
      final manifest =
          jsonDecode(
                await File(p.join(_managedInstallRoot(homePath: homeDir.path), '.managed-runtime.json')).readAsString(),
              )
              as Map<String, dynamic>;
      expect(manifest['version'], equals('1.2.3'));
    });

    test('repairs an incomplete same-version managed runtime', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await _seedManagedRuntime(
        homePath: homeDir.path,
        version: '1.2.3',
        binaryMarker: 'broken-managed',
        libMarker: 'broken-lib',
        includeBinary: true,
        includeLib: false,
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['libMarker'], equals('payload-lib'));
    });

    test('fails closed when a newer managed runtime is incomplete', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await _seedManagedRuntime(
        homePath: homeDir.path,
        version: '9.9.9',
        binaryMarker: 'broken-newer-managed',
        libMarker: 'broken-lib',
        includeBinary: true,
        includeLib: false,
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': recordPath},
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('Managed runtime 9.9.9 is incomplete/corrupt and newer than npm payload 1.2.3'));
      expect(result.stderr, contains('Refusing to repair it with an older npm payload'));
      expect(result.stderr, contains('bootstrap again with npx'));
      expect(File(recordPath).existsSync(), isFalse);
    });

    test('fails closed on managed install write failure', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': recordPath,
          'SESORI_BRIDGE_TEST_WRITE_FAIL': '1',
        },
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('Failed to install the managed runtime'));
      expect(result.stderr, contains('Refusing to run runtime binaries from npm-owned paths'));
      expect(result.stderr, contains('Delete the managed install directory and rerun npx @sesori/bridge'));
      expect(File(recordPath).existsSync(), isFalse);
    });

    test('managed runtime stays runnable after the npm package is removed', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final bootstrapRecordPath = p.join(homeDir.path, 'bootstrap-record.json');
      final directRecordPath = p.join(homeDir.path, 'direct-record.json');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final bootstrapResult = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve'],
        environment: {'SESORI_BRIDGE_RECORD_PATH': bootstrapRecordPath},
      );
      expect(bootstrapResult.exitCode, equals(0), reason: '${bootstrapResult.stdout}\n${bootstrapResult.stderr}');

      await Directory(p.join(wrapperRoot.path, 'node_modules')).delete(recursive: true);
      final managedBinary = _managedBinaryPath(homePath: homeDir.path);
      final directRun = await Process.run(
        managedBinary,
        ['after-npm-removal'],
        environment: {
          'HOME': homeDir.path,
          if (Platform.isWindows) 'LOCALAPPDATA': p.join(homeDir.path, 'AppData', 'Local'),
          'SESORI_BRIDGE_RECORD_PATH': directRecordPath,
        },
      );

      expect(directRun.exitCode, equals(0), reason: '${directRun.stdout}\n${directRun.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: directRecordPath);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['args'], equals(['after-npm-removal']));
      expect(recorded['libMarker'], equals('payload-lib'));
    });

    test('direct execution of package payload binary fails with guidance', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final packageName = _currentPlatformPackage();
      final packageDir = Directory(
        p.joinAll([wrapperRoot.path, 'node_modules', ...packageName.split('/')]),
      );
      final directBinary = p.join(
        packageDir.path,
        'lib',
        'runtime',
        'bin',
        Platform.isWindows ? 'sesori-bridge.exe' : 'sesori-bridge',
      );

      final result = await Process.run(
        directBinary,
        ['status'],
        environment: {
          'HOME': homeDir.path,
          if (Platform.isWindows) 'LOCALAPPDATA': p.join(homeDir.path, 'AppData', 'Local'),
        },
      );

      expect(result.exitCode, equals(1));
      expect(
        result.stderr,
        contains('Direct execution from npm-owned package payloads is unsupported'),
      );
      expect(result.stderr, contains('Run `npx @sesori/bridge`'));
      expect(result.stderr, contains('then use `sesori-bridge` from your PATH'));
    });

    test('concurrent bootstrap attempts share a managed install lock', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final firstRecordPath = p.join(homeDir.path, 'first-record.json');
      final secondRecordPath = p.join(homeDir.path, 'second-record.json');
      final installCounterPath = p.join(homeDir.path, 'install-count.txt');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final firstProcess = await _startWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve', 'first'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': firstRecordPath,
          'SESORI_BRIDGE_TEST_BOOTSTRAP_HOLD_MS': '800',
          'SESORI_BRIDGE_TEST_INSTALL_COUNTER_PATH': installCounterPath,
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      final secondProcess = await _startWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve', 'second'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': secondRecordPath,
          'SESORI_BRIDGE_TEST_INSTALL_COUNTER_PATH': installCounterPath,
        },
      );

      final firstResult = await _waitForProcess(firstProcess);
      final secondResult = await _waitForProcess(secondProcess);

      expect(firstResult.exitCode, equals(0), reason: '${firstResult.stdout}\n${firstResult.stderr}');
      expect(secondResult.exitCode, equals(0), reason: '${secondResult.stdout}\n${secondResult.stderr}');
      expect(
        secondResult.stderr,
        contains('Another bootstrap is already in progress. Waiting for the managed install lock'),
      );
      expect(await File(installCounterPath).readAsString(), equals('1'));

      final firstRecorded = await _readRecordedInvocation(recordPath: firstRecordPath);
      final secondRecorded = await _readRecordedInvocation(recordPath: secondRecordPath);
      expect(firstRecorded['marker'], equals('payload-runtime'));
      expect(secondRecorded['marker'], equals('payload-runtime'));
      expect(secondRecorded['executedPath'], equals(_managedBinaryPath(homePath: homeDir.path)));
    });

    test('active bootstrap holder is not evicted after crossing the stale threshold', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final firstRecordPath = p.join(homeDir.path, 'first-record.json');
      final secondRecordPath = p.join(homeDir.path, 'second-record.json');
      final installCounterPath = p.join(homeDir.path, 'install-count.txt');

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );

      final firstProcess = await _startWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve', 'first'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': firstRecordPath,
          'SESORI_BRIDGE_TEST_BOOTSTRAP_HOLD_MS': '1200',
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_STALE_MS': '300',
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_TIMEOUT_MS': '4000',
          'SESORI_BRIDGE_TEST_INSTALL_COUNTER_PATH': installCounterPath,
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final secondProcess = await _startWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['serve', 'second'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': secondRecordPath,
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_STALE_MS': '300',
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_TIMEOUT_MS': '4000',
          'SESORI_BRIDGE_TEST_INSTALL_COUNTER_PATH': installCounterPath,
        },
      );

      final firstResult = await _waitForProcess(firstProcess);
      final secondResult = await _waitForProcess(secondProcess);

      expect(firstResult.exitCode, equals(0), reason: '${firstResult.stdout}\n${firstResult.stderr}');
      expect(secondResult.exitCode, equals(0), reason: '${secondResult.stdout}\n${secondResult.stderr}');
      expect(
        secondResult.stderr,
        contains('Another bootstrap is already in progress. Waiting for the managed install lock'),
      );
      expect(await File(installCounterPath).readAsString(), equals('1'));

      final firstRecorded = await _readRecordedInvocation(recordPath: firstRecordPath);
      final secondRecorded = await _readRecordedInvocation(recordPath: secondRecordPath);
      expect(firstRecorded['marker'], equals('payload-runtime'));
      expect(secondRecorded['marker'], equals('payload-runtime'));
      expect(secondRecorded['executedPath'], equals(_managedBinaryPath(homePath: homeDir.path)));
    });

    test('stale abandoned bootstrap locks are reclaimed', () async {
      final wrapperRoot = await _createWrapperFixture();
      final homeDir = await Directory.systemTemp.createTemp('npm-wrapper-home-');
      addTearDown(() => homeDir.delete(recursive: true));
      final recordPath = p.join(homeDir.path, 'record.json');
      final lockDir = Directory(_bootstrapLockPath(homePath: homeDir.path));
      final ownerFile = File(p.join(lockDir.path, 'owner.json'));
      final heartbeatFile = File(p.join(lockDir.path, 'heartbeat'));

      await _createPlatformPayload(
        wrapperRoot: wrapperRoot,
        version: '1.2.3',
        binaryMarker: 'payload-runtime',
        libMarker: 'payload-lib',
      );
      await lockDir.create(recursive: true);
      await ownerFile.writeAsString(jsonEncode({'pid': 999999, 'createdAt': '2026-04-14T00:00:00.000Z'}));
      await heartbeatFile.writeAsString('stale');
      final staleTime = DateTime.now().subtract(const Duration(seconds: 5));
      ownerFile.setLastModifiedSync(staleTime);
      heartbeatFile.setLastModifiedSync(staleTime);

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        homePath: homeDir.path,
        args: ['status'],
        environment: {
          'SESORI_BRIDGE_RECORD_PATH': recordPath,
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_STALE_MS': '200',
          'SESORI_BRIDGE_TEST_BOOTSTRAP_LOCK_TIMEOUT_MS': '2000',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recorded = await _readRecordedInvocation(recordPath: recordPath);
      expect(recorded['marker'], equals('payload-runtime'));
      expect(recorded['executedPath'], equals(_managedBinaryPath(homePath: homeDir.path)));
      expect(lockDir.existsSync(), isFalse);
    });
  });
}
