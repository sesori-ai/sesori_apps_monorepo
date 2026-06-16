import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("sessionNotificationId", () {
    test("returns an int", () {
      expect(sessionNotificationId(sessionId: "ses_abc"), isA<int>());
    });

    test("same input produces same output (deterministic)", () {
      final a = sessionNotificationId(sessionId: "ses_abc");
      final b = sessionNotificationId(sessionId: "ses_abc");
      final c = sessionNotificationId(sessionId: "ses_abc");
      expect(a, equals(b));
      expect(b, equals(c));
    });

    test("different sessions produce different outputs", () {
      expect(
        sessionNotificationId(sessionId: "ses_abc"),
        isNot(equals(sessionNotificationId(sessionId: "ses_xyz"))),
      );
    });

    test("output is within the safe Android range [0, 2^27 - 1]", () {
      const maxSafeId = 134217727; // 2^27 - 1
      for (final id in ["ses_abc", "ses_xyz", "ses_long_id_123", ""]) {
        final result = sessionNotificationId(sessionId: id);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThanOrEqualTo(maxSafeId));
      }
    });

    test("handles long, special-character, and unicode session IDs", () {
      const maxSafeId = 134217727;
      const ids = [
        "ses_very_long_session_id_with_many_characters_12345678901234567890",
        r"ses_!@#$%^&*()_+-=[]{}|;:,.<>?",
        "ses_日本語_中文_한글_العربية",
      ];
      for (final id in ids) {
        final result = sessionNotificationId(sessionId: id);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThanOrEqualTo(maxSafeId));
      }
    });
  });
}
