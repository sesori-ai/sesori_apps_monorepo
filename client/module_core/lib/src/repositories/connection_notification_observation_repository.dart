import "package:injectable/injectable.dart";

import "../api/connection_notification_observation_api.dart";
import "../api/storage/notification_preferences_device_id_storage.dart";

@lazySingleton
class ConnectionNotificationObservationRepository({
  required final ConnectionNotificationObservationApi _api,
  required final NotificationPreferencesDeviceIdStorage _deviceIdStorage,
}) {
  ConnectionNotificationObservationToken? _lastObservedConnection;

  Future<void> reportCurrentConnectionObserved() async {
    final connection = _api.captureCurrentConnection();
    if (connection == null || connection == _lastObservedConnection) return;
    _lastObservedConnection = connection;

    final deviceId = await _deviceIdStorage.getOrCreate();
    _api.reportObserved(connection: connection, deviceId: deviceId);
  }
}
