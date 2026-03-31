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

String _wrapperScriptPath() {
  return p.join(Directory.current.path, 'npm', 'sesori-bridge', 'bin', 'bridge.js');
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
  required List<String> args,
}) {
  return Process.run('node', [p.join(packageRoot.path, 'bin', 'bridge.js'), ...args]);
}

Future<Directory> _createWrapperFixture() async {
  final tempDir = await Directory.systemTemp.createTemp('npm-wrapper-fixture-');
  addTearDown(() => tempDir.delete(recursive: true));

  final wrapperRoot = Directory(p.join(tempDir.path, 'wrapper'));
  await Directory(p.join(wrapperRoot.path, 'bin')).create(recursive: true);
  final source = await File(_wrapperScriptPath()).readAsString();
  await File(p.join(wrapperRoot.path, 'bin', 'bridge.js')).writeAsString(source);
  return wrapperRoot;
}

void main() {
  group('bridge.js', () {
    test('fails with a clear message for unsupported platforms', () async {
      final scriptPath = _wrapperScriptPath();
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
    if (name === 'path') return path;
    if (name === 'child_process') return { execFileSync() {} };
    throw new Error('unexpected require: ' + name);
  },
  process: {
    platform: 'sunos',
    arch: 'sparc',
    argv: ['node', 'bridge.js'],
    exit(code) { exitCode = code; throw new Error('__EXIT__'); },
  },
  console: {
    error(message) { stderr.push(String(message)); },
  },
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

      final result = await _runWrapperProcess(packageRoot: wrapperRoot, args: ['--version']);

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains("Failed to find platform package '$expectedPackage'."));
      expect(result.stderr, contains('npm install $expectedPackage'));
    });

    test('passes argv through to the platform binary', () async {
      final wrapperRoot = await _createWrapperFixture();
      final expectedPackage = _currentPlatformPackage();
      final packageDir = Directory(
        p.joinAll([wrapperRoot.path, 'node_modules', ...expectedPackage.split('/')]),
      );
      await Directory(p.join(packageDir.path, 'bin')).create(recursive: true);
      await File(p.join(packageDir.path, 'package.json')).writeAsString('{"name":"$expectedPackage"}\n');

      final argsFile = p.join(wrapperRoot.path, 'args.json');
      final binaryPath = p.join(packageDir.path, 'bin', 'sesori-bridge');
      await File(binaryPath).writeAsString('''
#!/usr/bin/env node
require('fs').writeFileSync(${jsonEncode(argsFile)}, JSON.stringify(process.argv.slice(2)));
''');
      final chmod = await Process.run('chmod', ['+x', binaryPath]);
      expect(chmod.exitCode, equals(0), reason: '${chmod.stdout}\n${chmod.stderr}');

      final result = await _runWrapperProcess(
        packageRoot: wrapperRoot,
        args: ['serve', '--port', '4096'],
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final recordedArgs = jsonDecode(await File(argsFile).readAsString()) as List<dynamic>;
      expect(recordedArgs, equals(['serve', '--port', '4096']));
    });

    test('propagates child exit codes', () async {
      final wrapperRoot = await _createWrapperFixture();
      final expectedPackage = _currentPlatformPackage();
      final packageDir = Directory(
        p.joinAll([wrapperRoot.path, 'node_modules', ...expectedPackage.split('/')]),
      );
      await Directory(p.join(packageDir.path, 'bin')).create(recursive: true);
      await File(p.join(packageDir.path, 'package.json')).writeAsString('{"name":"$expectedPackage"}\n');

      final binaryPath = p.join(packageDir.path, 'bin', 'sesori-bridge');
      await File(binaryPath).writeAsString('''
#!/usr/bin/env node
process.exit(23);
''');
      final chmod = await Process.run('chmod', ['+x', binaryPath]);
      expect(chmod.exitCode, equals(0), reason: '${chmod.stdout}\n${chmod.stderr}');

      final result = await _runWrapperProcess(packageRoot: wrapperRoot, args: ['status']);

      expect(result.exitCode, equals(23));
    });
  });
}
