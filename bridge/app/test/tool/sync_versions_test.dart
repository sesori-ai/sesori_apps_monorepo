import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const List<String> _platformPackages = <String>[
  'sesori-bridge-darwin-arm64',
  'sesori-bridge-darwin-x64',
  'sesori-bridge-linux-arm64',
  'sesori-bridge-linux-x64',
  'sesori-bridge-win32-x64',
];

String _repoRoot() => p.normalize(p.join(Directory.current.path, '..', '..'));

String _toolSourcePath() => p.join(_repoRoot(), 'tool', 'sync_versions.dart');

Future<void> _writeJsonFile({
  required String path,
  required Map<String, dynamic> json,
}) async {
  final formatted = const JsonEncoder.withIndent('  ').convert(json);
  await File(path).writeAsString('$formatted\n');
}

class _FixtureApp {
  _FixtureApp({required this.rootPath});

  final String rootPath;

  String get mobilePubspecPath => p.join(rootPath, 'mobile', 'app', 'pubspec.yaml');
  String get bridgePubspecPath => p.join(rootPath, 'bridge', 'app', 'pubspec.yaml');
  String get bridgeVersionPath => p.join(rootPath, 'bridge', 'app', 'lib', 'src', 'version.dart');
  String get wrapperPackagePath => p.join(rootPath, 'bridge', 'app', 'npm', 'sesori-bridge', 'package.json');

  List<String> get packagePaths => _platformPackages
      .map((final package) => p.join(rootPath, 'bridge', 'app', 'npm', package, 'package.json'))
      .toList();
}

Future<_FixtureApp> _createFixtureApp({required String mobileVersion, String? bridgeVersion}) async {
  final tempDir = await Directory.systemTemp.createTemp('sync-versions-fixture-');
  final rootPath = tempDir.path;
  final resolvedBridgeVersion = bridgeVersion ?? mobileVersion.split('+').first;

  for (final relativeDir in <List<String>>[
    ['tool'],
    ['bridge', 'app', 'lib', 'src'],
    ['bridge', 'app', 'npm', 'sesori-bridge'],
    ['bridge', 'app', 'npm', 'sesori-bridge-darwin-arm64'],
    ['bridge', 'app', 'npm', 'sesori-bridge-darwin-x64'],
    ['bridge', 'app', 'npm', 'sesori-bridge-linux-arm64'],
    ['bridge', 'app', 'npm', 'sesori-bridge-linux-x64'],
    ['bridge', 'app', 'npm', 'sesori-bridge-win32-x64'],
    ['mobile', 'app'],
  ]) {
    await Directory(p.joinAll(<String>[rootPath, ...relativeDir])).create(recursive: true);
  }

  await File(p.join(rootPath, 'mobile', 'app', 'pubspec.yaml')).writeAsString('''
name: sync_versions_fixture
version: $mobileVersion
environment:
  sdk: ^3.11.0
''');

  await File(p.join(rootPath, 'bridge', 'app', 'pubspec.yaml')).writeAsString('''
name: sesori_bridge
version: $resolvedBridgeVersion
publish_to: none
resolution: workspace
''');

  await File(p.join(rootPath, 'bridge', 'app', 'lib', 'src', 'version.dart')).writeAsString(
    "const String appVersion = '$resolvedBridgeVersion';\n",
  );

  await _writeJsonFile(
    path: p.join(rootPath, 'bridge', 'app', 'npm', 'sesori-bridge', 'package.json'),
    json: <String, dynamic>{
      'name': '@sesori/bridge',
      'version': resolvedBridgeVersion,
      'optionalDependencies': <String, dynamic>{
        '@sesori/bridge-darwin-arm64': resolvedBridgeVersion,
        '@sesori/bridge-darwin-x64': resolvedBridgeVersion,
        '@sesori/bridge-linux-arm64': resolvedBridgeVersion,
        '@sesori/bridge-linux-x64': resolvedBridgeVersion,
        '@sesori/bridge-win32-x64': resolvedBridgeVersion,
        '@sesori/not-bridge': '4.5.6',
      },
      'sesoriBridge': <String, dynamic>{
        'releaseTag': 'v$resolvedBridgeVersion',
        'runtimeBundleSource': 'github-release-assets',
      },
    },
  );

  for (final package in _platformPackages) {
    await _writeJsonFile(
      path: p.join(rootPath, 'bridge', 'app', 'npm', package, 'package.json'),
      json: <String, dynamic>{
        'name': '@sesori/${package.replaceFirst('sesori-bridge-', 'bridge-')}',
        'version': resolvedBridgeVersion,
        'sesoriBridge': <String, dynamic>{
          'releaseTag': 'v$resolvedBridgeVersion',
        },
      },
    );
  }

  await File(p.join(rootPath, 'tool', 'sync_versions.dart')).writeAsString(
    await File(_toolSourcePath()).readAsString(),
  );

  return _FixtureApp(rootPath: rootPath);
}

Future<ProcessResult> _runTool({
  required _FixtureApp fixture,
  required List<String> args,
}) {
  return Process.run(
    'dart',
    <String>['tool/sync_versions.dart', ...args],
    workingDirectory: fixture.rootPath,
  );
}

Future<Map<String, dynamic>> _readJson({required String path}) async {
  return jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
}

void main() {
  group('sync_versions.dart', () {
    _FixtureApp? fixture;

    tearDown(() {
      final currentFixture = fixture;
      if (currentFixture != null && Directory(currentFixture.rootPath).existsSync()) {
        Directory(currentFixture.rootPath).deleteSync(recursive: true);
      }
      fixture = null;
    });

    test('dry-run computes patch, minor, and major targets without mutations', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6+8');
      final currentFixture = fixture!;
      final beforeBridgePubspec = await File(currentFixture.bridgePubspecPath).readAsString();
      final beforeMobilePubspec = await File(currentFixture.mobilePubspecPath).readAsString();
      final beforeWrapper = await File(currentFixture.wrapperPackagePath).readAsString();

      final patchResult = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--type', 'patch']);
      expect(patchResult.exitCode, equals(0), reason: '${patchResult.stdout}\n${patchResult.stderr}');
      expect(patchResult.stdout, contains('Target bridge version: 1.0.7'));
      expect(patchResult.stdout, contains('Target mobile version: 1.0.7+8'));
      expect(patchResult.stdout, contains('Planned releaseTag: v1.0.7'));
      expect(patchResult.stdout, contains('bridge/app/pubspec.yaml'));
      expect(patchResult.stdout, contains('mobile/app/pubspec.yaml'));
      expect(await File(currentFixture.bridgePubspecPath).readAsString(), equals(beforeBridgePubspec));
      expect(await File(currentFixture.mobilePubspecPath).readAsString(), equals(beforeMobilePubspec));
      expect(await File(currentFixture.wrapperPackagePath).readAsString(), equals(beforeWrapper));

      final minorResult = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--type=minor']);
      expect(minorResult.exitCode, equals(0));
      expect(minorResult.stdout, contains('Target bridge version: 1.1.0'));
      expect(minorResult.stdout, contains('Target mobile version: 1.1.0+8'));

      final majorResult = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--type=major']);
      expect(majorResult.exitCode, equals(0));
      expect(majorResult.stdout, contains('Target bridge version: 2.0.0'));
      expect(majorResult.stdout, contains('Target mobile version: 2.0.0+8'));
    });

    test('release-type sync preserves the mobile build suffix exactly', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6+8');
      final currentFixture = fixture!;

      final cases = <({String type, String bridgeVersion, String mobileVersion})>[
        (type: 'patch', bridgeVersion: '1.0.7', mobileVersion: '1.0.7+8'),
        (type: 'minor', bridgeVersion: '1.1.0', mobileVersion: '1.1.0+8'),
        (type: 'major', bridgeVersion: '2.0.0', mobileVersion: '2.0.0+8'),
      ];

      for (final testCase in cases) {
        await File(currentFixture.bridgePubspecPath).writeAsString('''
name: sesori_bridge
version: 1.0.6
publish_to: none
resolution: workspace
''');
        await File(currentFixture.bridgeVersionPath).writeAsString("const String appVersion = '1.0.6';\n");
        await File(currentFixture.mobilePubspecPath).writeAsString('''
name: sesori_mobile
version: 1.0.6+8
environment:
  sdk: ^3.11.0
''');
        await _writeJsonFile(
          path: currentFixture.wrapperPackagePath,
          json: <String, dynamic>{
            'name': '@sesori/bridge',
            'version': '1.0.6',
            'optionalDependencies': <String, dynamic>{
              '@sesori/bridge-darwin-arm64': '1.0.6',
              '@sesori/bridge-darwin-x64': '1.0.6',
              '@sesori/bridge-linux-arm64': '1.0.6',
              '@sesori/bridge-linux-x64': '1.0.6',
              '@sesori/bridge-win32-x64': '1.0.6',
              '@sesori/not-bridge': '4.5.6',
            },
        'sesoriBridge': <String, dynamic>{
          'releaseTag': 'v1.0.6',
          'runtimeBundleSource': 'github-release-assets',
        },
          },
        );
        for (final packagePath in currentFixture.packagePaths) {
          await _writeJsonFile(
            path: packagePath,
            json: <String, dynamic>{
              'name': '@sesori/${p.basename(p.dirname(packagePath)).replaceFirst('sesori-bridge-', 'bridge-')}',
              'version': '1.0.6',
              'sesoriBridge': <String, dynamic>{
              'releaseTag': 'v1.0.6',
            },
            },
          );
        }

        final result = await _runTool(fixture: currentFixture, args: <String>['--type', testCase.type]);

        expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');

        final bridgePubspec = await File(currentFixture.bridgePubspecPath).readAsString();
        final bridgeVersion = await File(currentFixture.bridgeVersionPath).readAsString();
        final mobilePubspec = await File(currentFixture.mobilePubspecPath).readAsString();
        final wrapperPackage = await _readJson(path: currentFixture.wrapperPackagePath);

        expect(bridgePubspec, contains('version: ${testCase.bridgeVersion}'));
        expect(bridgeVersion, equals("const String appVersion = '${testCase.bridgeVersion}';\n"));
        expect(mobilePubspec, contains('version: ${testCase.mobileVersion}'));
        expect(wrapperPackage['version'] as String, equals(testCase.bridgeVersion));
        expect((wrapperPackage['sesoriBridge'] as Map<String, dynamic>)['releaseTag'], equals('v${testCase.bridgeVersion}'));

        final optionalDependencies = wrapperPackage['optionalDependencies'] as Map<String, dynamic>;
        expect(optionalDependencies['@sesori/bridge-darwin-arm64'], equals(testCase.bridgeVersion));
        expect(optionalDependencies['@sesori/bridge-darwin-x64'], equals(testCase.bridgeVersion));
        expect(optionalDependencies['@sesori/bridge-linux-arm64'], equals(testCase.bridgeVersion));
        expect(optionalDependencies['@sesori/bridge-linux-x64'], equals(testCase.bridgeVersion));
        expect(optionalDependencies['@sesori/bridge-win32-x64'], equals(testCase.bridgeVersion));
        expect(optionalDependencies['@sesori/not-bridge'], equals('4.5.6'));

        for (final packagePath in currentFixture.packagePaths) {
          final package = await _readJson(path: packagePath);
          expect(package['version'], equals(testCase.bridgeVersion));
          expect((package['sesoriBridge'] as Map<String, dynamic>)['releaseTag'], equals('v${testCase.bridgeVersion}'));
        }
      }
    });

    test('rejects diverged bridge and mobile versions', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6+8', bridgeVersion: '1.0.5');
      final currentFixture = fixture!;

      final result = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--type', 'patch']);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('out of sync'));
    });

    test('allows explicit --version to realign diverged versions', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6+8', bridgeVersion: '1.0.5');
      final currentFixture = fixture!;

      final result = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--version', '1.0.7']);

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Target mobile version: 1.0.7+8'));
      expect(result.stdout, contains('Target bridge version: 1.0.7'));
    });

    test('works without mobile build number', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6');
      final currentFixture = fixture!;

      final result = await _runTool(fixture: currentFixture, args: <String>['--dry-run', '--type', 'patch']);

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Target mobile version: 1.0.7'));
    });

    test('rejects invalid inputs and malformed mobile versions', () async {
      fixture = await _createFixtureApp(mobileVersion: '1.0.6+8');
      final currentFixture = fixture!;

      final cases = <({List<String> args, String stderr})>[
        (args: <String>[], stderr: 'Error: Provide exactly one of --type or --version'),
        (
          args: <String>['--type', 'patch', '--version', '1.0.6'],
          stderr: 'Error: Provide exactly one of --type or --version',
        ),
        (args: <String>['--type', 'bogus'], stderr: 'Error: Invalid type "bogus"'),
        (args: <String>['--version', '1.0'], stderr: 'Error: Invalid semver "1.0"'),
      ];

      for (final testCase in cases) {
        final result = await _runTool(fixture: currentFixture, args: testCase.args);
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains(testCase.stderr));
      }

      for (final malformedVersion in <String>['1.2+8', '1.2.3+abc']) {
        fixture = await _createFixtureApp(mobileVersion: malformedVersion);
        final malformedResult = await _runTool(fixture: fixture!, args: <String>['--dry-run', '--type', 'patch']);
        expect(malformedResult.exitCode, isNot(0));
        expect(malformedResult.stderr, contains('Error: Invalid mobile version "$malformedVersion"'));
      }
    });
  });
}
