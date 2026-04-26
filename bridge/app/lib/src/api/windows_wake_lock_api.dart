import 'package:win32/win32.dart';

import 'wake_lock_client.dart';

typedef ExecutionStateSetter = EXECUTION_STATE Function(EXECUTION_STATE flags);
typedef WarningLogger = void Function(String message);

/// Windows wake lock implementation backed by `SetThreadExecutionState`.
class WindowsWakeLockApi implements WakeLockClient {
  WindowsWakeLockApi({
    required this.executionStateSetter,
    required this.warningLogger,
  });

  final ExecutionStateSetter executionStateSetter;
  final WarningLogger warningLogger;

  @override
  Future<void> enable() async {
    _setExecutionState(
      ES_CONTINUOUS | ES_SYSTEM_REQUIRED,
      action: 'enable',
    );
  }

  @override
  Future<void> disable() async {
    _setExecutionState(
      ES_CONTINUOUS,
      action: 'disable',
    );
  }

  void _setExecutionState(EXECUTION_STATE flags, {required String action}) {
    final result = executionStateSetter(flags);
    if (result == 0) {
      warningLogger('[wake-lock] SetThreadExecutionState($action) failed');
    }
  }
}
