import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/token_refresh_exception.dart";
import "push_notification_client.dart";
import "push_notification_content_builder.dart";
import "push_rate_limiter.dart";
import "push_send_exception.dart";
import "push_session_state_tracker.dart";

class PushDispatcher {
  final PushNotificationClient _client;
  final PushRateLimiter _rateLimiter;
  final PushSessionStateTracker _tracker;
  final PushNotificationContentBuilder _contentBuilder;

  PushDispatcher({
    required PushNotificationClient client,
    required PushRateLimiter rateLimiter,
    required PushSessionStateTracker tracker,
    required PushNotificationContentBuilder contentBuilder,
  }) : _client = client,
       _rateLimiter = rateLimiter,
       _tracker = tracker,
       _contentBuilder = contentBuilder;

  void dispatchImmediateIfApplicable(SesoriSseEvent event) {
    _sendImmediateNotificationIfApplicable(event);
  }

  void dispatchCompletion({
    required String rootSessionId,
    required String title,
    required String body,
    required String? projectId,
  }) {
    _sendNotification(
      category: NotificationCategory.sessionMessage,
      eventType: NotificationEventType.agentTurnCompleted,
      title: title,
      body: body,
      sessionId: rootSessionId,
      projectId: projectId,
    );
  }

  Future<void> dispose() async {
    await _client.dispose();
  }

  void _sendImmediateNotificationIfApplicable(SesoriSseEvent event) {
    final notificationData = _contentBuilder.extractNotificationData(event);
    if (notificationData == null) {
      return;
    }

    final sessionId = _contentBuilder.extractSessionId(event);

    _sendNotification(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: sessionId,
      projectId: sessionId != null ? _tracker.getSessionProjectId(sessionId: sessionId) : null,
    );
  }

  void _sendNotification({
    required NotificationCategory category,
    required NotificationEventType eventType,
    required String title,
    required String body,
    required String? sessionId,
    required String? projectId,
  }) {
    // Rate limiting stays per category + session so a throttled completion never
    // suppresses a more urgent question (or vice versa) for the same session.
    final rateLimitKey = "${category.id}-${sessionId ?? "global"}";
    if (!_rateLimiter.shouldSend(
      category: category,
      rateLimitKey: rateLimitKey,
      sessionId: sessionId,
    )) {
      return;
    }

    // Session-scoped identity: every notification for a session collapses to one
    // (replace + dismiss key), independent of category. The auth server maps this
    // collapseKey to the Android notification.tag and the iOS apns-collapse-id, and
    // mobile derives the same value via sessionNotificationId for local rendering.
    final collapseKey = sessionId != null
        ? sessionNotificationId(sessionId: sessionId).toString()
        : "${category.id}-global";

    final payload = _contentBuilder.buildNotificationPayload(
      category: category,
      eventType: eventType,
      title: title,
      body: body,
      sessionId: sessionId,
      collapseKey: collapseKey,
      projectId: projectId,
    );

    unawaited(
      _client.sendNotification(payload).catchError((Object e) {
        if (e is TokenRefreshException || (e is PushSendException && e.statusCode == 401)) {
          Log.e("[push] auth failure, credentials may need re-authentication: $e");
        } else {
          Log.w("[push] send error: $e");
        }
      }),
    );
  }
}
