import "dart:async";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/token_refresh_exception.dart";
import "completion_notifier.dart";
import "push_notification_client.dart";
import "push_rate_limiter.dart";
import "push_send_exception.dart";
import "push_session_state_tracker.dart";

class PushNotificationService {
  final PushNotificationClient _client;
  final PushRateLimiter _rateLimiter;
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  late final StreamSubscription<String> _completionSubscription;

  PushNotificationService({
    required PushNotificationClient client,
    required PushRateLimiter rateLimiter,
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
  }) : _client = client,
       _rateLimiter = rateLimiter,
       _tracker = tracker,
       _completionNotifier = completionNotifier {
    _completionSubscription = _completionNotifier.completions.listen(_sendCompletionNotification);
  }

  void handleSseEvent(SesoriSseEvent event) {
    _tracker.handleEvent(event);
    _completionNotifier.handleEvent(event);
    _sendImmediateNotificationIfApplicable(event);
  }

  /// Marks a session as user-aborted so the completion notification is
  /// suppressed for the current busy→idle transition.
  void markSessionAborted(String sessionId) {
    _completionNotifier.markSessionAborted(sessionId);
  }

  Future<void> dispose() async {
    await _completionSubscription.cancel();
    _completionNotifier.dispose();
  }

  void reset() {
    _completionNotifier.reset();
    _tracker.reset();
  }

  void _sendImmediateNotificationIfApplicable(SesoriSseEvent event) {
    final notificationData = extractNotificationData(event);
    if (notificationData == null) {
      return;
    }

    _sendNotification(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: extractSessionId(event),
    );
  }

  void _sendCompletionNotification(String rootSessionId) {
    final sessionTitle = _tracker.getSessionTitle(rootSessionId);
    final latestAssistantText = _tracker.getLatestAssistantText(rootSessionId);

    final title = truncateTitle(
      (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
    );
    final body = truncateToWords(
      (latestAssistantText == null || latestAssistantText.trim().isEmpty) ? "Task completed" : latestAssistantText,
    );

    _sendNotification(
      category: NotificationCategory.sessionMessage,
      eventType: NotificationEventType.agentTurnCompleted,
      title: title,
      body: body,
      sessionId: rootSessionId,
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

    final payload = buildNotificationPayload(
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

@visibleForTesting
String truncateTitle(String title, {int maxChars = 50}) {
  final normalized = title.trim();
  if (normalized.length <= maxChars) {
    return normalized;
  }

  final cutoffIndex = normalized.lastIndexOf(" ", maxChars);
  final safeCutoff = cutoffIndex > 0 ? cutoffIndex : maxChars;
  return "${normalized.substring(0, safeCutoff).trimRight()}...";
}

@visibleForTesting
String truncateToWords(String text, {int maxWords = 10}) {
  final words = text.trim().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
  if (words.length <= maxWords) {
    return words.join(" ");
  }

  return "${words.take(maxWords).join(" ")}...";
}

@visibleForTesting
({
  NotificationCategory category,
  NotificationEventType eventType,
  String title,
  String body,
})?
extractNotificationData(SesoriSseEvent event) {
  return switch (event) {
    SesoriQuestionAsked(:final questions) => (
      category: NotificationCategory.aiInteraction,
      eventType: NotificationEventType.questionAsked,
      title: "Question requires input",
      body: questions.isNotEmpty ? questions.first.question : "The assistant is waiting for your response.",
    ),
    SesoriPermissionAsked(:final tool, :final description) => (
      category: NotificationCategory.aiInteraction,
      eventType: NotificationEventType.permissionAsked,
      title: "Permission requested",
      body: description.isNotEmpty ? description : "The assistant requested permission to run $tool.",
    ),
    SesoriInstallationUpdateAvailable(:final version) => (
      category: NotificationCategory.systemUpdate,
      eventType: NotificationEventType.installationUpdateAvailable,
      title: "Bridge update available",
      body: (version != null && version.isNotEmpty)
          ? "Version $version is available."
          : "A new bridge version is available.",
    ),
    _ => null,
  };
}

@visibleForTesting
SendNotificationPayload buildNotificationPayload({
  required NotificationCategory category,
  required NotificationEventType eventType,
  required String title,
  required String body,
  required String collapseKey,
  required String? sessionId,
  required String? projectId,
}) {
  final data = NotificationData(
    category: category,
    sessionId: sessionId,
    eventType: eventType,
    projectId: projectId,
  );

  return SendNotificationPayload(
    category: category,
    title: title,
    body: body,
    collapseKey: collapseKey,
    data: data,
  );
}

@visibleForTesting
String? extractSessionId(SesoriSseEvent event) {
  return switch (event) {
    SesoriSessionCreated(:final info) => info.id,
    SesoriSessionUpdated(:final info) => info.id,
    SesoriSessionDeleted(:final info) => info.id,
    SesoriSessionDiff(:final sessionID) => sessionID,
    SesoriSessionError(:final sessionID) => sessionID,
    SesoriSessionCompacted(:final sessionID) => sessionID,
    SesoriSessionStatus(:final sessionID) => sessionID,
    SesoriMessageUpdated(:final info) => info.sessionID,
    SesoriMessageRemoved(:final sessionID) => sessionID,
    SesoriMessagePartUpdated(:final part) => part.sessionID,
    SesoriMessagePartDelta(:final sessionID) => sessionID,
    SesoriMessagePartRemoved(:final sessionID) => sessionID,
    SesoriPermissionAsked(:final sessionID) => sessionID,
    SesoriQuestionAsked(:final sessionID) => sessionID,
    SesoriQuestionReplied(:final sessionID) => sessionID,
    SesoriQuestionRejected(:final sessionID) => sessionID,
    SesoriTodoUpdated(:final sessionID) => sessionID,
    _ => null,
  };
}
