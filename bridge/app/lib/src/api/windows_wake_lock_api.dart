import 'wake_lock_client.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:win32/win32.dart';

typedef ExecutionStateSetter = EXECUTION_STATE Function(EXECUTION_STATE flags);
typedef WarningLogger = void Function(String message);

/// Windows wake lock implementation backed by `SetThreadExecutionState`.
class WindowsWakeLockApi implements WakeLockClient {
  WindowsWakeLockApi({
    this.executionStateSetter = SetThreadExecutionState,
    this.warningLogger = Log.w,
  });

  final ExecutionStateSetter executionStateSetter;
  final WarningLogger warningLogger;

  @override
  Future<void> enable() async {
    _setExecutionState(
      ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED,
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
