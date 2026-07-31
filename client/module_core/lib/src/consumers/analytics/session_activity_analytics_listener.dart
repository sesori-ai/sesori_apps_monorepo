import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../cubits/session_detail/session_detail_cubit.dart";
import "../../cubits/session_detail/session_detail_state.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../services/models/product_analytics_state.dart";
import "../../services/product_analytics_service.dart";

enum _ActivityAnalyticsGuard { ready, inFlight, consumed }

/// Reports bounded session activity only while its owning detail route is
/// current and the app is foregrounded.
///
/// Route visibility is supplied by the Flutter owner so this pure-Dart
/// listener never mistakes a covered detail route for the active route.
class SessionActivityAnalyticsListener {
  final SessionDetailCubit _sessionDetailCubit;
  final LifecycleSource _lifecycleSource;
  final ProductAnalyticsService _productAnalyticsService;
  final DateTime Function() _nowUtc;

  late final StreamSubscription<SessionDetailState> _sessionStateSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  late final StreamSubscription<ProductAnalyticsState> _analyticsStateSubscription;

  bool _routeVisible;
  bool _disposed = false;
  _ActivityAnalyticsGuard _emptyGuard = _ActivityAnalyticsGuard.ready;
  bool _nonEmptyInFlight = false;
  DateTime? _consumedNonEmptyDateUtc;

  SessionActivityAnalyticsListener({
    required SessionDetailCubit sessionDetailCubit,
    required LifecycleSource lifecycleSource,
    required ProductAnalyticsService productAnalyticsService,
    required bool initialRouteVisible,
  }) : this._(
         sessionDetailCubit: sessionDetailCubit,
         lifecycleSource: lifecycleSource,
         productAnalyticsService: productAnalyticsService,
         initialRouteVisible: initialRouteVisible,
         nowUtc: _systemNowUtc,
       );

  @visibleForTesting
  SessionActivityAnalyticsListener.withClock({
    required SessionDetailCubit sessionDetailCubit,
    required LifecycleSource lifecycleSource,
    required ProductAnalyticsService productAnalyticsService,
    required bool initialRouteVisible,
    required DateTime Function() nowUtc,
  }) : this._(
         sessionDetailCubit: sessionDetailCubit,
         lifecycleSource: lifecycleSource,
         productAnalyticsService: productAnalyticsService,
         initialRouteVisible: initialRouteVisible,
         nowUtc: nowUtc,
       );

  SessionActivityAnalyticsListener._({
    required SessionDetailCubit sessionDetailCubit,
    required LifecycleSource lifecycleSource,
    required ProductAnalyticsService productAnalyticsService,
    required bool initialRouteVisible,
    required DateTime Function() nowUtc,
  }) : _sessionDetailCubit = sessionDetailCubit,
       _lifecycleSource = lifecycleSource,
       _productAnalyticsService = productAnalyticsService,
       _routeVisible = initialRouteVisible,
       _nowUtc = nowUtc {
    _sessionStateSubscription = _sessionDetailCubit.stream.listen((_) => _evaluateCurrentState());
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen((_) => _evaluateCurrentState());
    _analyticsStateSubscription = _productAnalyticsService.stateStream.listen((state) {
      if (state.isActive) _evaluateCurrentState();
    });
    _evaluateCurrentState();
  }

  static DateTime _systemNowUtc() => DateTime.now().toUtc();

  void setRouteVisible({required bool isVisible}) {
    if (_disposed || _routeVisible == isVisible) return;
    _routeVisible = isVisible;
    _evaluateCurrentState();
  }

  void _evaluateCurrentState() {
    if (_disposed || !_routeVisible || _lifecycleSource.lifecycleState != LifecycleState.resumed) return;
    final state = _sessionDetailCubit.state;
    if (state is! SessionDetailLoaded) return;

    final nowUtc = _nowUtc().toUtc();
    if (_hasActivity(state: state)) {
      _reportNonEmpty(occurredAtUtc: nowUtc);
    } else {
      _reportEmpty(occurredAtUtc: nowUtc);
    }
  }

  bool _hasActivity({required SessionDetailLoaded state}) =>
      state.messages.isNotEmpty ||
      state.pendingQuestions.isNotEmpty ||
      state.pendingPermissions.isNotEmpty ||
      state.sessionStatus is SessionStatusBusy ||
      state.sessionStatus is SessionStatusRetry ||
      state.childStatuses.values.any((status) => status is SessionStatusBusy || status is SessionStatusRetry);

  void _reportEmpty({required DateTime occurredAtUtc}) {
    if (_emptyGuard != _ActivityAnalyticsGuard.ready) return;
    _emptyGuard = _ActivityAnalyticsGuard.inFlight;
    unawaited(
      _deliverEmpty(
        occurredAtUtc: occurredAtUtc,
        attemptedWhileActive: _productAnalyticsService.state.isActive,
      ),
    );
  }

  Future<void> _deliverEmpty({
    required DateTime occurredAtUtc,
    required bool attemptedWhileActive,
  }) async {
    try {
      final result = await _productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.empty,
        ),
        occurredAtUtc: occurredAtUtc,
      );
      if (_disposed) return;
      if (result == AnalyticsDeliveryResult.acceptedBySdk) {
        _emptyGuard = _ActivityAnalyticsGuard.consumed;
      } else {
        _emptyGuard = _ActivityAnalyticsGuard.ready;
        final isActive = _productAnalyticsService.state.isActive;
        if (isActive) {
          logw("Failed to deliver empty session activity analytics event");
        }
        if (!attemptedWhileActive && isActive) _evaluateCurrentState();
      }
    } on Object catch (error, stackTrace) {
      if (!_disposed) _emptyGuard = _ActivityAnalyticsGuard.ready;
      logw("Failed to report empty session activity analytics event", error, stackTrace);
      if (!_disposed && !attemptedWhileActive && _productAnalyticsService.state.isActive) {
        _evaluateCurrentState();
      }
    }
  }

  void _reportNonEmpty({required DateTime occurredAtUtc}) {
    final dateUtc = DateTime.utc(occurredAtUtc.year, occurredAtUtc.month, occurredAtUtc.day);
    final consumedDateUtc = _consumedNonEmptyDateUtc;
    if (_nonEmptyInFlight || (consumedDateUtc != null && !dateUtc.isAfter(consumedDateUtc))) return;
    _nonEmptyInFlight = true;
    unawaited(_deliverNonEmpty(occurredAtUtc: occurredAtUtc, dateUtc: dateUtc));
  }

  Future<void> _deliverNonEmpty({required DateTime occurredAtUtc, required DateTime dateUtc}) async {
    try {
      final result = await _productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.nonEmpty,
        ),
        occurredAtUtc: occurredAtUtc,
      );
      if (_disposed) return;
      if (result == AnalyticsDeliveryResult.acceptedBySdk ||
          result == AnalyticsDeliveryResult.deferredUntilPreference) {
        _consumedNonEmptyDateUtc = dateUtc;
      } else if (_productAnalyticsService.state.isActive) {
        logw("Failed to deliver non-empty session activity analytics event");
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to report non-empty session activity analytics event", error, stackTrace);
    } finally {
      _nonEmptyInFlight = false;
      if (!_disposed && _consumedNonEmptyDateUtc == dateUtc) {
        final nowUtc = _nowUtc().toUtc();
        final currentDateUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
        if (currentDateUtc != dateUtc) _evaluateCurrentState();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      _sessionStateSubscription.cancel(),
      _lifecycleSubscription.cancel(),
      _analyticsStateSubscription.cancel(),
    ]);
  }
}
