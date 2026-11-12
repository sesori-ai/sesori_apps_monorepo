import "dart:async";

import "package:firebase_app_installations/firebase_app_installations.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase/firebase_messaging_static_adapter.dart";
import "package:sesori_mobile/core/platform/firebase_push_messaging_source.dart";

class MockFirebaseMessaging() extends Mock implements FirebaseMessaging;

class MockFirebaseInstallations() extends Mock implements FirebaseInstallations;

class FakeNotificationSettings() extends Fake implements NotificationSettings;

void main() {
  late FirebasePushMessagingSource source;
  late MockFirebaseMessaging messaging;
  late MockFirebaseInstallations installations;

  setUp(() {
    messaging = MockFirebaseMessaging();
    installations = MockFirebaseInstallations();
    source = FirebasePushMessagingSource.test(messaging: messaging, installations: installations);
  });

  tearDown(() async {
    await source.dispose();
  });

  setUpAll(() {
    registerFallbackValue(FakeNotificationSettings());
  });

  group("notificationOpenFromMessage", () {
    test("returns normalized open request with session title", () {
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "projectId": "proj_1",
          "sessionId": "ses_1",
          "bridgeId": "br_workstation",
        },
        notification: RemoteNotification(
          title: "Session title",
          body: "Body",
        ),
      );

      final request = source.notificationOpenFromMessage(message: message);

      if (request == null) fail("message did not open a session");
      expect(request.projectId, equals("proj_1"));
      expect(request.sessionId, equals("ses_1"));
      expect(request.sessionTitle, equals("Session title"));
      expect(request.bridgeId, equals("br_workstation"));
    });

    test("returns null when projectId is missing", () {
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": "ses_1",
        },
      );

      final request = source.notificationOpenFromMessage(message: message);

      expect(request, isNull);
    });

    test("returns null when payload is invalid", () {
      const message = RemoteMessage(data: {"not": "a_notification_payload"});

      final request = source.notificationOpenFromMessage(message: message);

      expect(request, isNull);
    });
  });

  test("pushNotificationMessageFromRemoteMessage preserves typed data", () {
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

    final pushMessage = source.pushNotificationMessageFromRemoteMessage(
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

  test("initialize skips the permission prompt when it must not request permission", () async {
    await source.dispose();
    source = FirebasePushMessagingSource.test(
      messaging: messaging,
      installations: installations,
      requestsPermission: false,
    );
    when(
      () => messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      ),
    ).thenAnswer((_) async {});
    when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);

    await source.initialize();

    verifyNever(
      () => messaging.requestPermission(
        alert: any(named: "alert"),
        badge: any(named: "badge"),
        sound: any(named: "sound"),
      ),
    );
    verify(() => messaging.getInitialMessage()).called(1);
  });

  test("forwards foreground messages from the injected static adapter", () async {
    final foregroundMessages = StreamController<RemoteMessage>();
    addTearDown(foregroundMessages.close);
    source = FirebasePushMessagingSource.test(
      messaging: messaging,
      installations: installations,
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
      installations: installations,
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

  group("register", () {
    setUp(() {
      when(() => messaging.register()).thenAnswer((_) async {});
    });

    test("waits for the APNs token on Apple platforms before registering", () async {
      final apnsTokens = <String?>[null, null, "apns-token"];
      when(() => messaging.getAPNSToken()).thenAnswer((_) async => apnsTokens.removeAt(0));
      final delays = <Duration>[];
      final appleSource = FirebasePushMessagingSource.test(
        messaging: messaging,
        installations: installations,
        isApplePlatform: () => true,
        delay: (duration) async => delays.add(duration),
      );

      await appleSource.register();

      expect(delays, hasLength(2));
      verify(() => messaging.register()).called(1);
      await appleSource.dispose();
    });

    // Registering anyway lets the SDK report the missing APNs token instead of
    // the registration silently never happening.
    test("still registers when the APNs token never arrives", () async {
      when(() => messaging.getAPNSToken()).thenAnswer((_) async => null);
      final delays = <Duration>[];
      final appleSource = FirebasePushMessagingSource.test(
        messaging: messaging,
        installations: installations,
        isApplePlatform: () => true,
        delay: (duration) async => delays.add(duration),
      );

      await appleSource.register();

      expect(delays, hasLength(5));
      verify(() => messaging.register()).called(1);
      await appleSource.dispose();
    });

    test("registers without reading an APNs token off Apple platforms", () async {
      final androidSource = FirebasePushMessagingSource.test(
        messaging: messaging,
        installations: installations,
        isApplePlatform: () => false,
      );

      await androidSource.register();

      verifyNever(() => messaging.getAPNSToken());
      verify(() => messaging.register()).called(1);
      await androidSource.dispose();
    });
  });

  group("unregister", () {
    // Deleting the installation gives the next registration a new FID, so a row
    // the server still holds for the old one can never deliver. Unregistering
    // first clears the cached FCM registration that would otherwise make both
    // SDKs re-register with the rotated FID.
    test("unregisters from FCM, then deletes the installation", () async {
      when(() => messaging.unregister()).thenAnswer((_) async {});
      when(() => installations.delete()).thenAnswer((_) async {});

      await source.unregister();

      verifyInOrder([() => messaging.unregister(), () => installations.delete()]);
    });

    // The caller logs the failure; logout itself has already cleared auth.
    test("reports a failed installation delete to the caller", () async {
      when(() => messaging.unregister()).thenAnswer((_) async {});
      when(() => installations.delete()).thenThrow(FirebaseException(plugin: "firebase_app_installations"));

      await expectLater(source.unregister(), throwsA(isA<FirebaseException>()));
    });
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
