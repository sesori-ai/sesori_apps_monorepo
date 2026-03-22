import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_shared/sesori_shared.dart" show NotificationCategory;
import "package:test/test.dart";

void main() {
  group("PushRateLimiter", () {
    test("first call sends and second call within cooldown is blocked", () {
      var now = DateTime(2026, 1, 1, 10, 0, 0);
      final limiter = PushRateLimiter(now: () => now);

      expect(
        limiter.shouldSend(
          category: NotificationCategory.aiInteraction,
          sessionId: "session-a",
          collapseKey: "ai_interaction-session-a",
        ),
        isTrue,
      );

      now = now.add(const Duration(seconds: 1));
      expect(
        limiter.shouldSend(
          category: NotificationCategory.aiInteraction,
          sessionId: "session-a",
          collapseKey: "ai_interaction-session-a",
        ),
        isFalse,
      );
    });

    test("different sessions are rate limited independently", () {
      final limiter = PushRateLimiter(now: () => DateTime(2026, 1, 1, 10, 0, 0));

      expect(
        limiter.shouldSend(
          category: NotificationCategory.sessionMessage,
          sessionId: "session-a",
          collapseKey: "session_message-session-a",
        ),
        isTrue,
      );
      expect(
        limiter.shouldSend(
          category: NotificationCategory.sessionMessage,
          sessionId: "session-b",
          collapseKey: "session_message-session-b",
        ),
        isTrue,
      );
    });

    test("system updates are always allowed", () {
      final limiter = PushRateLimiter(now: () => DateTime(2026, 1, 1, 10, 0, 0));

      expect(
        limiter.shouldSend(
          category: NotificationCategory.systemUpdate,
          sessionId: null,
          collapseKey: "system_update-global",
        ),
        isTrue,
      );
      expect(
        limiter.shouldSend(
          category: NotificationCategory.systemUpdate,
          sessionId: null,
          collapseKey: "system_update-global",
        ),
        isTrue,
      );
    });
  });
}
