import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/scheduled_task_run_service.dart";

/// Fires due tasks at start, which catches up on runs missed while the bridge
/// was off, and then 30 seconds after each pass. A wake from sleep is caught
/// by the next pass comparing wall-clock time.
class ScheduledTaskTimerListener({required final ScheduledTaskRunService _service}) {
  Timer? _timer;
  Future<void>? _tick;
  bool _disposed = false;

  void start() {
    _tick = _run();
  }

  Future<void> _run() async {
    try {
      await _service.runDue();
    } on Object catch (error, stackTrace) {
      Log.w("Scheduled task timer failed", error, stackTrace);
    } finally {
      if (!_disposed) {
        _timer = Timer(const Duration(seconds: 30), () {
          _tick = _run();
        });
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _tick;
  }
}
