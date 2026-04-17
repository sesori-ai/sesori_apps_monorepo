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
  final PushMaintenanceTelemetryBuilder _telemetryBuilder;
  late final Timer _timer;
  PushMaintenanceTelemetrySnapshot? _lastSnapshot;

  PushMaintenanceLoop({
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushRateLimiter rateLimiter,
    required PushMaintenanceTelemetryBuilder telemetryBuilder,
    Duration maintenanceInterval = const Duration(minutes: 10),
  }) : _tracker = tracker,
       _completionNotifier = completionNotifier,
       _rateLimiter = rateLimiter,
       _maintenanceInterval = maintenanceInterval,
       _telemetryBuilder = telemetryBuilder {
    _timer = Timer.periodic(_maintenanceInterval, (_) => runNow());
  }

  PushMaintenanceTelemetrySnapshot? get lastSnapshot => _lastSnapshot;

  void dispose() {
    _timer.cancel();
  }

  void runNow() {
    _runMaintenanceStep(
      label: "root-prune",
      action: () {
        final prunableRoots = _tracker.findPrunableRoots();
        for (final prunableRoot in prunableRoots) {
          final prunedSubtree = _tracker.pruneRootSubtree(rootSessionId: prunableRoot.rootSessionId);
          _completionNotifier.cleanupPrunedRootSubtree(
            rootSessionId: prunableRoot.rootSessionId,
            prunedSessionIds: prunedSubtree.prunedSessionIds,
          );
        }
      },
    );

    _runMaintenanceStep(label: "message-role-prune", action: _tracker.pruneMessageRoleMetadata);
    _runMaintenanceStep(label: "rate-limiter-prune", action: _rateLimiter.pruneStaleEntries);
    _runMaintenanceStep(
      label: "telemetry",
      action: () {
        final snapshot = _telemetryBuilder.build(
          trackerSnapshot: _tracker.createTelemetrySnapshot(),
        );
        _lastSnapshot = snapshot;
        Log.d(snapshot.toLogMessage());
      },
    );
  }

  void _runMaintenanceStep({required String label, required void Function() action}) {
    try {
      action();
    } catch (error, stackTrace) {
      Log.w("[push] maintenance step '$label' failed: $error\n$stackTrace");
    }
  }
}
