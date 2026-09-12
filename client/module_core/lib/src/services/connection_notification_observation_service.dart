import "dart:async";

import "package:injectable/injectable.dart";

import "../capabilities/relay/relay_client.dart";
import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/notification_repository.dart";

@lazySingleton
class ConnectionNotificationObservationService({
  required final ConnectionService _connectionService,
  required final NotificationRepository _notificationRepository,
}) {
  // ignore: cancel_subscriptions - process-lifetime mobile startup service.
  StreamSubscription<ConnectionStatus>? _subscription;
  RelayClient? _lastObservedConnection;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _connectionService.status.listen((status) {
      if (status is! ConnectionConnected) return;
      final connection = _connectionService.relayClient;
      if (connection == null || identical(connection, _lastObservedConnection)) return;
      _lastObservedConnection = connection;
      unawaited(_observe(connection: connection));
    });
  }

  Future<void> _observe({required RelayClient connection}) async {
    try {
      final deviceId = await _notificationRepository.readDeviceId();
      if (deviceId == null) return;
      _connectionService.sendBridgeConnectionObserved(connection: connection, deviceId: deviceId);
    } on Object catch (error, stackTrace) {
      logw("Failed to report observed bridge connection", error, stackTrace);
    }
  }
}
