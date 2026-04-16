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
  final idleRootCount = rootSessionIds
      .where((rootSessionId) => resolveTrackedRootIdleSince(rootSessionId: rootSessionId, sessions: sessions) != null)
      .length;
  DateTime? oldestSessionActivityAt;
  for (final sessionState in sessions.values) {
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
    busySessionCount: sessions.values.where((sessionState) => sessionState.status != null).length,
    pendingQuestionCount: sessions.values.where((sessionState) => sessionState.hasPendingQuestion).length,
    pendingPermissionCount: sessions.values.where((sessionState) => sessionState.hasPendingPermission).length,
    permissionRequestCount: permissionRequestCount,
    previouslyBusyCount: sessions.values.where((sessionState) => sessionState.previouslyBusy).length,
    latestAssistantTextCount: sessions.values.where((sessionState) => sessionState.latestAssistantText != null).length,
    latestAssistantTextCharCount: sessions.values
        .map((sessionState) => sessionState.latestAssistantText?.length ?? 0)
        .fold(0, (sum, count) => sum + count),
    messageRoleCount: messageRoles.length,
    assistantMessageRoleCount: messageRoles.values.where((messageRole) => messageRole.role == "assistant").length,
    oldestSessionActivityAt: oldestSessionActivityAt,
    oldestMessageRoleUpdatedAt: oldestMessageRoleUpdatedAt,
    prunableRoots: findTrackedPrunableRoots(sessions: sessions, now: now),
  );
}
