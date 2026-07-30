import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../logging/logging.dart";
import "../repositories/analytics_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "models/product_analytics_state.dart";
import "product_analytics_preference_service.dart";
import "product_analytics_schema_readiness_dispatcher.dart";

@lazySingleton
class ProductAnalyticsService {
  final AnalyticsRepository _analyticsRepository;
  final ProductAnalyticsPreferenceService _preferenceService;
  final ProductAnalyticsSchemaReadinessDispatcher _schemaReadiness = ProductAnalyticsSchemaReadinessDispatcher();

  StreamSubscription<ProductAnalyticsState>? _stateSubscription;
  Future<void>? _startFuture;
  bool _disposed = false;

  ProductAnalyticsService({
    required AnalyticsRepository analyticsRepository,
    required ProductAnalyticsPreferenceService preferenceService,
  }) : _analyticsRepository = analyticsRepository,
       _preferenceService = preferenceService;

  ValueStream<ProductAnalyticsState> get stateStream => _preferenceService.stateStream;
  ProductAnalyticsState get state => _preferenceService.state;

  Future<void> start() {
    if (_disposed) return Future<void>.value();
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    _stateSubscription = stateStream.listen((state) => _onPreferenceState(state: state));
    await _preferenceService.start();
  }

  Future<void> markPostSplashReady() => _preferenceService.markPostSplashReady();

  Future<void> refreshPreference() => _preferenceService.refreshPreference();

  Future<void> setPreference({required ProductAnalyticsPreference preference}) =>
      _preferenceService.setPreference(preference: preference);

  Future<void> retryPendingDisable() => _preferenceService.retryPendingDisable();

  Future<void> prepareForLogout() => _preferenceService.prepareForLogout();

  Future<void> resumeAfterFailedLogout() => _preferenceService.resumeAfterFailedLogout();

  Future<AnalyticsDeliveryResult> logEvent({
    required ProductAnalyticsEvent event,
    required DateTime occurredAtUtc,
  }) async {
    if (_disposed) return AnalyticsDeliveryResult.failed;
    final context = _preferenceService.deliveryContext;
    if (context == null) return AnalyticsDeliveryResult.failed;
    final result = await _analyticsRepository.logProductEvent(
      envelope: ProductAnalyticsEnvelope(event: event, occurredAtUtc: occurredAtUtc),
      userKey: context.userKey,
    );
    return !_disposed && _preferenceService.isCurrentDeliveryContext(context: context)
        ? result
        : AnalyticsDeliveryResult.failed;
  }

  void _onPreferenceState({required ProductAnalyticsState state}) {
    if (_disposed || !state.isActive) return;
    final context = _preferenceService.deliveryContext;
    if (context == null) return;
    unawaited(
      _schemaReadiness
          .dispatch(
            generation: context.generation,
            deliver: () => logEvent(
              event: const ProductAnalyticsEvent.analyticsSchemaReady(),
              occurredAtUtc: DateTime.now().toUtc(),
            ),
          )
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report analytics schema readiness", error, stackTrace);
          }),
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _preferenceService.dispose();
  }
}
