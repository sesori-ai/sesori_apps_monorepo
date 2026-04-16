import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "completion_notifier.dart";
import "push_maintenance_telemetry.dart";
import "push_rate_limiter.dart";
import "push_session_state_tracker.dart";

class PushMaintenanceLoop {
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  final PushRateLimiter _rateLimiter;
  final Duration _maintenanceInterval;
  final int? Function() _rssBytesReader;
  final void Function(String) _debugLogger;
  late final Timer _timer;
  PushMaintenanceTelemetrySnapshot? _lastSnapshot;

  PushMaintenanceLoop({
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushRateLimiter rateLimiter,
    Duration maintenanceInterval = const Duration(minutes: 10),
    int? Function()? rssBytesReader,
    void Function(String)? debugLogger,
  }) : _tracker = tracker,
       _completionNotifier = completionNotifier,
       _rateLimiter = rateLimiter,
       _maintenanceInterval = maintenanceInterval,
       _rssBytesReader = rssBytesReader ?? readCurrentRssBytes,
       _debugLogger = debugLogger ?? Log.d {
    _timer = Timer.periodic(_maintenanceInterval, (_) => runNow());
  }

  PushMaintenanceTelemetrySnapshot? get lastSnapshot => _lastSnapshot;

  void dispose() {
    _timer.cancel();
  }

  void runNow() {
    final prunableRoots = _tracker.findPrunableRoots();
    for (final prunableRoot in prunableRoots) {
      final prunedSubtree = _tracker.pruneRootSubtree(rootSessionId: prunableRoot.rootSessionId);
      _completionNotifier.cleanupPrunedRootSubtree(
        rootSessionId: prunableRoot.rootSessionId,
        prunedSessionIds: prunedSubtree.prunedSessionIds,
      );
    }

    _rateLimiter.pruneStaleEntries();

    final snapshot = buildPushMaintenanceTelemetrySnapshot(
      trackerSnapshot: _tracker.createTelemetrySnapshot(),
      completionNotifier: _completionNotifier,
      rateLimiter: _rateLimiter,
      rssBytes: _rssBytesReader(),
    );
    _lastSnapshot = snapshot;
    _debugLogger(snapshot.toLogMessage());
  }
}
