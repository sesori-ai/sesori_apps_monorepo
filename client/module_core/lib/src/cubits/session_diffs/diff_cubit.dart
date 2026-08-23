import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../repositories/session_repository.dart";
import "../../services/loaded_state_analytics_reporter.dart";
import "diff_state.dart";

class DiffCubit({
  required final SessionRepository _sessionRepository,
  required final ConnectionService _connectionService,
  required final LoadedStateAnalyticsReporter _loadedStateAnalyticsReporter,
  required final String sessionId,
  required final Duration staleRetryDelay,
}) extends Cubit<DiffState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<void>? _activeRefresh;
  Timer? _staleRetryTimer;
  bool _refreshQueued = false;
  bool _queuedShowLoading = false;
  bool _staleRefreshPending = false;

  this : super(const DiffState.loading()) {
    _subscriptions.add(_connectionService.sessionEvents(sessionId).listen(_handleEvent));
    unawaited(_refresh(showLoading: false));
  }

  void _handleEvent(SesoriSessionEvent event) {
    if (event is! SesoriSessionDiff) return;
    _staleRefreshPending = true;
    unawaited(_refresh(showLoading: false));
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Re-fetches diffs from the server.
  Future<void> refresh() => _refresh(showLoading: true);

  Future<void> _refresh({required bool showLoading}) {
    final active = _activeRefresh;
    if (active != null) {
      _refreshQueued = true;
      _queuedShowLoading = _queuedShowLoading || showLoading;
      return active;
    }
    _staleRetryTimer?.cancel();
    _staleRetryTimer = null;
    return _activeRefresh = _drainRefreshes(showLoading: showLoading);
  }

  Future<void> _drainRefreshes({required bool showLoading}) async {
    var nextShowLoading = showLoading;
    try {
      do {
        final consumedStaleSignal = _staleRefreshPending;
        _staleRefreshPending = false;
        _refreshQueued = false;
        _queuedShowLoading = false;
        final applied = await _fetchAndEmit(showLoading: nextShowLoading);
        nextShowLoading = _queuedShowLoading;
        if (!applied && consumedStaleSignal) {
          _staleRefreshPending = true;
          break;
        }
      } while (_refreshQueued && !isClosed);
    } finally {
      _activeRefresh = null;
    }
    if (_staleRefreshPending) _scheduleStaleRetry(showLoading: nextShowLoading);
  }

  void _scheduleStaleRetry({required bool showLoading}) {
    if (isClosed || _staleRetryTimer != null) return;
    _staleRetryTimer = Timer(staleRetryDelay, () {
      _staleRetryTimer = null;
      if (isClosed || !_staleRefreshPending) return;
      unawaited(_refresh(showLoading: showLoading));
    });
  }

  Future<bool> _fetchAndEmit({required bool showLoading}) async {
    if (showLoading) {
      _loadedStateAnalyticsReporter.clearCurrentOccurrence();
      emit(const DiffState.loading());
    }
    try {
      final response = await _sessionRepository.getSessionDiffs(sessionId: sessionId);
      if (isClosed) return false;

      switch (response) {
        case SuccessResponse(:final data):
          emit(DiffState.loaded(files: data.diffs));
          _loadedStateAnalyticsReporter.reportLoaded(
            isEmpty: data.diffs.isEmpty,
            occurredAtUtc: DateTime.now().toUtc(),
          );
          return true;
        case ErrorResponse(:final error):
          _loadedStateAnalyticsReporter.clearCurrentOccurrence();
          emit(DiffState.failed(error: error));
          return false;
      }
    } catch (e) {
      if (isClosed) return false;
      _loadedStateAnalyticsReporter.clearCurrentOccurrence();
      emit(DiffState.failed(error: e));
      return false;
    }
  }

  @override
  Future<void> close() async {
    _staleRetryTimer?.cancel();
    await _subscriptions.dispose();
    await _loadedStateAnalyticsReporter.close();
    return await super.close();
  }
}
