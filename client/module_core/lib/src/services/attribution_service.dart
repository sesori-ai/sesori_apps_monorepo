import "dart:async";

import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../repositories/attribution_repository.dart";

/// Owns the bridge-pairing attribution trigger.
@lazySingleton
class AttributionService({
  required final AttributionRepository _repository,
  required final ConnectionService _connectionService,
}) {
  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription;

  void start() {
    // If the sink is not ready at this transition, the repository declines
    // without claiming and the next reconnect reports it instead.
    _connectionStatusSubscription = _connectionService.status.listen(_reportIfConnected);
  }

  void _reportIfConnected(ConnectionStatus status) {
    if (status is ConnectionConnected) {
      unawaited(_repository.logEvent(event: AttributionEvent.bridgePaired));
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
  }
}
