import 'dart:io';

import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:test/test.dart';

void main() {
  test('internal browser mode is recognized only as the first argument', () {
    expect(BrowserNoop.matches(arguments: []), isFalse);
    expect(BrowserNoop.matches(arguments: ['run', BrowserNoop.argument]), isFalse);
    expect(BrowserNoop.matches(arguments: [BrowserNoop.argument]), isTrue);
  });

  for (final explicitPackages in [false, true]) {
    test('actual source entrypoint exits silently with explicit packages: $explicitPackages', () async {
      final temp = Directory.systemTemp.createTempSync('browser-noop-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          if (explicitPackages) '--packages=${File('../.dart_tool/package_config.json').absolute.path}',
          File('bin/bridge.dart').absolute.path,
          BrowserNoop.argument,
          'https://example.invalid/synthetic?code=not-a-credential',
          '--deliberately-invalid-option',
        ],
        environment: {'HOME': temp.path, 'USERPROFILE': temp.path},
        includeParentEnvironment: false,
        workingDirectory: temp.path,
      ).timeout(const Duration(seconds: 45));
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
      expect(temp.listSync(), isEmpty);
    });
  }
}
