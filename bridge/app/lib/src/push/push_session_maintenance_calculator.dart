import "push_session_state_graph.dart";
import "push_session_state_tracker_models.dart";
import "push_session_state_tracker_state.dart";

class PushSessionMaintenanceCalculator {
  final Map<String, PushTrackedSessionState> _sessions;
  final Map<String, PushTrackedMessageRole> _messageRoles;
  final int Function() _permissionRequestCount;
  final PushSessionStateGraph _graph;
  final DateTime Function() _now;

  PushSessionMaintenanceCalculator({
    required Map<String, PushTrackedSessionState> sessions,
    required Map<String, PushTrackedMessageRole> messageRoles,
    required int Function() permissionRequestCount,
    required PushSessionStateGraph graph,
    required DateTime Function() now,
  }) : _sessions = sessions,
       _messageRoles = messageRoles,
       _permissionRequestCount = permissionRequestCount,
       _graph = graph,
       _now = now;

  List<PushPrunableRoot> findPrunableRoots() {
    final now = _now();
    final cutoff = now.subtract(PushSessionMaintenancePolicy.rootIdlePruneTtl);
    final prunableRoots = <PushPrunableRoot>[];

    for (final rootSessionId in _graph.findRootSessionIds()) {
      final idleSince = _graph.resolveRootIdleSince(rootSessionId: rootSessionId);
      if (idleSince == null || idleSince.isAfter(cutoff)) {
        continue;
      }

      prunableRoots.add(
        PushPrunableRoot(
          rootSessionId: rootSessionId,
          idleSince: idleSince,
          retainedSessionCount: _graph.collectSubtreeSessionIds(rootSessionId: rootSessionId).length,
        ),
      );
    }

    return prunableRoots;
  }

  PushSessionTelemetrySnapshot buildTelemetrySnapshot() {
    final rootSessionIds = _graph.findRootSessionIds();
    var idleRootCount = 0;
    for (final rootSessionId in rootSessionIds) {
      if (_graph.resolveRootIdleSince(rootSessionId: rootSessionId) != null) {
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
    for (final sessionState in _sessions.values) {
      if (sessionState.status != null) busySessionCount += 1;
      if (sessionState.hasPendingQuestion) pendingQuestionCount += 1;
      if (sessionState.hasPendingPermission) pendingPermissionCount += 1;
      if (sessionState.previouslyBusy) previouslyBusyCount += 1;
      final latestAssistantText = sessionState.latestAssistantText;
      if (latestAssistantText != null) {
        latestAssistantTextCount += 1;
        latestAssistantTextCharCount += latestAssistantText.length;
      }
      final touchedAt = sessionState.lastTouchedAt;
      if (touchedAt != null && (oldestSessionActivityAt == null || touchedAt.isBefore(oldestSessionActivityAt))) {
        oldestSessionActivityAt = touchedAt;
      }
    }

    DateTime? oldestMessageRoleUpdatedAt;
    for (final messageRole in _messageRoles.values) {
      if (oldestMessageRoleUpdatedAt == null || messageRole.updatedAt.isBefore(oldestMessageRoleUpdatedAt)) {
        oldestMessageRoleUpdatedAt = messageRole.updatedAt;
      }
    }

    return PushSessionTelemetrySnapshot(
      sessionCount: _sessions.length,
      rootSessionCount: rootSessionIds.length,
      idleRootCount: idleRootCount,
      busySessionCount: busySessionCount,
      pendingQuestionCount: pendingQuestionCount,
      pendingPermissionCount: pendingPermissionCount,
      permissionRequestCount: _permissionRequestCount(),
      previouslyBusyCount: previouslyBusyCount,
      latestAssistantTextCount: latestAssistantTextCount,
      latestAssistantTextCharCount: latestAssistantTextCharCount,
      messageRoleCount: _messageRoles.length,
      assistantMessageRoleCount: _messageRoles.values.where((messageRole) => messageRole.role == "assistant").length,
      oldestSessionActivityAt: oldestSessionActivityAt,
      oldestMessageRoleUpdatedAt: oldestMessageRoleUpdatedAt,
      prunableRoots: findPrunableRoots(),
    );
  }
}
