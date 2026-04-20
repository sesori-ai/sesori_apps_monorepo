import "dart:async";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_push_messaging_source.dart";

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class FakeNotificationSettings extends Fake implements NotificationSettings {}

void main() {
  late FirebasePushMessagingSource source;
  late MockFirebaseMessaging messaging;

  setUp(() {
    messaging = MockFirebaseMessaging();
    source = FirebasePushMessagingSource.test(messaging: messaging);
  });

  setUpAll(() {
    registerFallbackValue(FakeNotificationSettings());
  });

  group("notificationOpenFromMessageForTesting", () {
    test("returns normalized open request with session title", () {
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "projectId": "proj_1",
          "sessionId": "ses_1",
        },
        notification: RemoteNotification(
          title: "Session title",
          body: "Body",
        ),
      );

      final request = source.notificationOpenFromMessageForTesting(message: message);

      expect(request, isNotNull);
      expect(request!.projectId, equals("proj_1"));
      expect(request.sessionId, equals("ses_1"));
      expect(request.sessionTitle, equals("Session title"));
    });

    test("returns null when projectId is missing", () {
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": "ses_1",
        },
      );

      final request = source.notificationOpenFromMessageForTesting(message: message);

      expect(request, isNull);
    });

    test("returns null when payload is invalid", () {
      const message = RemoteMessage(data: {"not": "a_notification_payload"});

      final request = source.notificationOpenFromMessageForTesting(message: message);

      expect(request, isNull);
    });
  });

  test("pushNotificationMessageFromRemoteMessageForTesting preserves typed data", () {
    const message = RemoteMessage(
      data: {
        "category": "session_message",
        "eventType": "message_posted",
        "projectId": "proj_2",
      },
      notification: RemoteNotification(
        title: "Foreground title",
        body: "Foreground body",
      ),
    );

    final pushMessage = source.pushNotificationMessageFromRemoteMessageForTesting(
      message: message,
    );

    expect(pushMessage.title, equals("Foreground title"));
    expect(pushMessage.body, equals("Foreground body"));
    expect(pushMessage.data, containsPair("projectId", "proj_2"));
  });

  test("initialize shares the same in-flight work across concurrent callers", () async {
    final permissionCompleter = Completer<NotificationSettings>();
    when(
      () => messaging.requestPermission(alert: true, badge: true, sound: true),
    ).thenAnswer((_) => permissionCompleter.future);
    when(
      () => messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      ),
    ).thenAnswer((_) async {});
    when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);

    final first = source.initialize();
    final second = source.initialize();
    permissionCompleter.complete(FakeNotificationSettings());

    await Future.wait([first, second]);

    verify(() => messaging.requestPermission(alert: true, badge: true, sound: true)).called(1);
    verify(
      () => messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      ),
    ).called(1);
    verify(() => messaging.getInitialMessage()).called(1);
  });
}
