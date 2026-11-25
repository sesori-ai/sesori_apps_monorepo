import "dart:async";

import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../services/pull_request_watch_service.dart";

/// Polls the due PRs once at start and then every 30 seconds, while the user
/// has the group on. Watches stay stored while it is off and resume with it.
class PullRequestPollListener({
  required final PullRequestWatchService _service,
  required final SesoriToolHost _host,
}) {
  static const Duration tick = Duration(seconds: 30);

  Timer? _timer;
  Future<void>? _tick;
  bool _disposed = false;

  void start() {
    _tick = _run();
  }

  Future<void> _run() async {
    try {
      if (_host.enabled) await _service.pollDue();
    } on Object catch (error, stackTrace) {
      Log.w("PR monitor: poll tick failed", error, stackTrace);
    } finally {
      if (!_disposed) {
        _timer = Timer(tick, () {
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
