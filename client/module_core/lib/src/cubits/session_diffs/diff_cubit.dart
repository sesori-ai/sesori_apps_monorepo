import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/session_repository.dart";
import "../../services/product_analytics_service.dart";
import "diff_state.dart";

enum _DiffAnalyticsGuard() { ready, inFlight, consumed }

class DiffCubit({
    required final SessionRepository _sessionRepository,
    required final ConnectionService _connectionService,
    required final ProductAnalyticsService _productAnalyticsService,
    required final String sessionId,
    required final Duration staleRetryDelay,
  }) extends Cubit<DiffState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<void>? _activeRefresh;
  Timer? _staleRetryTimer;
  bool _refreshQueued = false;
  bool _queuedShowLoading = false;
  bool _staleRefreshPending = false;
  _DiffAnalyticsGuard _emptyDiffAnalytics = _DiffAnalyticsGuard.ready;
  _DiffAnalyticsGuard _nonEmptyDiffAnalytics = _DiffAnalyticsGuard.ready;

  this : super(const DiffState.loading()) {
    _subscriptions
      ..add(_connectionService.sessionEvents(sessionId).listen(_handleEvent))
      ..add(
        _productAnalyticsService.stateStream
            .map((state) => state.isActive)
            .distinct()
            .where((isActive) => isActive)
            .listen((_) => _retryCurrentDiffAnalytics()),
      );
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
      emit(const DiffState.loading());
    }
    try {
      final response = await _sessionRepository.getSessionDiffs(sessionId: sessionId);
      if (isClosed) return false;

      switch (response) {
        case SuccessResponse(:final data):
          emit(DiffState.loaded(files: data.diffs));
          _reportDiffLoaded(isEmpty: data.diffs.isEmpty);
          return true;
        case ErrorResponse(:final error):
          emit(DiffState.failed(error: error));
          return false;
      }
    } catch (e) {
      if (isClosed) return false;
      emit(DiffState.failed(error: e));
      return false;
    }
  }

  void _retryCurrentDiffAnalytics() {
    if (isClosed) return;
    final current = state;
    if (current is DiffStateLoaded) {
      _reportDiffLoaded(isEmpty: current.files.isEmpty);
    }
  }

  void _reportDiffLoaded({required bool isEmpty}) {
    final guard = isEmpty ? _emptyDiffAnalytics : _nonEmptyDiffAnalytics;
    if (guard != _DiffAnalyticsGuard.ready) return;
    final attemptedWhileActive = _productAnalyticsService.state.isActive;
    if (isEmpty) {
      _emptyDiffAnalytics = _DiffAnalyticsGuard.inFlight;
    } else {
      _nonEmptyDiffAnalytics = _DiffAnalyticsGuard.inFlight;
    }

    unawaited(
      _productAnalyticsService
          .logEvent(
            event: ProductAnalyticsEvent.sessionDiffViewed(
              changeState: isEmpty ? AnalyticsChangeState.empty : AnalyticsChangeState.nonEmpty,
            ),
            occurredAtUtc: DateTime.now().toUtc(),
          )
          .then<void>((result) {
            final consumed =
                result == AnalyticsDeliveryResult.acceptedBySdk ||
                (!isEmpty && result == AnalyticsDeliveryResult.deferredUntilPreference);
            final next = consumed ? _DiffAnalyticsGuard.consumed : _DiffAnalyticsGuard.ready;
            if (isEmpty) {
              _emptyDiffAnalytics = next;
            } else {
              _nonEmptyDiffAnalytics = next;
            }
            final isActive = _productAnalyticsService.state.isActive;
            if (!consumed && isActive) {
              logw("Failed to deliver session diff analytics event");
            }
            if (!consumed && isEmpty && !attemptedWhileActive && isActive) {
              _retryCurrentDiffAnalytics();
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (isEmpty) {
              _emptyDiffAnalytics = _DiffAnalyticsGuard.ready;
            } else {
              _nonEmptyDiffAnalytics = _DiffAnalyticsGuard.ready;
            }
            logw("Failed to report session diff analytics event", error, stackTrace);
            if (isEmpty && !attemptedWhileActive && _productAnalyticsService.state.isActive) {
              _retryCurrentDiffAnalytics();
            }
          }),
    );
  }

  @override
  Future<void> close() async {
    _staleRetryTimer?.cancel();
    await _subscriptions.dispose();
    return await super.close();
  }
}
