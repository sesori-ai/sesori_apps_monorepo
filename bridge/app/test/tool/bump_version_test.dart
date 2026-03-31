import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _appRoot() => Directory.current.path;

String _toolSourcePath() => p.join(_appRoot(), 'tool', 'bump_version.dart');

Future<void> _writeJsonFile({
  required String path,
  required Map<String, dynamic> json,
}) async {
  final formatted = const JsonEncoder.withIndent('  ').convert(json);
  await File(path).writeAsString('$formatted\n');
}

class _FixtureApp {
  _FixtureApp({required this.rootPath, required this.oldVersion});

  final String rootPath;
  final String oldVersion;

  String get newVersion => '9.8.7';

  String get wrapperPackagePath => p.join(rootPath, 'npm', 'sesori-bridge', 'package.json');
  String get pubspecPath => p.join(rootPath, 'pubspec.yaml');
  String get versionDartPath => p.join(rootPath, 'lib', 'src', 'version.dart');

  static const platformPackages = <String>[
    'sesori-bridge-darwin-arm64',
    'sesori-bridge-darwin-x64',
    'sesori-bridge-linux-x64',
    'sesori-bridge-linux-arm64',
    'sesori-bridge-win32-x64',
  ];
}

Future<_FixtureApp> _createFixtureApp() async {
  final tempDir = await Directory.systemTemp.createTemp('bump-version-fixture-');
  const oldVersion = '1.2.3';
  final rootPath = tempDir.path;

  await Directory(p.join(rootPath, 'tool')).create(recursive: true);
  await Directory(p.join(rootPath, 'lib', 'src')).create(recursive: true);
  await Directory(p.join(rootPath, 'npm')).create(recursive: true);

  for (final package in _FixtureApp.platformPackages) {
    await Directory(p.join(rootPath, 'npm', package)).create(recursive: true);
  }
  await Directory(p.join(rootPath, 'npm', 'sesori-bridge')).create(recursive: true);

  await File(p.join(rootPath, 'pubspec.yaml')).writeAsString('''
name: bump_version_fixture
version: $oldVersion
environment:
  sdk: ^3.11.0
dependencies:
  path: ^1.9.0
''');

  final toolSource = await File(_toolSourcePath()).readAsString();
  await File(p.join(rootPath, 'tool', 'bump_version.dart')).writeAsString(toolSource);
  await File(p.join(rootPath, 'lib', 'src', 'version.dart')).writeAsString(
    "const String appVersion = '$oldVersion';\n",
  );

  await _writeJsonFile(
    path: p.join(rootPath, 'npm', 'sesori-bridge', 'package.json'),
    json: {
      'name': '@sesori/bridge',
      'version': oldVersion,
      'optionalDependencies': {
        '@sesori/bridge-darwin-arm64': oldVersion,
        '@sesori/bridge-darwin-x64': oldVersion,
        '@sesori/bridge-linux-x64': oldVersion,
        '@sesori/bridge-linux-arm64': oldVersion,
        '@sesori/bridge-win32-x64': oldVersion,
        '@sesori/not-bridge': '4.5.6',
      },
    },
  );

  for (final package in _FixtureApp.platformPackages) {
    await _writeJsonFile(
      path: p.join(rootPath, 'npm', package, 'package.json'),
      json: {
        'name': '@sesori/${package.replaceFirst('sesori-bridge-', 'bridge-')}',
        'version': oldVersion,
      },
    );
  }

  final pubGet = await Process.run(
    'dart',
    ['pub', 'get', '--offline'],
    workingDirectory: rootPath,
  );
  if (pubGet.exitCode != 0) {
    fail('dart pub get failed: ${pubGet.stderr}');
  }

  return _FixtureApp(rootPath: rootPath, oldVersion: oldVersion);
}

Future<ProcessResult> _runTool({
  required _FixtureApp fixture,
  required List<String> args,
}) {
  return Process.run(
    'dart',
    ['run', 'tool/bump_version.dart', ...args],
    workingDirectory: fixture.rootPath,
  );
}

Future<Map<String, dynamic>> _readJson({required String path}) async {
  final content = await File(path).readAsString();
  return jsonDecode(content) as Map<String, dynamic>;
}

void main() {
  group('bump_version.dart', () {
    late _FixtureApp fixture;

    setUp(() async {
      fixture = await _createFixtureApp();
    });

    tearDown(() async {
      await Directory(fixture.rootPath).delete(recursive: true);
    });

    test('updates the real fixture app end to end', () async {
      final result = await _runTool(fixture: fixture, args: [fixture.newVersion]);

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('✓ Version bumped from ${fixture.oldVersion} to ${fixture.newVersion}'));
      expect(result.stdout, contains('8. npm/sesori-bridge-win32-x64/package.json'));

      final pubspec = await File(fixture.pubspecPath).readAsString();
      final versionDart = await File(fixture.versionDartPath).readAsString();
      final wrapperPackage = await _readJson(path: fixture.wrapperPackagePath);

      expect(pubspec, contains('version: ${fixture.newVersion}'));
      expect(pubspec, isNot(contains('version: ${fixture.oldVersion}')));
      expect(versionDart, equals("const String appVersion = '${fixture.newVersion}';\n"));
      expect(wrapperPackage['version'], equals(fixture.newVersion));

      final optionalDependencies = wrapperPackage['optionalDependencies'] as Map<String, dynamic>;
      expect(optionalDependencies['@sesori/bridge-darwin-arm64'], equals(fixture.newVersion));
      expect(optionalDependencies['@sesori/bridge-darwin-x64'], equals(fixture.newVersion));
      expect(optionalDependencies['@sesori/bridge-linux-x64'], equals(fixture.newVersion));
      expect(optionalDependencies['@sesori/bridge-linux-arm64'], equals(fixture.newVersion));
      expect(optionalDependencies['@sesori/bridge-win32-x64'], equals(fixture.newVersion));
      expect(optionalDependencies['@sesori/not-bridge'], equals('4.5.6'));

      for (final package in _FixtureApp.platformPackages) {
        final packageJson = await _readJson(
          path: p.join(fixture.rootPath, 'npm', package, 'package.json'),
        );
        expect(packageJson['version'], equals(fixture.newVersion), reason: 'failed for $package');
      }
    });

    test('rejects invalid semver and keeps fixture files unchanged', () async {
      final beforePubspec = await File(fixture.pubspecPath).readAsString();
      final beforeVersionDart = await File(fixture.versionDartPath).readAsString();
      final beforeWrapperPackage = await File(fixture.wrapperPackagePath).readAsString();

      final result = await _runTool(fixture: fixture, args: ['1.2']);

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('Error: Invalid version format "1.2"'));
      expect(await File(fixture.pubspecPath).readAsString(), equals(beforePubspec));
      expect(await File(fixture.versionDartPath).readAsString(), equals(beforeVersionDart));
      expect(await File(fixture.wrapperPackagePath).readAsString(), equals(beforeWrapperPackage));
    });
  });
}
