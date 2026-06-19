import 'package:sesori_bridge/src/updater/foundation/update_policy.dart';
import 'package:test/test.dart';

void main() {
  group('unsupportedPackageRuntimeMessage', () {
    test('returns null for managed executable path', () {
      expect(
        unsupportedPackageRuntimeMessage(
          executablePath: '/Users/alex/.local/share/sesori/bin/sesori-bridge',
          managedExecutablePath: '/Users/alex/.local/share/sesori/bin/sesori-bridge',
        ),
        isNull,
      );
    });

    test('returns null for non-npm unmanaged executable path', () {
      expect(
        unsupportedPackageRuntimeMessage(
          executablePath: '/tmp/custom/sesori-bridge',
          managedExecutablePath: '/Users/alex/.local/share/sesori/bin/sesori-bridge',
        ),
        isNull,
      );
    });

    test('returns guidance for direct npm-owned payload execution', () {
      final message = unsupportedPackageRuntimeMessage(
        executablePath: '/tmp/project/node_modules/@sesori/bridge-linux-x64/lib/runtime/bin/sesori-bridge',
        managedExecutablePath: '/Users/alex/.local/share/sesori/bin/sesori-bridge',
      );

      expect(message, isNotNull);
      expect(message, contains('Direct execution from npm-owned package payloads is unsupported'));
      expect(message, contains('Run `npx @sesori/bridge`'));
      expect(message, contains('`sesori-bridge` from your PATH'));
    });
  });

  group('shouldSkipUpdates', () {
    const managed = '/Users/alex/.local/share/sesori/bin/sesori-bridge';

    test('false for the managed binary in a normal environment', () {
      expect(
        shouldSkipUpdates(
          environment: const <String, String>{},
          executablePath: managed,
          managedExecutablePath: managed,
        ),
        isFalse,
      );
    });

    test('true when this is not the managed binary', () {
      expect(
        shouldSkipUpdates(
          environment: const <String, String>{},
          executablePath: '/tmp/custom/sesori-bridge',
          managedExecutablePath: managed,
        ),
        isTrue,
      );
    });

    test('true for an npm-owned payload', () {
      expect(
        shouldSkipUpdates(
          environment: const <String, String>{},
          executablePath: '/tmp/project/node_modules/@sesori/bridge-linux-x64/lib/runtime/bin/sesori-bridge',
          managedExecutablePath: managed,
        ),
        isTrue,
      );
    });

    test('true when updates are disabled or running in CI', () {
      expect(
        shouldSkipUpdates(
          environment: const <String, String>{'SESORI_NO_UPDATE': '1'},
          executablePath: managed,
          managedExecutablePath: managed,
        ),
        isTrue,
      );
      expect(
        shouldSkipUpdates(
          environment: const <String, String>{'CI': 'true'},
          executablePath: managed,
          managedExecutablePath: managed,
        ),
        isTrue,
      );
    });
  });
}
