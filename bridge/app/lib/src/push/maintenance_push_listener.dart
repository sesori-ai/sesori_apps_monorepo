import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "completion_notifier.dart";
import "push_rate_limiter.dart";
import "push_session_state_tracker.dart";

class MaintenancePushListener({
  required final PushSessionStateTracker _tracker,
  required final CompletionNotifier _completionNotifier,
  required final PushRateLimiter _rateLimiter,
  final Duration _maintenanceInterval = const Duration(minutes: 10),
}) {
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(_maintenanceInterval, (_) => runNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void runNow() {
    final stopwatch = Stopwatch()..start();
    var prunedRootCount = 0;
    _runMaintenanceStep(
      label: "root-prune",
      action: () {
        for (final rootSessionId in _tracker.findPrunableRoots()) {
          _runMaintenanceStep(
            label: "root-prune:$rootSessionId",
            action: () {
              _completionNotifier.cleanupPrunedRootSubtree(
                rootSessionId: rootSessionId,
                prunedSessionIds: _tracker.pruneRootSubtree(rootSessionId: rootSessionId),
              );
              prunedRootCount += 1;
            },
          );
        }
      },
    );

    _runMaintenanceStep(label: "message-role-prune", action: _tracker.pruneMessageRoleMetadata);
    _runMaintenanceStep(label: "rate-limiter-prune", action: _rateLimiter.pruneStaleEntries);
    Log.d(
      "[push] maintenance: pruned $prunedRootCount idle roots; tracking ${_tracker.sessionCount} sessions, "
      "${_tracker.messageRoleCount} message roles, ${_rateLimiter.retainedKeyCount} rate-limit keys "
      "(${stopwatch.elapsedMilliseconds} ms)",
    );
  }

  void _runMaintenanceStep({required String label, required void Function() action}) {
    try {
      action();
    } catch (error, stackTrace) {
      Log.w("[push] maintenance step '$label' failed", error, stackTrace);
    }
  }
}
