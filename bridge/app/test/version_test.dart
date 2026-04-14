import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/version.dart';
import 'package:test/test.dart';

Future<Map<String, dynamic>> _readJson({required String path}) async {
  final content = await File(path).readAsString();
  return jsonDecode(content) as Map<String, dynamic>;
}

void main() {
  group('version', () {
    test('appVersion is not empty', () {
      expect(appVersion, isNotEmpty);
    });

    test('appVersion matches semver pattern', () {
      final semverRegex = RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$');
      expect(appVersion, matches(semverRegex));
    });

    test('appVersion matches pubspec and npm package versions', () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      final pubspecVersion = RegExp(r'^version:\s+(.+)$', multiLine: true).firstMatch(pubspec)!.group(1)!;

      expect(appVersion, equals(pubspecVersion));

      final wrapperPackage = await _readJson(
        path: p.join('npm', 'sesori-bridge', 'package.json'),
      );
      expect(wrapperPackage['version'], equals(appVersion));
      expect(
        wrapperPackage['description'],
        equals('Bootstrap launcher for the managed Sesori Bridge runtime'),
      );
      expect(
        wrapperPackage['sesoriBridge'],
        equals({
          'bootstrapOnly': true,
          'managedRuntimeOwner': false,
          'runtimeBundleSource': 'github-release-assets',
        }),
      );

      final optionalDependencies = wrapperPackage['optionalDependencies'] as Map<String, dynamic>;
      const packageDirs = <String, String>{
        '@sesori/bridge-darwin-arm64': 'sesori-bridge-darwin-arm64',
        '@sesori/bridge-darwin-x64': 'sesori-bridge-darwin-x64',
        '@sesori/bridge-linux-x64': 'sesori-bridge-linux-x64',
        '@sesori/bridge-linux-arm64': 'sesori-bridge-linux-arm64',
        '@sesori/bridge-win32-x64': 'sesori-bridge-win32-x64',
      };

      expect(optionalDependencies.keys, equals(packageDirs.keys));

      for (final entry in packageDirs.entries) {
        expect(optionalDependencies[entry.key], equals(appVersion));
        final package = await _readJson(path: p.join('npm', entry.value, 'package.json'));
        expect(package['name'], equals(entry.key));
        expect(package['version'], equals(appVersion));
        expect(package['description'], contains('Bootstrap payload for the managed Sesori Bridge runtime'));
        expect(package['files'], equals(['lib/runtime/']));
        expect(
          package['sesoriBridge'],
          equals({
            'bootstrapOnly': true,
            'managedRuntimeOwner': false,
            'releaseTag': 'bridge-v$appVersion',
            'releaseArtifact': {
              '@sesori/bridge-darwin-arm64': 'sesori-bridge-macos-arm64.tar.gz',
              '@sesori/bridge-darwin-x64': 'sesori-bridge-macos-x64.tar.gz',
              '@sesori/bridge-linux-x64': 'sesori-bridge-linux-x64.tar.gz',
              '@sesori/bridge-linux-arm64': 'sesori-bridge-linux-arm64.tar.gz',
              '@sesori/bridge-win32-x64': 'sesori-bridge-windows-x64.zip',
            }[entry.key],
            'runtimeBundlePath': 'lib/runtime',
          }),
        );
      }
    });
  });
}
