import "dart:convert";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/flutter_local_notification_client.dart";
import "package:sesori_mobile/core/platform/notification_id_utils.dart";
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
    test("calls plugin.cancel with correct notification ID", () async {
      when(() => mockPlugin.cancel(id: 42)).thenAnswer((_) async => true);

      await client.cancel(42);

      verify(() => mockPlugin.cancel(id: 42)).called(1);
    });

    test("cancelForSession uses the deterministic session notification ID", () async {
      const sessionId = "ses_abc";
      const category = NotificationCategory.aiInteraction;
      final expectedId = computeNotificationId(sessionId: sessionId, category: category);
      when(() => mockPlugin.cancel(id: expectedId)).thenAnswer((_) async => true);

      client.cancelForSession(sessionId: sessionId, category: category);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockPlugin.cancel(id: expectedId)).called(1);
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
      final expectedId = computeNotificationId(sessionId: sessionId, category: category);

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
