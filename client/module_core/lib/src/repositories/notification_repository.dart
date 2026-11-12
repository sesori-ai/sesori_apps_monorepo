import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_api.dart";
import "../api/storage/notification_preferences_device_id_storage.dart";
import "../capabilities/notifications/register_fid_request.dart";

@lazySingleton
class NotificationRepository({
  required final NotificationApi _api,
  required final NotificationPreferencesDeviceIdStorage _deviceIdStorage,
}) {
  /// Sends the same device ID the notification settings are stored under, so the
  /// server can match this FID to the preferences for this device and retire the
  /// device's pre-FID push token.
  ///
  /// A device ID that cannot be read fails the registration instead of sending
  /// the FID without one: such a row could not replace the device's old token
  /// row, so the install would receive each push twice. The caller logs the
  /// failure and retries on the next FID report, login or launch.
  Future<void> registerFid({required String fid, required DevicePlatform platform}) async {
    final deviceId = await _deviceIdStorage.getOrCreate();
    await _api.registerFid(
      request: RegisterFidRequest(fid: fid, platform: platform, deviceId: deviceId),
    );
  }

  Future<void> unregisterFid({required String fid}) {
    return _api.unregisterFid(fid: fid);
  }
}
