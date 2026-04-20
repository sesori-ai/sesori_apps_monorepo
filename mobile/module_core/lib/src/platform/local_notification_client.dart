import "package:sesori_shared/sesori_shared.dart";

import "notification_canceller.dart";
import "notification_open_request.dart";

abstract interface class LocalNotificationClient implements NotificationCanceller {
  Future<void> initialize();

  Future<NotificationOpenRequest?> getInitialNotificationOpen();

  Stream<NotificationOpenRequest> get notificationOpenedStream;

  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  });
}
