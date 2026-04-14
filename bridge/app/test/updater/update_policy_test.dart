import 'package:sesori_bridge/src/updater/foundation/update_policy.dart';
import 'package:test/test.dart';

void main() {
  group('unsupportedPackageRuntimeMessage', () {
    test('returns null for managed executable path', () {
      expect(
        unsupportedPackageRuntimeMessage(
          executablePath: '/Users/alex/.sesori/bin/sesori-bridge',
          managedExecutablePath: '/Users/alex/.sesori/bin/sesori-bridge',
        ),
        isNull,
      );
    });

    test('returns null for non-npm unmanaged executable path', () {
      expect(
        unsupportedPackageRuntimeMessage(
          executablePath: '/tmp/custom/sesori-bridge',
          managedExecutablePath: '/Users/alex/.sesori/bin/sesori-bridge',
        ),
        isNull,
      );
    });

    test('returns guidance for direct npm-owned payload execution', () {
      final message = unsupportedPackageRuntimeMessage(
        executablePath: '/tmp/project/node_modules/@sesori/bridge-linux-x64/lib/runtime/bin/sesori-bridge',
        managedExecutablePath: '/Users/alex/.sesori/bin/sesori-bridge',
      );

      expect(message, isNotNull);
      expect(message, contains('Direct execution from npm-owned package payloads is unsupported'));
      expect(message, contains('Run `npx @sesori/bridge`'));
      expect(message, contains('`sesori-bridge` from your PATH'));
    });
  });
}
