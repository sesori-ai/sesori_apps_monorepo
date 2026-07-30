import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../cubits/session_detail/session_detail_cubit.dart";
import "../../cubits/session_detail/session_detail_state.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/route_source.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../routing/app_routes.dart";
import "../../services/product_analytics_service.dart";

/// Reports bounded session activity only while its detail screen is actually
/// visible and the app is foregrounded.
final class SessionActivityAnalyticsConsumer {
  final SessionDetailCubit _sessionDetailCubit;
  final RouteSource _routeSource;
  final LifecycleSource _lifecycleSource;
  final ProductAnalyticsService _productAnalyticsService;
  final DateTime Function() _now;
  late final StreamSubscription<SessionDetailState> _sessionStateSubscription;
  late final StreamSubscription<AppRouteDef?> _routeSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  bool _emptyConsumed = false;
  DateTime? _lastNonEmptyUtcDate;
  bool _evaluationInFlight = false;
  bool _evaluateAgain = false;
  bool _disposed = false;

  SessionActivityAnalyticsConsumer({
    required SessionDetailCubit sessionDetailCubit,
    required RouteSource routeSource,
    required LifecycleSource lifecycleSource,
    required ProductAnalyticsService productAnalyticsService,
  }) : _sessionDetailCubit = sessionDetailCubit,
       _routeSource = routeSource,
       _lifecycleSource = lifecycleSource,
       _productAnalyticsService = productAnalyticsService,
       _now = DateTime.now {
    _start();
  }

  @visibleForTesting
  SessionActivityAnalyticsConsumer.withClock({
    required SessionDetailCubit sessionDetailCubit,
    required RouteSource routeSource,
    required LifecycleSource lifecycleSource,
    required ProductAnalyticsService productAnalyticsService,
    required DateTime Function() now,
  }) : _sessionDetailCubit = sessionDetailCubit,
       _routeSource = routeSource,
       _lifecycleSource = lifecycleSource,
       _productAnalyticsService = productAnalyticsService,
       _now = now {
    _start();
  }

  void _start() {
    _sessionStateSubscription = _sessionDetailCubit.stream.listen((_) => _scheduleEvaluation());
    _routeSubscription = _routeSource.currentRouteStream.listen((_) => _scheduleEvaluation());
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen((_) => _scheduleEvaluation());
    _scheduleEvaluation();
  }

  void _scheduleEvaluation() {
    if (_disposed) return;
    if (_evaluationInFlight) {
      _evaluateAgain = true;
      return;
    }
    _evaluationInFlight = true;
    unawaited(_runEvaluation());
  }

  Future<void> _runEvaluation() async {
    try {
      await _evaluate();
    } on Object catch (error, stackTrace) {
      logw("Failed to report session activity analytics", error, stackTrace);
    } finally {
      _evaluationInFlight = false;
      if (_evaluateAgain && !_disposed) {
        _evaluateAgain = false;
        _scheduleEvaluation();
      }
    }
  }

  Future<void> _evaluate() async {
    if (_routeSource.currentRoute != AppRouteDef.sessionDetail ||
        _lifecycleSource.lifecycleState != LifecycleState.resumed) {
      return;
    }

    final state = _sessionDetailCubit.state;
    if (state is! SessionDetailLoaded) return;

    final activityState = _activityState(state: state);
    final occurredAtUtc = _now().toUtc();
    final utcDate = DateTime.utc(occurredAtUtc.year, occurredAtUtc.month, occurredAtUtc.day);
    switch (activityState) {
      case AnalyticsActivityState.empty:
        if (_emptyConsumed) return;
      case AnalyticsActivityState.nonEmpty:
        if (_lastNonEmptyUtcDate == utcDate) return;
    }

    final result = await _productAnalyticsService.logEvent(
      event: ProductAnalyticsEvent.sessionActivityViewed(activityState: activityState),
      occurredAtUtc: occurredAtUtc,
    );
    if (result != AnalyticsDeliveryResult.acceptedBySdk && result != AnalyticsDeliveryResult.deferredUntilPreference) {
      return;
    }

    switch (activityState) {
      case AnalyticsActivityState.empty:
        _emptyConsumed = true;
      case AnalyticsActivityState.nonEmpty:
        _lastNonEmptyUtcDate = utcDate;
    }
  }

  AnalyticsActivityState _activityState({required SessionDetailLoaded state}) {
    final hasActiveStatus = switch (state.sessionStatus) {
      SessionStatusBusy() || SessionStatusRetry() => true,
      SessionStatusIdle() => false,
    };
    return state.messages.isNotEmpty ||
            state.pendingQuestions.isNotEmpty ||
            state.pendingPermissions.isNotEmpty ||
            hasActiveStatus
        ? AnalyticsActivityState.nonEmpty
        : AnalyticsActivityState.empty;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      _sessionStateSubscription.cancel(),
      _routeSubscription.cancel(),
      _lifecycleSubscription.cancel(),
    ]);
  }
}
