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
      }
    });
  });
}
