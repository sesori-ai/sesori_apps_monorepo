import 'dart:io';

import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;
import 'package:test/test.dart';
import 'package:win32/win32.dart';

void main() {
  group('WakeLockRepository', () {
    test('tracks enabled state while delegating to the client', () async {
      final flags = <EXECUTION_STATE>[];
      final repository = WakeLockRepository(
        client: WakeLockClient.forPlatform(
          platform: PlatformOs.windows,
          processStarter: Process.start,
          executionStateSetter: (flagsValue) {
            flags.add(flagsValue);
            return const EXECUTION_STATE(1);
          },
          warningLogger: (_, [_, _]) {},
        ),
      );

      expect(repository.isEnabled, isFalse);

      await repository.enable();
      expect(repository.isEnabled, isTrue);

      await repository.disable();
      expect(repository.isEnabled, isFalse);
      expect(flags, [ES_CONTINUOUS | ES_SYSTEM_REQUIRED, ES_CONTINUOUS]);
    });

    test('exposes preventsLidCloseSleep from the client', () {
      final repository = WakeLockRepository(
        client: WakeLockClient.forPlatform(
          platform: PlatformOs.windows,
          processStarter: Process.start,
          executionStateSetter: (_) => const EXECUTION_STATE(1),
          warningLogger: (_, [_, _]) {},
        ),
      );

      expect(repository.preventsLidCloseSleep, isFalse);
    });
  });
}
