import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/session_wake_up_service.dart";

/// Fires due wake-ups once at start, so those that came due while the bridge
/// was off fire on its return, and then every 30 seconds.
class SessionWakeUpTimerListener({required final SessionWakeUpService _service}) {
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
      Log.w("Wake-up timer failed", error, stackTrace);
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
