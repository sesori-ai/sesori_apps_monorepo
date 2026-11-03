import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show bridgeVersion;
import 'package:test/test.dart';

Future<Map<String, dynamic>> _readJson({required String path}) async {
  final content = await File(path).readAsString();
  return jsonDecode(content) as Map<String, dynamic>;
}

void main() {
  group('version', () {
    test('bridgeVersion is not empty', () {
      expect(bridgeVersion, isNotEmpty);
    });

    test('bridgeVersion matches semver pattern', () {
      final semverRegex = RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$');
      expect(bridgeVersion, matches(semverRegex));
    });

    test('bridgeVersion matches pubspec and npm package versions', () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      final pubspecVersion =
          RegExp(r'^version:\s+(.+)$', multiLine: true).firstMatch(pubspec)?.group(1) ??
          fail('pubspec.yaml has no version');

      expect(bridgeVersion, equals(pubspecVersion));

      final wrapperPackage = await _readJson(
        path: p.join('npm', 'sesori-bridge', 'package.json'),
      );
      expect(wrapperPackage['version'], equals(bridgeVersion));
      expect(
        wrapperPackage['description'],
        equals('Bootstrap launcher for the managed Sesori Bridge runtime'),
      );
      expect(
        wrapperPackage['sesoriBridge'],
        equals({
          'bootstrapOnly': true,
          'managedRuntimeOwner': false,
          'releaseTag': 'v$bridgeVersion',
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
        '@sesori/bridge-win32-arm64': 'sesori-bridge-win32-arm64',
      };

      expect(optionalDependencies.keys, equals(packageDirs.keys));

      for (final entry in packageDirs.entries) {
        expect(optionalDependencies[entry.key], equals(bridgeVersion));
        final package = await _readJson(path: p.join('npm', entry.value, 'package.json'));
        expect(package['name'], equals(entry.key));
        expect(package['version'], equals(bridgeVersion));
        expect(package['description'], contains('Bootstrap payload for the managed Sesori Bridge runtime'));
        expect(package['files'], equals(['lib/runtime/']));
        expect(
          package['sesoriBridge'],
          equals({
            'bootstrapOnly': true,
            'managedRuntimeOwner': false,
            'releaseTag': 'v$bridgeVersion',
            'releaseArtifact': {
              '@sesori/bridge-darwin-arm64': 'sesori-bridge-macos-arm64.tar.gz',
              '@sesori/bridge-darwin-x64': 'sesori-bridge-macos-x64.tar.gz',
              '@sesori/bridge-linux-x64': 'sesori-bridge-linux-x64.tar.gz',
              '@sesori/bridge-linux-arm64': 'sesori-bridge-linux-arm64.tar.gz',
              '@sesori/bridge-win32-x64': 'sesori-bridge-windows-x64.zip',
              '@sesori/bridge-win32-arm64': 'sesori-bridge-windows-arm64.zip',
            }[entry.key],
            'runtimeBundlePath': 'lib/runtime',
          }),
        );
      }
    });
  });
}
