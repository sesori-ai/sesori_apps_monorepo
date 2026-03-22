import "notification_category.dart";

class PushRateLimiter {
  final DateTime Function() _now;
  final Map<String, DateTime> _lastSent = {};

  PushRateLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _cooldowns = {
    NotificationCategory.aiInteraction: Duration(seconds: 5),
    NotificationCategory.sessionMessage: Duration(seconds: 30),
    NotificationCategory.systemUpdate: Duration.zero,
  };

  bool shouldSend(NotificationCategory category, {String? sessionId}) {
    final key = "${category.id}-${sessionId ?? "global"}";
    final cooldown = _cooldowns[category] ?? const Duration(seconds: 30);
    if (cooldown == Duration.zero) {
      return true;
    }

    final now = _now();
    final last = _lastSent[key];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastSent[key] = now;
    return true;
  }
}
