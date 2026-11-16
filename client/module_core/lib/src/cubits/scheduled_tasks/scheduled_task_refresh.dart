import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../logging/logging.dart";
import "../../repositories/models/scheduled_task_result.dart";

/// When the computer's tasks may have changed: the bridge says so, the
/// connection comes back, or it reports that data may be stale.
Stream<void> scheduledTaskRefreshSignals({required ConnectionService connectionService}) => MergeStream<void>([
  connectionService.events.where((event) => event.data is SesoriScheduledTasksChanged),
  connectionService.status
      .map((status) => status is ConnectionConnected)
      .distinct()
      // The first value is the current status, not a reconnect.
      .skip(1)
      .where((isConnected) => isConnected),
  connectionService.dataMayBeStale,
]);

/// Runs one refresh at a time. A request that arrives meanwhile runs once
/// after it, so an older response never replaces a newer one.
class ScheduledTaskRefreshDispatcher({required final Future<void> Function() _refresh}) {
  Future<void>? _active;
  bool _queued = false;

  /// Completes once the refresh this request asked for has run.
  Future<void> request() {
    final active = _active;
    if (active != null) {
      _queued = true;
      return active;
    }
    return _active = _drain();
  }

  Future<void> _drain() async {
    try {
      do {
        _queued = false;
        await _refresh();
      } while (_queued);
    } finally {
      _active = null;
    }
  }
}

/// Logs why a task request did not succeed, with the transport error itself
/// when there is one.
void logScheduledTaskFailure({required String message, required ScheduledTaskResult<Object?> result}) {
  switch (result) {
    case ScheduledTaskSuccess():
      return;
    case ScheduledTaskRefused(:final code):
      logw("$message: refused (${code.name})");
    case ScheduledTaskBridgeOutdated():
      logw("$message: the bridge predates scheduled tasks");
    case ScheduledTaskFailure(:final error):
      logw(message, error);
  }
}
