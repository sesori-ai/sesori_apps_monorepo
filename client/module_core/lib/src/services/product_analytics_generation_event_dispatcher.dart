import "dart:async";

import "../repositories/models/analytics_delivery_result.dart";

final class ProductAnalyticsGenerationEventDispatcher {
  int? _readyGeneration;
  ({int generation, Future<void> future})? _activeDelivery;

  Future<void> dispatch({
    required int generation,
    required Future<AnalyticsDeliveryResult> Function() deliver,
  }) async {
    if (_readyGeneration == generation) return;
    final active = _activeDelivery;
    if (active != null && active.generation == generation) {
      await active.future;
      return;
    }

    final future = _deliver(generation: generation, deliver: deliver);
    _activeDelivery = (generation: generation, future: future);
    try {
      await future;
    } finally {
      if (identical(_activeDelivery?.future, future)) _activeDelivery = null;
    }
  }

  Future<void> _deliver({
    required int generation,
    required Future<AnalyticsDeliveryResult> Function() deliver,
  }) async {
    final result = await deliver();
    if (result == AnalyticsDeliveryResult.acceptedBySdk) _readyGeneration = generation;
  }
}
