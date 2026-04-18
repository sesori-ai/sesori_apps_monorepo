import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "completion_notifier.dart";
import "push_maintenance_telemetry.dart";
import "push_rate_limiter.dart";
import "push_session_state_tracker.dart";

class MaintenancePushListener {
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  final PushRateLimiter _rateLimiter;
  final PushMaintenanceTelemetryBuilder _telemetryBuilder;
  final Duration _maintenanceInterval;
  Timer? _timer;
  PushMaintenanceTelemetrySnapshot? _lastMaintenanceTelemetry;

  MaintenancePushListener({
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushRateLimiter rateLimiter,
    required PushMaintenanceTelemetryBuilder telemetryBuilder,
    Duration maintenanceInterval = const Duration(minutes: 10),
  }) : _tracker = tracker,
       _completionNotifier = completionNotifier,
       _rateLimiter = rateLimiter,
       _telemetryBuilder = telemetryBuilder,
       _maintenanceInterval = maintenanceInterval;

  @visibleForTesting
  bool get isStarted => _timer != null;

  @visibleForTesting
  PushMaintenanceTelemetrySnapshot? get lastMaintenanceTelemetry => _lastMaintenanceTelemetry;

  void start() {
    _timer ??= Timer.periodic(_maintenanceInterval, (_) => runNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void runNow() {
    _runMaintenanceStep(
      label: "root-prune",
      action: () {
        final prunableRoots = _tracker.findPrunableRoots();
        for (final prunableRoot in prunableRoots) {
          _runMaintenanceStep(
            label: "root-prune:${prunableRoot.rootSessionId}",
            action: () {
              final prunedSubtree = _tracker.pruneRootSubtree(rootSessionId: prunableRoot.rootSessionId);
              _completionNotifier.cleanupPrunedRootSubtree(
                rootSessionId: prunableRoot.rootSessionId,
                prunedSessionIds: prunedSubtree.prunedSessionIds,
              );
            },
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
        _lastMaintenanceTelemetry = snapshot;
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
