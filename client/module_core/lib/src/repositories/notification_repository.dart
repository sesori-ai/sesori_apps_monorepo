import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_api.dart";
import "../api/storage/notification_preferences_device_id_storage.dart";
import "../capabilities/notifications/register_fid_request.dart";
import "../logging/logging.dart";

@lazySingleton
class NotificationRepository({
  required final NotificationApi _api,
  required final NotificationPreferencesDeviceIdStorage _deviceIdStorage,
}) {
  /// Sends the same device ID the notification settings are stored under, so the
  /// server can match this FID to the preferences for this device and retire the
  /// device's pre-FID push token.
  Future<void> registerFid({required String fid, required DevicePlatform platform}) async {
    return await _api.registerFid(
      request: RegisterFidRequest(fid: fid, platform: platform, deviceId: await readDeviceId()),
    );
  }

  Future<void> unregisterFid({required String fid}) {
    return _api.unregisterFid(fid: fid);
  }

  // A device ID that cannot be read must not cost the user push entirely. The
  // server keeps delivering to an FID registered without one, so registering
  // unfiltered is strictly better than failing the registration.
  Future<String?> readDeviceId() async {
    try {
      return await _deviceIdStorage.getOrCreate();
    } catch (error, stackTrace) {
      logw("Failed to read notification device ID; registering FID without it", error, stackTrace);
      return null;
    }
  }
}
