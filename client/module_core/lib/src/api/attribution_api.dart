import "dart:async";

import "package:injectable/injectable.dart";

import "../foundation/models/product_analytics/attribution_event.dart";
import "../foundation/platform/attribution_client.dart";

@lazySingleton
class AttributionApi({required final AttributionClient _client}) {
  bool get isReady => _client.isReady;
  Stream<void> get readinessStream => _client.readinessStream;

  Future<void> logEvent({required AttributionEvent event}) => _client.logEvent(event: event);
}
