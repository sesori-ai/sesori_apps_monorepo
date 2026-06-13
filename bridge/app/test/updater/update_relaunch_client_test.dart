import 'dart:io';

import 'package:sesori_bridge/src/bridge/foundation/post_update_restart_flag.dart';
import 'package:sesori_bridge/src/updater/foundation/update_relaunch_client.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateRelaunchClient', () {
    test('relaunchBinary passes post-update env flag and inheritStdio mode', () async {
      final calls =
          <({String executable, List<String> arguments, Map<String, String>? environment, ProcessStartMode mode})>[];
      final client = UpdateRelaunchClient(
        processStarter:
            (
              executable,
              arguments, {
              required Map<String, String>? environment,
              required ProcessStartMode mode,
            }) {
              calls.add((executable: executable, arguments: arguments, environment: environment, mode: mode));
              throw _TestAbort();
            },
      );

      await expectLater(
        client.relaunchBinary(binaryPath: '/bin/sesori-bridge', args: const <String>['run']),
        throwsA(isA<_TestAbort>()),
      );

      expect(calls, hasLength(1));
      expect(calls.single.executable, equals('/bin/sesori-bridge'));
      expect(calls.single.arguments, equals(<String>['run']));
      expect(calls.single.environment, equals(const <String, String>{sesoriPostUpdateRestartEnvVar: '1'}));
      expect(calls.single.mode, equals(ProcessStartMode.inheritStdio));
    });
  });
}

class _TestAbort implements Exception {}
