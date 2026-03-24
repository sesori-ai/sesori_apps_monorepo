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
    manager = LocalNotificationManager(mockPlugin);
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
    test('with sessionId and aiInteraction category uses deterministic ID', () async {
      when(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).thenAnswer((_) async {});

      const sessionId = 'ses_abc';
      const category = NotificationCategory.aiInteraction;
      final expectedId = computeNotificationId(sessionId, category);

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
        sessionId: sessionId,
      );

      verify(
        () => mockPlugin.show(
          id: expectedId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).called(1);
    });

    test('with sessionId but non-aiInteraction category uses timestamp-based ID', () async {
      when(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).thenAnswer((_) async {});

      const sessionId = 'ses_abc';
      const category = NotificationCategory.sessionMessage;
      final deterministicId = computeNotificationId(sessionId, category);

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
        sessionId: sessionId,
      );

      // Capture the actual ID used
      final captured = verify(
        () => mockPlugin.show(
          id: captureAny(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).captured;

      final actualId = captured[0] as int;
      // Verify it's NOT the deterministic ID (should be timestamp-based)
      expect(actualId, isNot(deterministicId));
    });

    test('without sessionId uses timestamp-based ID even for aiInteraction', () async {
      when(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).thenAnswer((_) async {});

      const category = NotificationCategory.aiInteraction;

      await manager.show(
        title: 'Test Title',
        body: 'Test Body',
        category: category,
      );

      // Capture the actual ID used
      final captured = verify(
        () => mockPlugin.show(
          id: captureAny(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).captured;

      final actualId = captured[0] as int;
      // Verify it's a reasonable timestamp-based ID (should be in seconds range)
      expect(actualId, greaterThan(0));
      expect(actualId, lessThan(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1000));
    });
  });
}
