import "dart:async";

import "package:bloc/bloc.dart";
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
    required SessionRepository sessionRepository,
    required ConnectionService connectionService,
    required ProductAnalyticsService productAnalyticsService,
    required this.sessionId,
  }) extends Cubit<DiffState> {
  final SessionRepository _sessionRepository;
  final ConnectionService _connectionService;
  final ProductAnalyticsService _productAnalyticsService;
  final String sessionId;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<bool> _analyticsStateSubscription;
  Future<void>? _activeRefresh;
  _DiffAnalyticsGuard _emptyDiffAnalytics = _DiffAnalyticsGuard.ready;
  _DiffAnalyticsGuard _nonEmptyDiffAnalytics = _DiffAnalyticsGuard.ready;

  this : _sessionRepository = sessionRepository,
       _connectionService = connectionService,
       _productAnalyticsService = productAnalyticsService,
       super(const DiffState.loading()) {
    _eventSubscription = _connectionService.sessionEvents(sessionId).listen(_handleEvent);
    _analyticsStateSubscription = _productAnalyticsService.stateStream
        .map((state) => state.isActive)
        .distinct()
        .where((isActive) => isActive)
        .listen((_) => _retryCurrentDiffAnalytics());
    unawaited(_refresh(showLoading: false));
  }

  void _handleEvent(SesoriSessionEvent event) {
    if (event is! SesoriSessionDiff) return;
    unawaited(_refresh(showLoading: false));
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Re-fetches diffs from the server.
  Future<void> refresh() => _refresh(showLoading: true);

  Future<void> _refresh({required bool showLoading}) {
    final queued = (_activeRefresh ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => _fetchAndEmit(showLoading: showLoading));
    _activeRefresh = queued;
    return queued;
  }

  Future<void> _fetchAndEmit({required bool showLoading}) async {
    if (showLoading) {
      emit(const DiffState.loading());
    }
    try {
      final response = await _sessionRepository.getSessionDiffs(sessionId: sessionId);
      if (isClosed) return;

      switch (response) {
        case SuccessResponse(:final data):
          emit(DiffState.loaded(files: data.diffs));
          _reportDiffLoaded(isEmpty: data.diffs.isEmpty);
        case ErrorResponse(:final error):
          emit(DiffState.failed(error: error));
      }
    } catch (e) {
      if (isClosed) return;
      emit(DiffState.failed(error: e));
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
    await Future.wait([
      _eventSubscription.cancel(),
      _analyticsStateSubscription.cancel(),
    ]);
    return super.close();
  }
}
