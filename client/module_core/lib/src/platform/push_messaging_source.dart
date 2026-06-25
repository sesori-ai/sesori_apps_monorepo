import "package:sesori_shared/sesori_shared.dart";

import "notification_open_request.dart";
import "push_notification_message.dart";

abstract interface class PushMessagingSource {
  Future<void> initialize();

  DevicePlatform get devicePlatform;

  Future<String?> getToken();

  Stream<String> get tokenRefreshStream;

  Stream<PushNotificationMessage> get foregroundMessageStream;

  Future<NotificationOpenRequest?> getInitialNotificationOpen();

  Stream<NotificationOpenRequest> get notificationOpenedStream;
}
