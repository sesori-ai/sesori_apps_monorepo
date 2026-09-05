import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_runtime_status_reporter.dart";

/// Bounded wait for a managed runtime's cold start (its first handshake).
///
/// A backend that passed its readiness probe but stalls the handshake must not
/// hang `start()` under the bridge's cross-instance startup mutex. The wait is
/// bounded by [budget]: within it, success reports connected and failure
/// reports degraded; past it, the plugin starts degraded while the cold start
/// keeps running in the background and a late failure is logged instead of
/// surfacing as an unhandled error. The descriptor still owns creating the API,
/// deciding whether to cold-start at all, and the abort check afterwards.
class const ManagedRuntimeColdStartService({
  required final Duration budget,
  required final String logTag,
}) {
  Future<void> run({
    required Future<void> coldStart,
    required ManagedRuntimeStatusReporter reporter,
  }) async {
    var budgetExceeded = false;
    // The sink keeps a post-budget failure from surfacing as an unhandled async
    // error once the await below has moved on; the awaited path observes (and
    // logs) every pre-budget failure itself.
    unawaited(
      coldStart.catchError((Object error, StackTrace stackTrace) {
        if (budgetExceeded) {
          Log.w("[$logTag] cold-start failed after the start budget", error, stackTrace);
        }
      }),
    );
    try {
      await coldStart.timeout(
        budget,
        onTimeout: () {
          budgetExceeded = true;
          Log.w(
            "[$logTag] cold-start did not finish within ${budget.inSeconds}s — "
            "starting degraded while it keeps running in the background",
          );
        },
      );
      if (budgetExceeded) {
        reporter.markDegradedNow();
      } else {
        reporter.markConnected();
      }
    } on Object catch (error, stackTrace) {
      Log.w("[$logTag] cold-start did not complete cleanly", error, stackTrace);
      reporter.markDegradedNow();
    }
  }
}
