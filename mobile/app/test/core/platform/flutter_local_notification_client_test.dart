import "dart:convert";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/flutter_local_notification_client.dart";
import "package:sesori_mobile/core/platform/notification_tap_event.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late FlutterLocalNotificationClient client;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    client = FlutterLocalNotificationClient(plugin: mockPlugin);
  });

  group("cancel", () {
    test("calls plugin.cancel with the notification ID", () async {
      when(() => mockPlugin.cancel(id: 42, tag: null)).thenAnswer((_) async {});

      await client.cancel(id: 42, tag: null);

      verify(() => mockPlugin.cancel(id: 42, tag: null)).called(1);
    });

    test("cancelForSession dismisses the deterministic session notification ID", () async {
      const sessionId = "ses_abc";
      final expectedId = sessionNotificationId(sessionId: sessionId);
      when(
        () => mockPlugin.cancel(id: any(named: "id"), tag: any(named: "tag")),
      ).thenAnswer((_) async {});

      client.cancelForSession(sessionId: sessionId);
      await Future<void>.delayed(Duration.zero);

      // On a non-Android host the identity is (sessionKey, no tag), so one
      // cancel by integer id clears the foreground + iOS/macOS notifications.
      verify(() => mockPlugin.cancel(id: expectedId, tag: null)).called(1);
    });

    test("cancelForSession swallows plugin cancel failures", () async {
      when(
        () => mockPlugin.cancel(id: any(named: "id"), tag: any(named: "tag")),
      ).thenThrow(Exception("cancel boom"));

      client.cancelForSession(sessionId: "ses_abc");
      await Future<void>.delayed(Duration.zero);

      verify(() => mockPlugin.cancel(id: any(named: "id"), tag: any(named: "tag"))).called(1);
    });
  });

  group("notificationIdentityForSession", () {
    test("Android reuses the FCM (tag, 0) identity: id 0 + session key as tag", () {
      final identity = FlutterLocalNotificationClient.notificationIdentityForSession(
        sessionId: "ses_abc",
        isAndroid: true,
      );

      expect(identity.id, 0);
      expect(identity.androidTag, sessionNotificationId(sessionId: "ses_abc").toString());
    });

    test("iOS/macOS use the session id as the notification id with no tag", () {
      final identity = FlutterLocalNotificationClient.notificationIdentityForSession(
        sessionId: "ses_abc",
        isAndroid: false,
      );

      expect(identity.id, sessionNotificationId(sessionId: "ses_abc"));
      expect(identity.androidTag, isNull);
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
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await client.show(
        title: "T2",
        body: "B2",
        category: NotificationCategory.systemUpdate,
        sessionId: null,
        projectId: null,
        sessionTitle: null,
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

  group("NotificationTapEvent serialization", () {
    test("toJson includes sessionTitle", () {
      const event = NotificationTapEvent(
        sessionId: "ses_1",
        projectId: "proj_1",
        sessionTitle: "Title",
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
      final event = NotificationTapEvent.fromJson({
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
