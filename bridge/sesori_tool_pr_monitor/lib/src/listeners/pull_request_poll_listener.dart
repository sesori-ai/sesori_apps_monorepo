import "dart:async";

import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../services/pull_request_watch_service.dart";

/// Polls the due PRs once at start and then every 30 seconds, while the user
/// has the group on. Watches stay stored while it is off and resume with it.
///
/// The app shows watches only while the group is on, so turning it off
/// republishes their sessions at once, and turning it on polls first, so
/// they come back with fresh statuses.
class PullRequestPollListener({
  required final PullRequestWatchService _service,
  required final SesoriToolHost _host,
}) {
  static const Duration tick = Duration(seconds: 30);

  Timer? _timer;
  Future<void>? _tick;
  StreamSubscription<bool>? _enabledChanges;
  bool _disposed = false;

  void start() {
    _enabledChanges = _host.enabledChanges.listen(_onEnabledChanged);
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

  /// Runs after any tick in flight, so polls never overlap. While the group
  /// is off no tick is due; turning it on polls and restarts the ticks.
  void _onEnabledChanged(bool enabled) {
    final previous = _tick;
    _tick = () async {
      await previous;
      _timer?.cancel();
      if (_disposed) return;
      if (enabled) await _run();
      try {
        await _service.announceAll();
      } on Object catch (error, stackTrace) {
        Log.w("PR monitor: could not republish watched sessions", error, stackTrace);
      }
    }();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _enabledChanges?.cancel();
    _timer?.cancel();
    await _tick;
  }
}
