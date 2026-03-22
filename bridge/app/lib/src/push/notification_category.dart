import "package:sesori_shared/sesori_shared.dart";

enum NotificationCategory {
  aiInteraction("ai_interaction"),
  sessionMessage("session_message"),
  systemUpdate("system_update")
  ;

  const NotificationCategory(this.id);
  final String id;
}

NotificationCategory? categorizeEvent(SesoriSseEvent event) {
  return switch (event) {
    SesoriQuestionAsked() => NotificationCategory.aiInteraction,
    SesoriPermissionAsked() => NotificationCategory.aiInteraction,
    SesoriMessageUpdated() => NotificationCategory.sessionMessage,
    SesoriInstallationUpdateAvailable() => NotificationCategory.systemUpdate,
    _ => null,
  };
}

({String title, String body, String? collapseKey, Map<String, String>? data})? buildNotificationPayload(
  SesoriSseEvent event,
  NotificationCategory category,
) {
  final sessionId = extractSessionId(event);
  final data = sessionId == null ? null : <String, String>{"sessionId": sessionId};
  final collapseKey = sessionId == null ? null : "${category.id}-$sessionId";

  return switch ((category, event)) {
    (NotificationCategory.aiInteraction, SesoriQuestionAsked(:final questions)) => (
      title: "Question requires input",
      body: questions.isNotEmpty ? questions.first.question : "The assistant is waiting for your response.",
      collapseKey: collapseKey,
      data: data,
    ),
    (NotificationCategory.aiInteraction, SesoriPermissionAsked(:final tool, :final description)) => (
      title: "Permission requested",
      body: description.isNotEmpty ? description : "The assistant requested permission to run $tool.",
      collapseKey: collapseKey,
      data: data,
    ),
    (NotificationCategory.sessionMessage, SesoriMessageUpdated(:final info)) => (
      title: "New session message",
      body: "${info.role} updated message ${info.id}",
      collapseKey: collapseKey,
      data: data,
    ),
    (NotificationCategory.systemUpdate, SesoriInstallationUpdateAvailable(:final version)) => (
      title: "Bridge update available",
      body: (version != null && version.isNotEmpty)
          ? "Version $version is available."
          : "A new bridge version is available.",
      collapseKey: collapseKey,
      data: data,
    ),
    _ => null,
  };
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
