import 'package:sesori_bridge/src/api/windows_wake_lock_api.dart';
import 'package:win32/win32.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsWakeLockApi', () {
    test('enable uses continuous and system required flags', () async {
      var observedFlags = EXECUTION_STATE(0);
      final warnings = <String>[];

      final api = WindowsWakeLockApi(
        executionStateSetter: (flags) {
          observedFlags = flags;
          return EXECUTION_STATE(1);
        },
        warningLogger: warnings.add,
      );

      await api.enable();

      expect(
        observedFlags,
        equals(ES_CONTINUOUS | ES_SYSTEM_REQUIRED),
      );
      expect(warnings, isEmpty);
    });

    test('disable uses continuous flag only', () async {
      var observedFlags = EXECUTION_STATE(0);
      final warnings = <String>[];

      final api = WindowsWakeLockApi(
        executionStateSetter: (flags) {
          observedFlags = flags;
          return EXECUTION_STATE(1);
        },
        warningLogger: warnings.add,
      );

      await api.disable();

      expect(observedFlags, equals(ES_CONTINUOUS));
      expect(warnings, isEmpty);
    });

    test('logs a warning when the Windows call fails', () async {
      final warnings = <String>[];

      final api = WindowsWakeLockApi(
        executionStateSetter: (_) => EXECUTION_STATE(0),
        warningLogger: warnings.add,
      );

      await api.enable();

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('SetThreadExecutionState(enable) failed'));
    });
  });
}
