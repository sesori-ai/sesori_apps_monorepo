import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";

class const ConnectionNotificationObservationToken._({required final ConnectionNotificationObservationHandle _handle});

@lazySingleton
class ConnectionNotificationObservationApi({required final ConnectionService _connectionService}) {
  ConnectionNotificationObservationToken? captureCurrentConnection() {
    final handle = _connectionService.captureConnectionNotificationObservation();
    return handle == null ? null : ConnectionNotificationObservationToken._(handle: handle);
  }

  bool reportObserved({
    required ConnectionNotificationObservationToken connection,
    required String deviceId,
  }) {
    return _connectionService.sendBridgeConnectionObserved(handle: connection._handle, deviceId: deviceId);
  }
}
