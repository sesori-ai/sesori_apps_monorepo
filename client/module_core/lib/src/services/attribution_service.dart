import "dart:async";

import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../repositories/attribution_repository.dart";

/// Opens crawl-gated attribution delivery and owns the bridge-pairing listener.
@lazySingleton
class AttributionService({
  required final AttributionRepository _repository,
  required final ConnectionService _connectionService,
}) {
  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription;
  bool _started = false;

  Future<void> start() {
    if (_started) return Future<void>.value();
    _started = true;
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    return Future<void>.value();
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
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
