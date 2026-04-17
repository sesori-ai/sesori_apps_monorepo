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

  void dispatchCompletionForRoot({required String rootSessionId}) {
    final sessionTitle = _tracker.getSessionTitle(rootSessionId);
    final latestAssistantText = _tracker.getLatestAssistantText(rootSessionId);

    final title = _contentBuilder.truncateTitle(
      (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
    );
    final body = _contentBuilder.truncateToWords(
      (latestAssistantText == null || latestAssistantText.trim().isEmpty) ? "Task completed" : latestAssistantText,
    );

    _tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: rootSessionId);

    _sendNotification(
      category: NotificationCategory.sessionMessage,
      eventType: NotificationEventType.agentTurnCompleted,
      title: title,
      body: body,
      sessionId: rootSessionId,
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

    _sendNotification(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: _contentBuilder.extractSessionId(event),
    );
  }

  void _sendNotification({
    required NotificationCategory category,
    required NotificationEventType eventType,
    required String title,
    required String body,
    required String? sessionId,
  }) {
    final collapseKey = "${category.id}-${sessionId ?? "global"}";
    if (!_rateLimiter.shouldSend(
      category: category,
      collapseKey: collapseKey,
      sessionId: sessionId,
    )) {
      return;
    }

    final payload = _contentBuilder.buildNotificationPayload(
      category: category,
      eventType: eventType,
      title: title,
      body: body,
      sessionId: sessionId,
      collapseKey: collapseKey,
      projectId: sessionId != null ? _tracker.getSessionProjectId(sessionId: sessionId) : null,
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
