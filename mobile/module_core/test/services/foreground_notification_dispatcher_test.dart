import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_dart_core/src/platform/local_notification_client.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/repositories/notification_preferences_repository.dart";
import "package:sesori_dart_core/src/services/foreground_notification_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ForegroundNotificationDispatcher", () {
    late FakeNotificationPreferencesRepository preferencesRepository;
    late RecordingLocalNotificationClient localNotificationClient;
    late FakePushMessagingSource pushMessagingSource;
    late ForegroundNotificationDispatcher dispatcher;

    setUp(() {
      preferencesRepository = FakeNotificationPreferencesRepository();
      localNotificationClient = RecordingLocalNotificationClient();
      pushMessagingSource = FakePushMessagingSource();
      dispatcher = ForegroundNotificationDispatcher(
        notificationPreferencesRepository: preferencesRepository,
        localNotificationClient: localNotificationClient,
        pushMessagingSource: pushMessagingSource,
      );
    });

    tearDown(() async {
      await dispatcher.dispose();
      await pushMessagingSource.dispose();
      await localNotificationClient.dispose();
    });

    test("foreground messages dispatch local notifications through preferences", () async {
      preferencesRepository.enabledCategories[NotificationCategory.aiInteraction] = true;
      await dispatcher.start();

      pushMessagingSource.emitForegroundMessage(
        const PushNotificationMessage(
          data: {
            "category": "ai_interaction",
            "eventType": "question_asked",
            "sessionId": "session-1",
            "projectId": "project-1",
          },
          title: "Weekly planning",
          body: "Agent finished its turn",
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(localNotificationClient.shownNotifications, hasLength(1));
      expect(
        localNotificationClient.shownNotifications.single,
        equals(
          const ShownNotification(
            title: "Weekly planning",
            body: "Agent finished its turn",
            category: NotificationCategory.aiInteraction,
            sessionId: "session-1",
            projectId: "project-1",
            sessionTitle: "Weekly planning",
          ),
        ),
      );
    });

    test("disabled category suppresses local notification", () async {
      preferencesRepository.enabledCategories[NotificationCategory.aiInteraction] = false;
      await dispatcher.start();

      pushMessagingSource.emitForegroundMessage(
        const PushNotificationMessage(
          data: {
            "category": "ai_interaction",
            "eventType": "question_asked",
            "sessionId": "session-1",
            "projectId": "project-1",
          },
          title: "Weekly planning",
          body: "Agent finished its turn",
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(localNotificationClient.shownNotifications, isEmpty);
    });
  });
}

class FakeNotificationPreferencesRepository implements NotificationPreferencesRepository {
  final Map<NotificationCategory, bool> enabledCategories = <NotificationCategory, bool>{};

  @override
  Future<Map<NotificationCategory, bool>> getAll() async => enabledCategories;

  @override
  Future<bool> isEnabled({required NotificationCategory category}) async {
    return enabledCategories[category] ?? true;
  }

  @override
  Future<void> setEnabled({required NotificationCategory category, required bool enabled}) async {
    enabledCategories[category] = enabled;
  }
}

class RecordingLocalNotificationClient implements LocalNotificationClient {
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();
  final List<ShownNotification> shownNotifications = <ShownNotification>[];

  @override
  Future<void> cancelForSession({required String sessionId, required NotificationCategory category}) async {}

  Future<void> dispose() async => _notificationOpenedController.close();

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  }) async {
    shownNotifications.add(
      ShownNotification(
        title: title,
        body: body,
        category: category,
        sessionId: sessionId,
        projectId: projectId,
        sessionTitle: sessionTitle,
      ),
    );
  }
}

class FakePushMessagingSource implements PushMessagingSource {
  final StreamController<PushNotificationMessage> _foregroundMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  Future<void> dispose() async {
    await _foregroundMessageController.close();
    await _notificationOpenedController.close();
  }

  void emitForegroundMessage(PushNotificationMessage message) => _foregroundMessageController.add(message);

  @override
  DevicePlatform get devicePlatform => DevicePlatform.android;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Stream<String> get tokenRefreshStream => const Stream<String>.empty();
}

@immutable
class ShownNotification {
  final String title;
  final String body;
  final NotificationCategory category;
  final String? sessionId;
  final String? projectId;
  final String? sessionTitle;

  const ShownNotification({
    required this.title,
    required this.body,
    required this.category,
    required this.sessionId,
    required this.projectId,
    required this.sessionTitle,
  });

  @override
  bool operator ==(Object other) {
    return other is ShownNotification &&
        other.title == title &&
        other.body == body &&
        other.category == category &&
        other.sessionId == sessionId &&
        other.projectId == projectId &&
        other.sessionTitle == sessionTitle;
  }

  @override
  int get hashCode => Object.hash(title, body, category, sessionId, projectId, sessionTitle);
}
