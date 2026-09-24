import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/session_continuation_service.dart";

typedef ContinuationTimerFactory = Timer Function({required Duration delay, required void Function() callback});

class SessionContinuationTimerListener({
  required final SessionContinuationService _service,
  required final ContinuationTimerFactory _timerFactory,
}) {
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
      Log.w("Quota continuation timer failed", error, stackTrace);
    } finally {
      if (!_disposed) {
        _timer = _timerFactory(
          delay: const Duration(seconds: 30),
          callback: () {
            _tick = _run();
          },
        );
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _tick;
  }
}
