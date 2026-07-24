import "dart:async";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase/firebase_messaging_static_adapter.dart";
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

  tearDown(() async {
    await source.dispose();
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

  test("forwards foreground messages from the injected static adapter", () async {
    final foregroundMessages = StreamController<RemoteMessage>();
    addTearDown(foregroundMessages.close);
    source = FirebasePushMessagingSource.test(
      messaging: messaging,
      staticAdapter: FirebaseMessagingStaticAdapter.test(
        foregroundMessageStream: foregroundMessages.stream,
        notificationOpenedStream: const Stream.empty(),
      ),
    );
    _stubInitialization(messaging);
    await source.initialize();

    final forwardedMessage = source.foregroundMessageStream.first;
    foregroundMessages.add(
      const RemoteMessage(
        data: {"projectId": "proj_2"},
        notification: RemoteNotification(
          title: "Foreground title",
          body: "Foreground body",
        ),
      ),
    );

    expect((await forwardedMessage).title, "Foreground title");
  });

  test("forwards notification opens from the injected static adapter", () async {
    final notificationOpens = StreamController<RemoteMessage>();
    addTearDown(notificationOpens.close);
    source = FirebasePushMessagingSource.test(
      messaging: messaging,
      staticAdapter: FirebaseMessagingStaticAdapter.test(
        foregroundMessageStream: const Stream.empty(),
        notificationOpenedStream: notificationOpens.stream,
      ),
    );
    _stubInitialization(messaging);
    await source.initialize();

    final forwardedOpen = source.notificationOpenedStream.first;
    notificationOpens.add(
      const RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "projectId": "proj_1",
          "sessionId": "ses_1",
        },
        notification: RemoteNotification(title: "Session title"),
      ),
    );

    final request = await forwardedOpen;
    expect(request.projectId, "proj_1");
    expect(request.sessionId, "ses_1");
    expect(request.sessionTitle, "Session title");
  });

  test("getToken returns null when APNS token never becomes available", () async {
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => null);

    final appleSource = FirebasePushMessagingSource.test(
      messaging: messaging,
      isApplePlatform: () => true,
      delay: (_) async {},
    );

    final token = await appleSource.getToken();

    expect(token, isNull);
    verifyNever(() => messaging.getToken());
    await appleSource.dispose();
  });

  test("deleteToken delegates to Firebase Messaging", () async {
    when(() => messaging.deleteToken()).thenAnswer((_) async {});

    await source.deleteToken();

    verify(() => messaging.deleteToken()).called(1);
  });
}

void _stubInitialization(MockFirebaseMessaging messaging) {
  when(
    () => messaging.requestPermission(alert: true, badge: true, sound: true),
  ).thenAnswer((_) async => FakeNotificationSettings());
  when(
    () => messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    ),
  ).thenAnswer((_) async {});
  when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
}
