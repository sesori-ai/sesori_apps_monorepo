import "package:sesori_shared/sesori_shared.dart";

class const PushNotificationContentBuilder() {
  String truncateTitle({required String title, int maxChars = 50}) {
    final normalized = title.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }

    final cutoffIndex = normalized.lastIndexOf(" ", maxChars);
    final safeCutoff = cutoffIndex > 0 ? cutoffIndex : maxChars;
    return "${normalized.substring(0, safeCutoff).trimRight()}...";
  }

  String truncateToWords({required String text, int maxWords = 10}) {
    final words = text.trim().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
    if (words.length <= maxWords) {
      return words.join(" ");
    }

    return "${words.take(maxWords).join(" ")}...";
  }

  /// The push content for [event], or null when it raises no immediate push.
  ///
  /// A permission or question prompt targets its display (root) session, so
  /// the collapse key and deep link open the session the request is surfaced
  /// on (a sub-agent request surfaces on its root). The owner session is the
  /// one that raised the prompt.
  ({
    NotificationCategory category,
    NotificationEventType eventType,
    String title,
    String body,
    ({String displaySessionId, String ownerSessionId})? session,
  })?
  extractNotificationData({required SesoriSseEvent event}) {
    return switch (event) {
      SesoriQuestionAsked(:final questions, :final sessionID, :final displaySessionId) => (
        category: NotificationCategory.aiInteraction,
        eventType: NotificationEventType.questionAsked,
        title: "Question requires input",
        body: questions.isNotEmpty ? questions.first.question : "The assistant is waiting for your response.",
        session: (displaySessionId: displaySessionId ?? sessionID, ownerSessionId: sessionID),
      ),
      SesoriPermissionAsked(:final tool, :final description, :final sessionID, :final displaySessionId) => (
        category: NotificationCategory.aiInteraction,
        eventType: NotificationEventType.permissionAsked,
        title: "Permission requested",
        body: description.isNotEmpty
            ? _markdownToPlainText(markdown: description)
            : "The assistant requested permission to run $tool.",
        session: (displaySessionId: displaySessionId ?? sessionID, ownerSessionId: sessionID),
      ),
      SesoriInstallationUpdateAvailable(:final version) => (
        category: NotificationCategory.systemUpdate,
        eventType: NotificationEventType.installationUpdateAvailable,
        title: "Bridge update available",
        body: (version != null && version.isNotEmpty)
            ? "Version $version is available."
            : "A new bridge version is available.",
        session: null,
      ),
      SesoriServerConnected() ||
      SesoriServerHeartbeat() ||
      SesoriServerInstanceDisposed() ||
      SesoriGlobalDisposed() ||
      SesoriCatalogImportProgress() ||
      SesoriPluginManagementChanged() ||
      SesoriMcpInventoryChanged() ||
      SesoriMcpAuthenticationChanged() ||
      SesoriPluginInstallProgress() ||
      SesoriPluginAuthenticationProgress() ||
      SesoriSessionOptionsUpdated() ||
      SesoriSessionCreated() ||
      SesoriSessionUpdated() ||
      SesoriSessionDeleted() ||
      SesoriSessionDiff() ||
      SesoriSessionError() ||
      SesoriSessionCompacted() ||
      SesoriSessionHistoryRefreshed() ||
      SesoriSessionPromptSettled() ||
      SesoriSessionPromptDefaultsChanged() ||
      SesoriSessionStatus() ||
      SesoriCommandExecuted() ||
      SesoriSessionQueuedPrompts() ||
      SesoriMessageUpdated() ||
      SesoriMessageRemoved() ||
      SesoriMessagePartUpdated() ||
      SesoriMessagePartDelta() ||
      SesoriMessagePartRemoved() ||
      SesoriPermissionReplied() ||
      SesoriPermissionUpdated() ||
      SesoriQuestionReplied() ||
      SesoriQuestionRejected() ||
      SesoriTodoUpdated() ||
      SesoriProjectsSummary() ||
      SesoriProjectUpdated() ||
      SesoriVcsBranchUpdated() ||
      SesoriSessionUnseenChanged() ||
      SesoriFileEdited() ||
      SesoriTuiToastShow() => null,
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
    required String? bridgeId,
  }) {
    final data = NotificationData(
      category: category,
      sessionId: sessionId,
      eventType: eventType,
      projectId: projectId,
      bridgeId: bridgeId,
    );

    return SendNotificationPayload(
      category: category,
      title: title,
      body: body,
      collapseKey: collapseKey,
      data: data,
    );
  }

  /// A permission description is Markdown rendered by the app; the OS shows
  /// the push body verbatim. Drop the code-block indentation and fences and
  /// inline code-span backticks the descriptions use, plus blank lines.
  // ponytail: covers the code constructs plugins emit, not general Markdown.
  String _markdownToPlainText({required String markdown}) {
    // CommonMark drops one padding space each side of a code span's text.
    final codeSpan = RegExp(r"(`+) ?(.+?) ?\1");
    return markdown
        .split("\n")
        .where((line) => line.trim().isNotEmpty && !line.trimLeft().startsWith("```"))
        .map(
          (line) => line.startsWith("    ") || line.startsWith("\t")
              ? line.trim()
              : line.replaceAllMapped(codeSpan, (match) => match[2] ?? "").trim(),
        )
        .join("\n");
  }
}
