import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_api.dart";
import "../api/storage/notification_preferences_device_id_storage.dart";
import "../capabilities/notifications/register_token_request.dart";
import "../logging/logging.dart";

@lazySingleton
class NotificationRepository({
  required final NotificationApi _api,
  required final NotificationPreferencesDeviceIdStorage _deviceIdStorage,
}) {
  /// Sends the same device ID the notification settings are stored under, so the
  /// server can match this push token to the preferences for this device.
  Future<void> registerToken({required String token, required DevicePlatform platform}) async {
    return await _api.registerToken(
      request: RegisterTokenRequest(token: token, platform: platform, deviceId: await _readDeviceId()),
    );
  }

  Future<void> unregisterToken({required String token}) {
    return _api.unregisterToken(token: token);
  }

  // A device ID that cannot be read must not cost the user push entirely. The
  // server keeps delivering to a token registered without one, so registering
  // unfiltered is strictly better than failing the registration.
  Future<String?> _readDeviceId() async {
    try {
      return await _deviceIdStorage.getOrCreate();
    } catch (error, stackTrace) {
      logw("Failed to read notification device ID; registering token without it", error, stackTrace);
      return null;
    }
  }
}
