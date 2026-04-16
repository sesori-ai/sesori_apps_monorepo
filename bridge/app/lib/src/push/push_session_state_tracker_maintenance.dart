import "push_session_state_tracker_graph.dart";
import "push_session_state_tracker_models.dart";
import "push_session_state_tracker_state.dart";

List<PushPrunableRoot> findTrackedPrunableRoots({
  required Map<String, PushTrackedSessionState> sessions,
  required DateTime now,
}) {
  final cutoff = now.subtract(PushSessionMaintenancePolicy.rootIdlePruneTtl);
  final prunableRoots = <PushPrunableRoot>[];

  for (final rootSessionId in findTrackedRootSessionIds(sessions: sessions)) {
    final idleSince = resolveTrackedRootIdleSince(rootSessionId: rootSessionId, sessions: sessions);
    if (idleSince == null || idleSince.isAfter(cutoff)) {
      continue;
    }

    prunableRoots.add(
      PushPrunableRoot(
        rootSessionId: rootSessionId,
        idleSince: idleSince,
        retainedSessionCount: collectTrackedSubtreeSessionIds(
          rootSessionId: rootSessionId,
          sessions: sessions,
        ).length,
      ),
    );
  }

  return prunableRoots;
}

PushSessionTelemetrySnapshot buildTrackedTelemetrySnapshot({
  required Map<String, PushTrackedSessionState> sessions,
  required Map<String, PushTrackedMessageRole> messageRoles,
  required int permissionRequestCount,
  required DateTime now,
}) {
  final rootSessionIds = findTrackedRootSessionIds(sessions: sessions);
  var idleRootCount = 0;
  for (final rootSessionId in rootSessionIds) {
    if (resolveTrackedRootIdleSince(rootSessionId: rootSessionId, sessions: sessions) != null) {
      idleRootCount += 1;
    }
  }

  var busySessionCount = 0;
  var pendingQuestionCount = 0;
  var pendingPermissionCount = 0;
  var previouslyBusyCount = 0;
  var latestAssistantTextCount = 0;
  var latestAssistantTextCharCount = 0;
  DateTime? oldestSessionActivityAt;
  for (final sessionState in sessions.values) {
    if (sessionState.status != null) {
      busySessionCount += 1;
    }
    if (sessionState.hasPendingQuestion) {
      pendingQuestionCount += 1;
    }
    if (sessionState.hasPendingPermission) {
      pendingPermissionCount += 1;
    }
    if (sessionState.previouslyBusy) {
      previouslyBusyCount += 1;
    }
    final latestAssistantText = sessionState.latestAssistantText;
    if (latestAssistantText != null) {
      latestAssistantTextCount += 1;
      latestAssistantTextCharCount += latestAssistantText.length;
    }

    final touchedAt = sessionState.lastTouchedAt;
    if (touchedAt == null) {
      continue;
    }
    if (oldestSessionActivityAt == null || touchedAt.isBefore(oldestSessionActivityAt)) {
      oldestSessionActivityAt = touchedAt;
    }
  }

  DateTime? oldestMessageRoleUpdatedAt;
  for (final messageRole in messageRoles.values) {
    if (oldestMessageRoleUpdatedAt == null || messageRole.updatedAt.isBefore(oldestMessageRoleUpdatedAt)) {
      oldestMessageRoleUpdatedAt = messageRole.updatedAt;
    }
  }

  return PushSessionTelemetrySnapshot(
    sessionCount: sessions.length,
    rootSessionCount: rootSessionIds.length,
    idleRootCount: idleRootCount,
    busySessionCount: busySessionCount,
    pendingQuestionCount: pendingQuestionCount,
    pendingPermissionCount: pendingPermissionCount,
    permissionRequestCount: permissionRequestCount,
    previouslyBusyCount: previouslyBusyCount,
    latestAssistantTextCount: latestAssistantTextCount,
    latestAssistantTextCharCount: latestAssistantTextCharCount,
    messageRoleCount: messageRoles.length,
    assistantMessageRoleCount: messageRoles.values.where((messageRole) => messageRole.role == "assistant").length,
    oldestSessionActivityAt: oldestSessionActivityAt,
    oldestMessageRoleUpdatedAt: oldestMessageRoleUpdatedAt,
    prunableRoots: findTrackedPrunableRoots(sessions: sessions, now: now),
  );
}
