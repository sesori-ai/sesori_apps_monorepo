import "package:injectable/injectable.dart";

import "../foundation/models/attribution/attribution_event.dart";
import "../foundation/platform/attribution_client.dart";

@lazySingleton
class AttributionApi({required final AttributionClient _client}) {
  Future<void> logEvent({required AttributionEvent event}) => _client.logEvent(event: event);
}
