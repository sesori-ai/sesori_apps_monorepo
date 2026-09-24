import "package:sesori_shared/sesori_shared.dart" show NotificationCategory;

class PushRateLimiter({DateTime Function()? now}) {
  static const staleEntryTtl = Duration(minutes: 30);

  final DateTime Function() _now = now ?? DateTime.now;
  final Map<String, DateTime> _lastSent = {};

  static const _cooldowns = {
    // Each question or permission can block the agent. Suppressed sends are
    // discarded, not deferred, so interactions must not throttle one another.
    NotificationCategory.aiInteraction: Duration.zero,
    NotificationCategory.sessionMessage: Duration(seconds: 30),
    NotificationCategory.systemUpdate: Duration.zero,
  };

  int get retainedKeyCount => _lastSent.length;

  int pruneStaleEntries({Duration ttl = staleEntryTtl}) {
    final cutoff = _now().subtract(ttl);
    final previousCount = _lastSent.length;
    _lastSent.removeWhere(
      (_, lastSentAt) => lastSentAt.isBefore(cutoff),
    );
    return previousCount - _lastSent.length;
  }

  bool shouldSend({
    required NotificationCategory category,
    required String? sessionId,
    required String rateLimitKey,
  }) {
    final cooldown = _cooldowns[category] ?? const Duration(seconds: 30);
    if (cooldown == Duration.zero) {
      return true;
    }

    final now = _now();
    final last = _lastSent[rateLimitKey];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastSent[rateLimitKey] = now;
    return true;
  }
}
