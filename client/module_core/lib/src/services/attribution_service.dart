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
  StreamSubscription<void>? _readinessSubscription;

  void start() {
    _connectionStatusSubscription = _connectionService.status.listen(_reportIfConnected);
    // A connection established before the sink became ready (deferred Singular
    // start) is reported once readiness arrives instead of waiting for a reconnect.
    _readinessSubscription = _repository.readinessStream.listen(
      (_) => _reportIfConnected(_connectionService.currentStatus),
    );
  }

  void _reportIfConnected(ConnectionStatus status) {
    if (status is ConnectionConnected) {
      unawaited(_repository.logEvent(event: AttributionEvent.bridgePaired));
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _connectionStatusSubscription?.cancel();
    await _readinessSubscription?.cancel();
    _connectionStatusSubscription = null;
    _readinessSubscription = null;
  }
}
