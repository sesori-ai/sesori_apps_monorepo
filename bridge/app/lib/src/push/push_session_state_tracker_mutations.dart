import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker_state.dart";

void upsertTrackedSession({
  required Session session,
  required DateTime touchedAt,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  final sessionState = stateForTrackedSession(
    sessionId: session.id,
    sessions: sessions,
    touchedAt: touchedAt,
  );
  final prevParentId = sessionState.parentId;
  final nextParentId = session.parentID;

  if (prevParentId != null && prevParentId != nextParentId) {
    sessions[prevParentId]?.childIds.remove(session.id);
  }

  sessionState.parentId = nextParentId;
  sessionState.title = session.title;
  sessionState.projectId = session.projectID;

  if (nextParentId != null) {
    sessions[nextParentId]?.childIds.add(session.id);
  }
  rebuildTrackedChildLinksForParent(parentId: session.id, sessions: sessions);
}

void deleteTrackedSession({
  required String sessionId,
  required Map<String, PushTrackedSessionState> sessions,
  required Map<String, PushTrackedMessageRole> messageRoles,
  required Map<String, String> permissionRequestToSession,
}) {
  final removedSessionState = sessions.remove(sessionId);
  final orphanedChildIds =
      removedSessionState?.childIds.toList(growable: false) ??
      sessions.entries
          .where((entry) => entry.value.parentId == sessionId)
          .map((entry) => entry.key)
          .toList(growable: false);

  if (removedSessionState != null) {
    if (removedSessionState.parentId != null) {
      sessions[removedSessionState.parentId]?.childIds.remove(sessionId);
    }

    removedSessionState.messageIds.forEach(messageRoles.remove);
  }

  for (final childId in orphanedChildIds) {
    final childState = sessions[childId];
    if (childState != null && childState.parentId == sessionId) {
      childState.parentId = null;
    }
  }

  permissionRequestToSession.removeWhere((_, value) => value == sessionId);
}

void applyTrackedProjectsSummaryChildLinks({
  required List<ProjectActivitySummary> projects,
  required Map<String, PushTrackedSessionState> sessions,
  required DateTime touchedAt,
}) {
  for (final project in projects) {
    for (final activeSession in project.activeSessions) {
      stateForTrackedSession(sessionId: activeSession.id, sessions: sessions, touchedAt: touchedAt).projectId =
          project.id;
      for (final childId in activeSession.childSessionIds) {
        final childState = stateForTrackedSession(sessionId: childId, sessions: sessions, touchedAt: touchedAt);
        childState.projectId = project.id;
        if (childState.parentId == null) {
          childState.parentId = activeSession.id;
          stateForTrackedSession(sessionId: activeSession.id, sessions: sessions, touchedAt: touchedAt).childIds.add(
            childId,
          );
        }
      }
    }
  }
}

void rebuildTrackedChildLinksForParent({
  required String parentId,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  final parentState = sessions[parentId];
  if (parentState == null) {
    return;
  }

  parentState.childIds.removeWhere((childId) => sessions[childId]?.parentId != parentId);
  for (final entry in sessions.entries) {
    if (entry.value.parentId == parentId) {
      parentState.childIds.add(entry.key);
    }
  }
}

void updateTrackedLatestAssistantText({
  required MessagePart part,
  required Map<String, PushTrackedSessionState> sessions,
  required Map<String, PushTrackedMessageRole> messageRoles,
}) {
  if (part.type != MessagePartType.text || messageRoles[part.messageID]?.role != "assistant") {
    return;
  }

  stateForTrackedSession(sessionId: part.sessionID, sessions: sessions).latestAssistantText = part.text ?? "";
}

PushTrackedSessionState stateForTrackedSession({
  required String sessionId,
  required Map<String, PushTrackedSessionState> sessions,
  DateTime? touchedAt,
}) {
  final sessionState = sessions.putIfAbsent(sessionId, PushTrackedSessionState.new);
  if (touchedAt != null) {
    sessionState.lastTouchedAt = touchedAt;
  }
  return sessionState;
}

void trackMessageForSession({
  required String sessionId,
  required String messageId,
  required Map<String, PushTrackedSessionState> sessions,
  DateTime? touchedAt,
}) {
  stateForTrackedSession(sessionId: sessionId, sessions: sessions, touchedAt: touchedAt).messageIds.add(messageId);
}

String? untrackMessage({
  required String messageId,
  required Map<String, PushTrackedSessionState> sessions,
  required Map<String, PushTrackedMessageRole> messageRoles,
}) {
  final sessionId = messageRoles.remove(messageId)?.sessionId;
  if (sessionId != null) {
    sessions[sessionId]?.messageIds.remove(messageId);
  }
  return sessionId;
}
