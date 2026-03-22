import "package:sesori_shared/sesori_shared.dart" show NotificationCategory;

class PushRateLimiter {
  final DateTime Function() _now;
  final Map<String, DateTime> _lastSent = {};

  PushRateLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _cooldowns = {
    NotificationCategory.aiInteraction: Duration(seconds: 5),
    NotificationCategory.sessionMessage: Duration(seconds: 30),
    NotificationCategory.systemUpdate: Duration.zero,
  };

  bool shouldSend({
    required NotificationCategory category,
    required String? sessionId,
    required String collapseKey,
  }) {
    final cooldown = _cooldowns[category] ?? const Duration(seconds: 30);
    if (cooldown == Duration.zero) {
      return true;
    }

    final now = _now();
    final last = _lastSent[collapseKey];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastSent[collapseKey] = now;
    return true;
  }
}
