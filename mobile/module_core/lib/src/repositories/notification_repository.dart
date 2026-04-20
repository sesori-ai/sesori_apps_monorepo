import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_api.dart";
import "../capabilities/notifications/register_token_request.dart";

@lazySingleton
class NotificationRepository {
  final NotificationApi _api;

  NotificationRepository({required NotificationApi api}) : _api = api;

  Future<void> registerToken({required String token, required DevicePlatform platform}) {
    return _api.registerToken(request: RegisterTokenRequest(token: token, platform: platform));
  }

  Future<void> unregisterToken({required String token}) {
    return _api.unregisterToken(token: token);
  }
}
