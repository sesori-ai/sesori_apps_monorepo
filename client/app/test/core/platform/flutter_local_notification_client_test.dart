import "dart:async";
import "dart:convert";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_local_notification_client.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockFlutterLocalNotificationsPlugin() extends Mock implements FlutterLocalNotificationsPlugin;

void main() {
  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings("@drawable/ic_notification"),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
  });

  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late FlutterLocalNotificationClient client;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    client = FlutterLocalNotificationClient(plugin: mockPlugin);
    when(mockPlugin.getNotificationAppLaunchDetails).thenAnswer((_) async => null);
    when(
      () => mockPlugin.initialize(
        settings: any(named: "settings"),
        onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() => client.dispose());

  group("initialize", () {
    test("coalesces concurrent native initialization", () async {
      final nativeInitialization = Completer<bool?>();
      when(
        () => mockPlugin.initialize(
          settings: any(named: "settings"),
          onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
        ),
      ).thenAnswer((_) => nativeInitialization.future);

      final first = client.initialize();
      final second = client.initialize();
      nativeInitialization.complete(true);
      await Future.wait<void>(<Future<void>>[first, second]);

      verify(mockPlugin.getNotificationAppLaunchDetails).called(1);
      verify(
        () => mockPlugin.initialize(
          settings: any(named: "settings"),
          onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
        ),
      ).called(1);
    });

    test("retries after native initialization fails", () async {
      var attempts = 0;
      when(
        () => mockPlugin.initialize(
          settings: any(named: "settings"),
          onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
        ),
      ).thenAnswer((_) async {
        if (attempts++ == 0) {
          throw StateError("native initialization failed");
        }
        return true;
      });

      await expectLater(client.initialize(), throwsStateError);
      await client.initialize();

      verify(
        () => mockPlugin.initialize(
          settings: any(named: "settings"),
          onDidReceiveNotificationResponse: any(named: "onDidReceiveNotificationResponse"),
        ),
      ).called(2);
    });
  });

  group("cancel", () {
    test("calls plugin.cancel with the notification ID", () async {
      when(() => mockPlugin.cancel(id: 42, tag: null)).thenAnswer((_) async {});

      await client.cancel(id: 42, tag: null);

      verify(() => mockPlugin.cancel(id: 42, tag: null)).called(1);
    });

    test("cancelAll delegates to the plugin", () async {
      when(mockPlugin.cancelAll).thenAnswer((_) async {});

      await client.cancelAll();

      verify(mockPlugin.cancelAll).called(1);
    });

    test("cancelForSession dismisses the deterministic session notification ID", () async {
      const sessionId = "ses_abc";
      final expectedId = sessionNotificationId(sessionId: sessionId);
      when(
        () => mockPlugin.cancel(
          id: any(named: "id"),
          tag: any(named: "tag"),
        ),
      ).thenAnswer((_) async {});

      await client.cancelForSession(sessionId: sessionId);

      // On a non-Android host the integer id covers foreground + iOS/macOS
      // delivered notifications; the Android (tag, 0) sweep is a no-op here.
      verify(() => mockPlugin.cancel(id: expectedId, tag: null)).called(1);
    });

    test("cancelForSession swallows plugin cancel failures", () async {
      when(
        () => mockPlugin.cancel(
          id: any(named: "id"),
          tag: any(named: "tag"),
        ),
      ).thenThrow(Exception("cancel boom"));

      await client.cancelForSession(sessionId: "ses_abc");

      verify(
        () => mockPlugin.cancel(
          id: any(named: "id"),
          tag: any(named: "tag"),
        ),
      ).called(1);
    });
  });

  group("show", () {
    void stubPluginShow() {
      when(
        () => mockPlugin.show(
          id: any(named: "id"),
          title: any(named: "title"),
          body: any(named: "body"),
          notificationDetails: any(named: "notificationDetails"),
          payload: any(named: "payload"),
        ),
      ).thenAnswer((_) async {});
    }

    test("with sessionId uses deterministic ID", () async {
      stubPluginShow();

      const sessionId = "ses_abc";
      const category = NotificationCategory.aiInteraction;
      final expectedId = sessionNotificationId(sessionId: sessionId);

      await client.show(
        title: "Test Title",
        body: "Test Body",
        category: category,
        sessionId: sessionId,
        projectId: null,
        sessionTitle: null,
        accountId: null,
      );

      verify(
        () => mockPlugin.show(
          id: expectedId,
          title: any(named: "title"),
          body: any(named: "body"),
          notificationDetails: any(named: "notificationDetails"),
          payload: any(named: "payload"),
        ),
      ).called(1);
    });

    test("without sessionId uses millisecond fallback IDs", () async {
      stubPluginShow();

      await client.show(
        title: "T1",
        body: "B1",
        category: NotificationCategory.systemUpdate,
        sessionId: null,
        projectId: null,
        sessionTitle: null,
        accountId: null,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await client.show(
        title: "T2",
        body: "B2",
        category: NotificationCategory.systemUpdate,
        sessionId: null,
        projectId: null,
        sessionTitle: null,
        accountId: null,
      );

      final capturedIds = verify(
        () => mockPlugin.show(
          id: captureAny(named: "id"),
          title: any(named: "title"),
          body: any(named: "body"),
          notificationDetails: any(named: "notificationDetails"),
          payload: any(named: "payload"),
        ),
      ).captured.cast<int>();

      expect(capturedIds, hasLength(2));
      expect(capturedIds.first, isNot(equals(capturedIds.last)));
    });

    test("payload preserves sessionTitle for newer notifications", () async {
      stubPluginShow();

      await client.show(
        title: "Visible Title",
        body: "Body",
        category: NotificationCategory.aiInteraction,
        sessionId: "s1",
        projectId: "p1",
        sessionTitle: "Session Title",
        accountId: null,
      );

      final captured = verify(
        () => mockPlugin.show(
          id: any(named: "id"),
          title: any(named: "title"),
          body: any(named: "body"),
          notificationDetails: any(named: "notificationDetails"),
          payload: captureAny(named: "payload"),
        ),
      ).captured;

      final payloadJson = captured.single as String?;
      expect(payloadJson, isNotNull);
      final decoded = jsonDecode(payloadJson!) as Map<String, dynamic>;
      expect(decoded["sessionId"], equals("s1"));
      expect(decoded["projectId"], equals("p1"));
      expect(decoded["sessionTitle"], equals("Session Title"));
    });
  });

  group("LocalNotificationPayload serialization", () {
    test("toJson includes sessionTitle", () {
      const event = LocalNotificationPayload(
        sessionId: "ses_1",
        projectId: "proj_1",
        sessionTitle: "Title",
        accountId: null,
      );

      expect(
        event.toJson(),
        equals({
          "sessionId": "ses_1",
          "projectId": "proj_1",
          "sessionTitle": "Title",
        }),
      );
    });

    test("fromJson stays backward compatible when sessionTitle is missing", () {
      final event = LocalNotificationPayload.fromJson({
        "sessionId": "ses_1",
        "projectId": "proj_1",
      });

      expect(event.sessionId, equals("ses_1"));
      expect(event.projectId, equals("proj_1"));
      expect(event.sessionTitle, isNull);
    });
  });

  group("notificationOpenFromPayloadForTesting", () {
    test("normalizes valid payload into core open request", () {
      final request = client.notificationOpenFromPayloadForTesting(
        payload: jsonEncode({
          "sessionId": "ses_123",
          "projectId": "proj_456",
          "sessionTitle": "Warm title",
        }),
      );

      expect(request, isNotNull);
      expect(request!.sessionId, equals("ses_123"));
      expect(request.projectId, equals("proj_456"));
      expect(request.sessionTitle, equals("Warm title"));
    });

    test("accepts legacy payloads without sessionTitle", () {
      final request = client.notificationOpenFromPayloadForTesting(
        payload: jsonEncode({
          "sessionId": "ses_legacy",
          "projectId": "proj_legacy",
        }),
      );

      expect(request, isNotNull);
      expect(request!.sessionId, equals("ses_legacy"));
      expect(request.projectId, equals("proj_legacy"));
      expect(request.sessionTitle, isNull);
    });

    test("returns null for malformed payloads", () {
      final request = client.notificationOpenFromPayloadForTesting(
        payload: "not-valid-json{{{",
      );

      expect(request, isNull);
    });
  });
}
