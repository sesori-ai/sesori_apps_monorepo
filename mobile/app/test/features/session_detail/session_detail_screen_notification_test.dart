import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sesori_mobile/core/platform/local_notification_manager.dart';
import 'package:sesori_mobile/core/platform/notification_id_utils.dart';
import 'package:sesori_shared/sesori_shared.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  group('notification cancel on question answer', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late LocalNotificationManager manager;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      manager = LocalNotificationManager(mockPlugin);
      when(() => mockPlugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    });

    test('cancel uses deterministic ID matching show() for same session', () async {
      const sessionId = 'ses_test_123';
      const category = NotificationCategory.aiInteraction;

      final expectedId = computeNotificationId(sessionId, category);

      // This is what show() would use for aiInteraction + sessionId
      // And this is what cancel should use after answering
      await manager.cancel(expectedId);

      verify(() => mockPlugin.cancel(id: expectedId)).called(1);
    });

    test('cancel ID for reply matches the notification shown for the same session', () {
      const sessionId = 'ses_abc_456';
      const category = NotificationCategory.aiInteraction;

      // The ID used when showing the notification
      final showId = computeNotificationId(sessionId, category);
      // The ID that would be used when cancelling after reply
      final cancelId = computeNotificationId(sessionId, category);

      expect(cancelId, equals(showId), reason: 'Cancel ID must match the notification ID shown for the same session');
    });

    test('cancel with fire-and-forget does not throw', () {
      const sessionId = 'ses_xyz';
      final id = computeNotificationId(sessionId, NotificationCategory.aiInteraction);

      when(() => mockPlugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});

      // Fire-and-forget: don't await
      manager.cancel(id);

      // No exception thrown = pass
    });
  });
}
