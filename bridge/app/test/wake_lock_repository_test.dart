import 'dart:io';

import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;
import 'package:test/test.dart';
import 'package:win32/win32.dart';

void main() {
  group('WakeLockRepository', () {
    test('tracks whether the wake lock holds while delegating to the client', () async {
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

      expect(repository.isHeld, isFalse);

      await repository.enable();
      expect(repository.isHeld, isTrue);

      await repository.disable();
      expect(repository.isHeld, isFalse);
      expect(flags, [ES_CONTINUOUS | ES_SYSTEM_REQUIRED, ES_CONTINUOUS]);
    });

    test('reports the wake lock as not held when the system refuses it', () async {
      final repository = WakeLockRepository(
        client: WakeLockClient.forPlatform(
          platform: PlatformOs.windows,
          processStarter: Process.start,
          executionStateSetter: (_) => const EXECUTION_STATE(0),
          warningLogger: (_, [_, _]) {},
        ),
      );

      await repository.enable();

      expect(repository.isHeld, isFalse);
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
