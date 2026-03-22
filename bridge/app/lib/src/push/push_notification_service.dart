import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "notification_category.dart";
import "push_notification_client.dart";
import "push_rate_limiter.dart";

class PushNotificationService {
  final PushNotificationClient _client;
  final PushRateLimiter _rateLimiter;

  PushNotificationService({
    required PushNotificationClient client,
    required PushRateLimiter rateLimiter,
  }) : _client = client,
       _rateLimiter = rateLimiter;

  void maybeSendForEvent(SesoriSseEvent event) {
    final category = categorizeEvent(event);
    if (category == null) {
      return;
    }

    final sessionId = extractSessionId(event);
    if (!_rateLimiter.shouldSend(category, sessionId: sessionId)) {
      return;
    }

    final payload = buildNotificationPayload(event, category);
    if (payload == null) {
      return;
    }

    unawaited(
      _client.sendNotification(payload).catchError((Object e) => Log.w("[push] send error: $e")),
    );
  }
}
