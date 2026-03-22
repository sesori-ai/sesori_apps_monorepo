import "package:sesori_shared/sesori_shared.dart";

NotificationCategory? categorizeEvent(SesoriSseEvent event) {
  return switch (event) {
    SesoriQuestionAsked() => NotificationCategory.aiInteraction,
    SesoriPermissionAsked() => NotificationCategory.aiInteraction,
    SesoriMessageUpdated() => NotificationCategory.sessionMessage,
    SesoriInstallationUpdateAvailable() => NotificationCategory.systemUpdate,
    _ => null,
  };
}

SendNotificationPayload? buildNotificationPayload(
  SesoriSseEvent event,
  NotificationCategory category,
) {
  final sessionId = extractSessionId(event);
  final eventType = switch (event) {
    SesoriQuestionAsked() => "questionAsked",
    SesoriPermissionAsked() => "permissionAsked",
    SesoriMessageUpdated() => "messageUpdated",
    SesoriInstallationUpdateAvailable() => "installationUpdateAvailable",
    _ => null,
  };
  final rawData = NotificationData(
    category: category,
    sessionId: sessionId,
    eventType: eventType,
  ).toJson();
  final data = Map<String, String>.fromEntries(
    rawData.entries.where((entry) => entry.value != null).map((entry) => MapEntry(entry.key, entry.value.toString())),
  );
  final payloadData = data.isEmpty ? null : data;
  final collapseKey = sessionId == null ? null : "${_categoryId(category)}-$sessionId";

  return switch ((category, event)) {
    (NotificationCategory.aiInteraction, SesoriQuestionAsked(:final questions)) => SendNotificationPayload(
      category: category,
      title: "Question requires input",
      body: questions.isNotEmpty ? questions.first.question : "The assistant is waiting for your response.",
      collapseKey: collapseKey,
      data: payloadData,
    ),
    (
      NotificationCategory.aiInteraction,
      SesoriPermissionAsked(:final tool, :final description),
    ) =>
      SendNotificationPayload(
        category: category,
        title: "Permission requested",
        body: description.isNotEmpty ? description : "The assistant requested permission to run $tool.",
        collapseKey: collapseKey,
        data: payloadData,
      ),
    (
      NotificationCategory.sessionMessage,
      SesoriMessageUpdated(:final info),
    ) =>
      SendNotificationPayload(
        category: category,
        title: "New session message",
        body: "${info.role} updated message ${info.id}",
        collapseKey: collapseKey,
        data: payloadData,
      ),
    (
      NotificationCategory.systemUpdate,
      SesoriInstallationUpdateAvailable(:final version),
    ) =>
      SendNotificationPayload(
        category: category,
        title: "Bridge update available",
        body: (version != null && version.isNotEmpty)
            ? "Version $version is available."
            : "A new bridge version is available.",
        collapseKey: collapseKey,
        data: payloadData,
      ),
    _ => null,
  };
}

String _categoryId(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.aiInteraction => "ai_interaction",
    NotificationCategory.sessionMessage => "session_message",
    NotificationCategory.connectionStatus => "connection_status",
    NotificationCategory.systemUpdate => "system_update",
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
