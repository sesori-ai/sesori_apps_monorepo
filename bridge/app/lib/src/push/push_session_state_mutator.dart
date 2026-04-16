import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker_state.dart";

class PushSessionStateMutator {
  final Map<String, PushTrackedSessionState> _sessions;
  final Map<String, PushTrackedMessageRole> _messageRoles;
  final Map<String, String> _permissionRequestToSession;

  PushSessionStateMutator({
    required Map<String, PushTrackedSessionState> sessions,
    required Map<String, PushTrackedMessageRole> messageRoles,
    required Map<String, String> permissionRequestToSession,
  }) : _sessions = sessions,
       _messageRoles = messageRoles,
       _permissionRequestToSession = permissionRequestToSession;

  void upsertSession({required Session session, required DateTime touchedAt}) {
    final sessionState = stateForSession(sessionId: session.id, touchedAt: touchedAt);
    final prevParentId = sessionState.parentId;
    final nextParentId = session.parentID;

    if (prevParentId != null && prevParentId != nextParentId) {
      _sessions[prevParentId]?.childIds.remove(session.id);
    }

    sessionState.parentId = nextParentId;
    sessionState.title = session.title;
    sessionState.projectId = session.projectID;

    if (nextParentId != null) {
      _sessions[nextParentId]?.childIds.add(session.id);
    }
    rebuildChildLinksForParent(parentId: session.id);
  }

  void deleteSession({required String sessionId}) {
    final removedSessionState = _sessions.remove(sessionId);
    final orphanedChildIds =
        removedSessionState?.childIds.toList(growable: false) ??
        _sessions.entries
            .where((entry) => entry.value.parentId == sessionId)
            .map((entry) => entry.key)
            .toList(growable: false);

    if (removedSessionState != null) {
      if (removedSessionState.parentId != null) {
        _sessions[removedSessionState.parentId]?.childIds.remove(sessionId);
      }

      removedSessionState.messageIds.forEach(_messageRoles.remove);
    }

    for (final childId in orphanedChildIds) {
      final childState = _sessions[childId];
      if (childState != null && childState.parentId == sessionId) {
        childState.parentId = null;
      }
    }

    _permissionRequestToSession.removeWhere((_, value) => value == sessionId);
  }

  void applyProjectsSummaryChildLinks({required List<ProjectActivitySummary> projects, required DateTime touchedAt}) {
    for (final project in projects) {
      for (final activeSession in project.activeSessions) {
        stateForSession(sessionId: activeSession.id, touchedAt: touchedAt).projectId = project.id;
        for (final childId in activeSession.childSessionIds) {
          final childState = stateForSession(sessionId: childId, touchedAt: touchedAt);
          childState.projectId = project.id;
          if (childState.parentId == null) {
            childState.parentId = activeSession.id;
            stateForSession(sessionId: activeSession.id, touchedAt: touchedAt).childIds.add(childId);
          }
        }
      }
    }
  }

  void rebuildChildLinksForParent({required String parentId}) {
    final parentState = _sessions[parentId];
    if (parentState == null) {
      return;
    }

    parentState.childIds.removeWhere((childId) => _sessions[childId]?.parentId != parentId);
    for (final entry in _sessions.entries) {
      if (entry.value.parentId == parentId) {
        parentState.childIds.add(entry.key);
      }
    }
  }

  void updateLatestAssistantText({required MessagePart part}) {
    if (part.type != MessagePartType.text || _messageRoles[part.messageID]?.role != "assistant") {
      return;
    }

    stateForSession(sessionId: part.sessionID).latestAssistantText = part.text ?? "";
  }

  PushTrackedSessionState stateForSession({required String sessionId, DateTime? touchedAt}) {
    final sessionState = _sessions.putIfAbsent(sessionId, PushTrackedSessionState.new);
    if (touchedAt != null) {
      sessionState.lastTouchedAt = touchedAt;
    }
    return sessionState;
  }

  void trackMessageForSession({required String sessionId, required String messageId, DateTime? touchedAt}) {
    stateForSession(sessionId: sessionId, touchedAt: touchedAt).messageIds.add(messageId);
  }

  String? untrackMessage({required String messageId}) {
    final sessionId = _messageRoles.remove(messageId)?.sessionId;
    if (sessionId != null) {
      _sessions[sessionId]?.messageIds.remove(messageId);
    }
    return sessionId;
  }
}
