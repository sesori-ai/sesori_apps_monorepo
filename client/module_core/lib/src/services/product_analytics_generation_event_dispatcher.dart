import "dart:async";

import "../repositories/models/analytics_delivery_result.dart";

final class ProductAnalyticsGenerationEventDispatcher() {
  int? _readyGeneration;
  ({int generation, Future<AnalyticsDeliveryResult> future})? _activeDelivery;

  Future<AnalyticsDeliveryResult> dispatch({
    required int generation,
    required Future<AnalyticsDeliveryResult> Function() deliver,
  }) async {
    if (_readyGeneration == generation) return AnalyticsDeliveryResult.acceptedBySdk;
    final active = _activeDelivery;
    if (active != null && active.generation == generation) {
      return active.future;
    }

    final future = _deliver(generation: generation, deliver: deliver);
    _activeDelivery = (generation: generation, future: future);
    try {
      return await future;
    } finally {
      if (identical(_activeDelivery?.future, future)) _activeDelivery = null;
    }
  }

  Future<AnalyticsDeliveryResult> _deliver({
    required int generation,
    required Future<AnalyticsDeliveryResult> Function() deliver,
  }) async {
    final result = await deliver();
    if (result == AnalyticsDeliveryResult.acceptedBySdk) _readyGeneration = generation;
    return result;
  }
}
