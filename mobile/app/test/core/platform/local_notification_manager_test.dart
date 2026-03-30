import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sesori_mobile/core/platform/local_notification_manager.dart';
import 'package:sesori_mobile/core/platform/notification_id_utils.dart';
import 'package:sesori_shared/sesori_shared.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late LocalNotificationManager manager;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    manager = LocalNotificationManager(plugin: mockPlugin);
  });

  group('cancel', () {
    test('calls _plugin.cancel with correct notification ID', () async {
      when(() => mockPlugin.cancel(id: 42)).thenAnswer((_) async => true);

      await manager.cancel(42);

      verify(() => mockPlugin.cancel(id: 42)).called(1);
    });

    test('does not throw when canceling any valid int ID', () async {
      when(() => mockPlugin.cancel(id: any(named: 'id'))).thenAnswer((_) async => true);

      expect(() => manager.cancel(123), returnsNormally);
      expect(() => manager.cancel(0), returnsNormally);
      expect(() => manager.cancel(999999), returnsNormally);
    });

    test('passes the correct ID value to plugin.cancel', () async {
      when(() => mockPlugin.cancel(id: 555)).thenAnswer((_) async => true);

      await manager.cancel(555);

      verify(() => mockPlugin.cancel(id: 555)).called(1);
    });
  });

  group('show', () {
    void stubPluginShow() {
      when(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
    }

    test('with sessionId and aiInteraction category uses deterministic ID', () async {
      stubPluginShow();

      const sessionId = 'ses_abc';
      const category = NotificationCategory.aiInteraction;
      final expectedId = computeNotificationId(sessionId: sessionId, category: category);

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
        sessionId: sessionId,
        projectId: null,
      );

      verify(
        () => mockPlugin.show(
          id: expectedId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('with sessionId and non-aiInteraction category also uses deterministic ID', () async {
      stubPluginShow();

      const sessionId = 'ses_abc';
      const category = NotificationCategory.sessionMessage;
      final expectedId = computeNotificationId(sessionId: sessionId, category: category);

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
        sessionId: sessionId,
        projectId: null,
      );

      verify(
        () => mockPlugin.show(
          id: expectedId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('without sessionId uses timestamp-based ID even for aiInteraction', () async {
      stubPluginShow();

      const category = NotificationCategory.aiInteraction;

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
        sessionId: null,
        projectId: null,
      );

      // Capture the actual ID used
      final captured = verify(
        () => mockPlugin.show(
          id: captureAny(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).captured;

      final actualId = captured[0] as int;
      // Verify it's a reasonable timestamp-based ID (should be in seconds range)
      expect(actualId, greaterThan(0));
      expect(actualId, lessThan(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1000));
    });

    test('passes JSON payload with sessionId and projectId to plugin.show()', () async {
      stubPluginShow();

      await manager.show(
        title: 'Title',
        body: 'Body',
        category: NotificationCategory.aiInteraction,
        sessionId: 's1',
        projectId: 'p1',
      );

      final captured = verify(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;

      final payloadJson = captured[0] as String?;
      expect(payloadJson, isNotNull);
      final decoded = jsonDecode(payloadJson!) as Map<String, dynamic>;
      expect(decoded['sessionId'], equals('s1'));
      expect(decoded['projectId'], equals('p1'));
    });

    test('payload contains null values when sessionId and projectId are null', () async {
      stubPluginShow();

      await manager.show(
        title: 'Title',
        body: 'Body',
        category: NotificationCategory.sessionMessage,
        sessionId: null,
        projectId: null,
      );

      final captured = verify(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;

      final payloadJson = captured[0] as String?;
      expect(payloadJson, isNotNull);
      final decoded = jsonDecode(payloadJson!) as Map<String, dynamic>;
      expect(decoded['sessionId'], isNull);
      expect(decoded['projectId'], isNull);
    });
  });

  group('NotificationTapEvent serialization', () {
    test('toJson produces correct map', () {
      const event = NotificationTapEvent(sessionId: 'ses_1', projectId: 'proj_1');
      final json = event.toJson();
      expect(json, equals({'sessionId': 'ses_1', 'projectId': 'proj_1'}));
    });

    test('fromJson parses correctly', () {
      final event = NotificationTapEvent.fromJson({'sessionId': 'ses_1', 'projectId': 'proj_1'});
      expect(event.sessionId, equals('ses_1'));
      expect(event.projectId, equals('proj_1'));
    });

    test('fromJson handles missing keys as null', () {
      final event = NotificationTapEvent.fromJson({});
      expect(event.sessionId, isNull);
      expect(event.projectId, isNull);
    });

    test('roundtrip toJson/fromJson preserves values', () {
      const original = NotificationTapEvent(sessionId: 'ses_rt', projectId: 'proj_rt');
      final restored = NotificationTapEvent.fromJson(original.toJson());
      expect(restored, equals(original));
    });
  });

  group('onNotificationTapped stream', () {
    NotificationResponse makeResponse(String? payload) {
      return NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      );
    }

    test('emits NotificationTapEvent with correct sessionId and projectId for valid JSON', () async {
      final payload = jsonEncode({'sessionId': 'ses_123', 'projectId': 'proj_456'});
      final response = makeResponse(payload);

      final eventFuture = manager.onNotificationTapped.first;
      manager.handleNotificationResponseForTesting(response);

      final event = await eventFuture;
      expect(event.sessionId, equals('ses_123'));
      expect(event.projectId, equals('proj_456'));
    });

    test('emits event with null fields when payload is null', () async {
      final response = makeResponse(null);

      final eventFuture = manager.onNotificationTapped.first;
      manager.handleNotificationResponseForTesting(response);

      final event = await eventFuture;
      expect(event.sessionId, isNull);
      expect(event.projectId, isNull);
    });

    test('emits event with null fields when payload is empty string', () async {
      final response = makeResponse('');

      final eventFuture = manager.onNotificationTapped.first;
      manager.handleNotificationResponseForTesting(response);

      final event = await eventFuture;
      expect(event.sessionId, isNull);
      expect(event.projectId, isNull);
    });

    test('emits event with null fields and does not crash on malformed JSON', () async {
      final response = makeResponse('not-valid-json{{{');

      final eventFuture = manager.onNotificationTapped.first;
      expect(() => manager.handleNotificationResponseForTesting(response), returnsNormally);

      final event = await eventFuture;
      expect(event.sessionId, isNull);
      expect(event.projectId, isNull);
    });
  });
}
