import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker_mutations.dart";
import "push_session_state_tracker_state.dart";

void handleTrackedEvent({
  required SesoriSseEvent event,
  required DateTime now,
  required Map<String, PushTrackedSessionState> sessions,
  required Map<String, PushTrackedMessageRole> messageRoles,
  required Map<String, String> permissionRequestToSession,
}) {
  switch (event) {
    case SesoriSessionCreated(:final info):
      upsertTrackedSession(session: info, touchedAt: now, sessions: sessions);
    case SesoriSessionUpdated(:final info):
      upsertTrackedSession(session: info, touchedAt: now, sessions: sessions);
    case SesoriSessionDeleted(:final info):
      deleteTrackedSession(
        sessionId: info.id,
        sessions: sessions,
        messageRoles: messageRoles,
        permissionRequestToSession: permissionRequestToSession,
      );
    case SesoriSessionStatus(:final sessionID, :final status):
      final sessionState = stateForTrackedSession(
        sessionId: sessionID,
        sessions: sessions,
        touchedAt: now,
      );
      switch (status) {
        case SessionStatusIdle():
          sessionState.status = null;
        case SessionStatusBusy():
        case SessionStatusRetry():
          sessionState.status = status;
          sessionState.previouslyBusy = true;
      }
    case SesoriMessageUpdated(:final info):
      messageRoles[info.id] = PushTrackedMessageRole(
        role: info.role,
        sessionId: info.sessionID,
        updatedAt: now,
      );
      trackMessageForSession(
        sessionId: info.sessionID,
        messageId: info.id,
        sessions: sessions,
        touchedAt: now,
      );
      stateForTrackedSession(sessionId: info.sessionID, sessions: sessions, touchedAt: now);
    case SesoriMessageRemoved(:final messageID):
      final sessionId = untrackMessage(
        messageId: messageID,
        sessions: sessions,
        messageRoles: messageRoles,
      );
      if (sessionId != null) {
        stateForTrackedSession(sessionId: sessionId, sessions: sessions, touchedAt: now);
      }
    case SesoriMessagePartUpdated(:final part):
      final messageRole = messageRoles[part.messageID];
      if (messageRole != null) {
        messageRoles[part.messageID] = PushTrackedMessageRole(
          role: messageRole.role,
          sessionId: messageRole.sessionId,
          updatedAt: now,
        );
      }
      stateForTrackedSession(sessionId: part.sessionID, sessions: sessions, touchedAt: now);
      updateTrackedLatestAssistantText(part: part, sessions: sessions, messageRoles: messageRoles);
    case SesoriQuestionAsked(:final sessionID):
      stateForTrackedSession(
        sessionId: sessionID,
        sessions: sessions,
        touchedAt: now,
      ).hasPendingQuestion = true;
    case SesoriQuestionReplied(:final sessionID):
      final sessionState = sessions[sessionID];
      if (sessionState != null) {
        sessionState.hasPendingQuestion = false;
        sessionState.lastTouchedAt = now;
      }
    case SesoriQuestionRejected(:final sessionID):
      final sessionState = sessions[sessionID];
      if (sessionState != null) {
        sessionState.hasPendingQuestion = false;
        sessionState.lastTouchedAt = now;
      }
    case SesoriPermissionAsked(:final requestID, :final sessionID):
      permissionRequestToSession[requestID] = sessionID;
      stateForTrackedSession(
        sessionId: sessionID,
        sessions: sessions,
        touchedAt: now,
      ).hasPendingPermission = true;
    case SesoriPermissionReplied(:final requestID):
      final sessionID = permissionRequestToSession.remove(requestID);
      if (sessionID != null) {
        final sessionState = sessions[sessionID];
        if (sessionState != null) {
          sessionState.hasPendingPermission = false;
          sessionState.lastTouchedAt = now;
        }
      }
    case SesoriProjectsSummary(:final projects):
      applyTrackedProjectsSummaryChildLinks(projects: projects, sessions: sessions, touchedAt: now);
    default:
      break;
  }
}
