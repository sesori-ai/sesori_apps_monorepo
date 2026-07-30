import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_preference.dart";
import "../logging/logging.dart";
import "../repositories/analytics_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "models/deferred_product_analytics_candidates.dart";
import "models/product_analytics_state.dart";
import "product_analytics_generation_event_dispatcher.dart";
import "product_analytics_preference_service.dart";

@lazySingleton
class ProductAnalyticsService {
  final AnalyticsRepository _analyticsRepository;
  final ProductAnalyticsPreferenceService _preferenceService;
  final ProductAnalyticsGenerationEventDispatcher _schemaReadiness = ProductAnalyticsGenerationEventDispatcher();
  final ProductAnalyticsGenerationEventDispatcher _activationReadiness = ProductAnalyticsGenerationEventDispatcher();

  StreamSubscription<ProductAnalyticsState>? _stateSubscription;
  DeferredProductAnalyticsCandidates? _deferredCandidates;
  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
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
    final envelope = ProductAnalyticsEnvelope(event: event, occurredAtUtc: occurredAtUtc);
    final context = _preferenceService.deliveryContext;
    if (context != null) return _deliver(envelope: envelope, context: context);

    final generation = _preferenceService.deferrableGeneration;
    if (generation == null) return AnalyticsDeliveryResult.failed;
    var candidates = _deferredCandidates;
    if (candidates == null || candidates.generation != generation) {
      candidates = DeferredProductAnalyticsCandidates.empty(generation: generation);
    }
    final retention = candidates.retain(envelope: envelope);
    _deferredCandidates = retention.candidates;
    return retention.retained ? AnalyticsDeliveryResult.deferredUntilPreference : AnalyticsDeliveryResult.failed;
  }

  Future<AnalyticsDeliveryResult> _deliver({
    required ProductAnalyticsEnvelope envelope,
    required ProductAnalyticsDeliveryContext context,
  }) async {
    if (_disposed || !_preferenceService.isCurrentDeliveryContext(context: context)) {
      return AnalyticsDeliveryResult.failed;
    }
    final result = await _analyticsRepository.logProductEvent(
      envelope: envelope,
      userKey: context.userKey,
    );
    return !_disposed && _preferenceService.isCurrentDeliveryContext(context: context)
        ? result
        : AnalyticsDeliveryResult.failed;
  }

  void _onPreferenceState({required ProductAnalyticsState state}) {
    if (_disposed) return;
    _synchronizeDeferredCandidates(state: state);
    if (!state.isActive) return;
    final context = _preferenceService.deliveryContext;
    if (context == null) return;
    unawaited(
      _dispatchActiveGeneration(context: context).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to dispatch active product analytics generation", error, stackTrace);
      }),
    );
  }

  void _synchronizeDeferredCandidates({required ProductAnalyticsState state}) {
    final generation = _preferenceService.authenticatedGeneration;
    final candidates = _deferredCandidates;
    if (generation == null || (candidates != null && candidates.generation != generation)) {
      _deferredCandidates = null;
      return;
    }
    if (!state.isActive && _preferenceService.deferrableGeneration == null) {
      _deferredCandidates = null;
    }
  }

  Future<void> _dispatchActiveGeneration({required ProductAnalyticsDeliveryContext context}) async {
    await _schemaReadiness.dispatch(
      generation: context.generation,
      deliver: () => _deliver(
        envelope: ProductAnalyticsEnvelope(
          event: const ProductAnalyticsEvent.analyticsSchemaReady(),
          occurredAtUtc: DateTime.now().toUtc(),
        ),
        context: context,
      ),
    );
    if (!_isCurrentActiveContext(context: context)) return;

    await _activationReadiness.dispatch(
      generation: context.generation,
      deliver: () => _deliver(
        envelope: ProductAnalyticsEnvelope(
          event: const ProductAnalyticsEvent.analyticsActivationReady(),
          occurredAtUtc: DateTime.now().toUtc(),
        ),
        context: context,
      ),
    );
    if (!_isCurrentActiveContext(context: context)) return;

    final candidates = _deferredCandidates;
    if (candidates == null || candidates.generation != context.generation) return;
    _deferredCandidates = null;
    for (final envelope in candidates.envelopes) {
      if (!_isCurrentActiveContext(context: context)) return;
      await _deliver(envelope: envelope, context: context);
    }
  }

  bool _isCurrentActiveContext({required ProductAnalyticsDeliveryContext context}) =>
      !_disposed && state.isActive && _preferenceService.isCurrentDeliveryContext(context: context);

  @disposeMethod
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _deferredCandidates = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _preferenceService.dispose();
  }
}
