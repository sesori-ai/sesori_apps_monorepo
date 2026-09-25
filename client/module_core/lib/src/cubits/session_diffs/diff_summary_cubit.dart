import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../logging/logging.dart";
import "../../repositories/models/session_diff_summary_result.dart";
import "../../repositories/session_repository.dart";
import "diff_summary_state.dart";

/// The session's line totals for the Changes label, refreshed when the
/// session's files change (at most once per [refreshInterval]), after a
/// reconnect, and when the connection reports that data may be stale.
class DiffSummaryCubit({
  required final SessionRepository _sessionRepository,
  required final ConnectionService _connectionService,
  required final String sessionId,
  required final Duration refreshInterval,
}) extends Cubit<DiffSummaryState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  /// The running refresh; a request that arrives meanwhile sets
  /// [_refreshQueued] and runs once after it, so an older response never
  /// replaces a newer one.
  Future<void>? _activeRefresh;
  bool _refreshQueued = false;

  this : super(const DiffSummaryState.unknown()) {
    _subscriptions
      ..add(
        _connectionService
            .sessionEvents(sessionId)
            .where((event) => event is SesoriSessionDiff)
            .throttleTime(refreshInterval, trailing: true)
            .listen((_) => _requestRefresh()),
      )
      ..add(
        _connectionService.status
            .map((status) => status is ConnectionConnected)
            .distinct()
            // The first value is the current status, not a reconnect.
            .skip(1)
            .where((isConnected) => isConnected)
            .listen((_) => _requestRefresh()),
      )
      ..add(_connectionService.dataMayBeStale.listen((_) => _requestRefresh()));
    _requestRefresh();
  }

  void _requestRefresh() {
    if (_activeRefresh != null) {
      _refreshQueued = true;
      return;
    }
    _activeRefresh = _drainRefreshes();
  }

  Future<void> _drainRefreshes() async {
    try {
      do {
        _refreshQueued = false;
        await _refresh();
      } while (_refreshQueued && !isClosed);
    } finally {
      _activeRefresh = null;
    }
  }

  Future<void> _refresh() async {
    final SessionDiffSummaryResult result;
    try {
      result = await _sessionRepository.getSessionDiffSummary(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      logw("Failed to load the session's change totals", error, stackTrace);
      return;
    }
    if (isClosed) return;
    switch (result) {
      case SessionDiffSummaryAvailable(:final additions, :final deletions):
        emit(DiffSummaryState.counts(additions: additions, deletions: deletions));
      case SessionDiffSummaryUnsupported():
        // An older bridge never learns the request; stop asking for this page.
        _refreshQueued = false;
        await _subscriptions.cancel();
      case SessionDiffSummaryFailure(:final error):
        // The last totals stay; the next signal refreshes them.
        logw("Failed to load the session's change totals", error);
    }
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    return await super.close();
  }
}
