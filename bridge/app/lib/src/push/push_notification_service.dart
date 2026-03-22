import "dart:async";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

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
    final notificationData = extractNotificationData(event);
    if (notificationData == null) {
      return;
    }

    final sessionId = extractSessionId(event);
    final collapseKey = "${notificationData.category.id}-${sessionId ?? "global"}";
    if (!_rateLimiter.shouldSend(
      category: notificationData.category,
      collapseKey: collapseKey,
      sessionId: sessionId,
    )) {
      return;
    }

    final payload = buildNotificationPayload(
      category: notificationData.category,
      eventType: notificationData.eventType,
      title: notificationData.title,
      body: notificationData.body,
      sessionId: sessionId,
      collapseKey: collapseKey,
    );

    unawaited(
      _client.sendNotification(payload).catchError((Object e) => Log.w("[push] send error: $e")),
    );
  }
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
    SesoriMessageUpdated(:final info) => (
      category: NotificationCategory.sessionMessage,
      eventType: NotificationEventType.messageUpdated,
      title: "New session message",
      body: "${info.role} updated message ${info.id}",
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
}) {
  final data = NotificationData(
    category: category,
    sessionId: sessionId,
    eventType: eventType,
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
