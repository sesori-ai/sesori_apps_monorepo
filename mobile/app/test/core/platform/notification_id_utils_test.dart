import 'package:flutter_test/flutter_test.dart';
import 'package:sesori_mobile/core/platform/notification_id_utils.dart';
import 'package:sesori_shared/sesori_shared.dart';

void main() {
  group('computeNotificationId', () {
    test('returns an int', () {
      final result = computeNotificationId('ses_abc', NotificationCategory.aiInteraction);
      expect(result, isA<int>());
    });

    test('same inputs produce same output (deterministic)', () {
      const sessionId = 'ses_abc';
      const category = NotificationCategory.aiInteraction;

      final result1 = computeNotificationId(sessionId, category);
      final result2 = computeNotificationId(sessionId, category);
      final result3 = computeNotificationId(sessionId, category);

      expect(result1, equals(result2));
      expect(result2, equals(result3));
    });

    test('different sessionIds produce different outputs', () {
      const category = NotificationCategory.aiInteraction;

      final result1 = computeNotificationId('ses_abc', category);
      final result2 = computeNotificationId('ses_xyz', category);

      expect(result1, isNot(equals(result2)));
    });

    test('different categories produce different outputs', () {
      const sessionId = 'ses_abc';

      final result1 = computeNotificationId(sessionId, NotificationCategory.aiInteraction);
      final result2 = computeNotificationId(sessionId, NotificationCategory.sessionMessage);

      expect(result1, isNot(equals(result2)));
    });

    test('output is within safe Android PendingIntent range [0, 2^27 - 1]', () {
      final result1 = computeNotificationId('ses_abc', NotificationCategory.aiInteraction);
      final result2 = computeNotificationId('ses_xyz', NotificationCategory.sessionMessage);
      final result3 = computeNotificationId('ses_long_id_123', NotificationCategory.connectionStatus);

      const maxSafeId = 134217727; // 2^27 - 1

      expect(result1, greaterThanOrEqualTo(0));
      expect(result1, lessThanOrEqualTo(maxSafeId));

      expect(result2, greaterThanOrEqualTo(0));
      expect(result2, lessThanOrEqualTo(maxSafeId));

      expect(result3, greaterThanOrEqualTo(0));
      expect(result3, lessThanOrEqualTo(maxSafeId));
    });

    test('works with long session IDs, special characters, and unicode', () {
      const longSessionId = 'ses_very_long_session_id_with_many_characters_12345678901234567890';
      const specialCharsId = r'ses_!@#$%^&*()_+-=[]{}|;:,.<>?';
      const unicodeId = 'ses_日本語_中文_한글_العربية';

      final result1 = computeNotificationId(longSessionId, NotificationCategory.aiInteraction);
      final result2 = computeNotificationId(specialCharsId, NotificationCategory.sessionMessage);
      final result3 = computeNotificationId(unicodeId, NotificationCategory.connectionStatus);

      const maxSafeId = 134217727;

      expect(result1, greaterThanOrEqualTo(0));
      expect(result1, lessThanOrEqualTo(maxSafeId));

      expect(result2, greaterThanOrEqualTo(0));
      expect(result2, lessThanOrEqualTo(maxSafeId));

      expect(result3, greaterThanOrEqualTo(0));
      expect(result3, lessThanOrEqualTo(maxSafeId));
    });
  });
}
