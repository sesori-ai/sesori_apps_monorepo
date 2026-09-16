import "dart:async";

import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/connection_notification_observation_repository.dart";

@lazySingleton
class ConnectionNotificationObservationService({
  required final ConnectionService _connectionService,
  required final ConnectionNotificationObservationRepository _repository,
}) {
  // ignore: cancel_subscriptions - process-lifetime mobile startup service.
  StreamSubscription<ConnectionStatus>? _subscription;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _connectionService.status.listen((status) {
      if (status is ConnectionConnected) unawaited(_observe());
    });
  }

  Future<void> _observe() async {
    try {
      await _repository.reportCurrentConnectionObserved();
    } on Object catch (error, stackTrace) {
      logw("Failed to report observed bridge connection", error, stackTrace);
    }
  }
}
