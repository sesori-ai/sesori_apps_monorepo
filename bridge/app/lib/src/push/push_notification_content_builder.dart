import "package:sesori_shared/sesori_shared.dart";

class PushNotificationContentBuilder {
  const PushNotificationContentBuilder();

  String truncateTitle(String title, {int maxChars = 50}) {
    final normalized = title.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }

    final cutoffIndex = normalized.lastIndexOf(" ", maxChars);
    final safeCutoff = cutoffIndex > 0 ? cutoffIndex : maxChars;
    return "${normalized.substring(0, safeCutoff).trimRight()}...";
  }

  String truncateToWords(String text, {int maxWords = 10}) {
    final words = text.trim().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
    if (words.length <= maxWords) {
      return words.join(" ");
    }

    return "${words.take(maxWords).join(" ")}...";
  }

  ({NotificationCategory category, NotificationEventType eventType, String title, String body})?
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
}
