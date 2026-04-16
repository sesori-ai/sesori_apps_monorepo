import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_mutator.dart";
import "push_session_state_tracker_state.dart";

class PushSessionEventReducer {
  final Map<String, PushTrackedSessionState> _sessions;
  final Map<String, PushTrackedMessageRole> _messageRoles;
  final Map<String, String> _permissionRequestToSession;
  final PushSessionStateMutator _mutator;

  PushSessionEventReducer({
    required Map<String, PushTrackedSessionState> sessions,
    required Map<String, PushTrackedMessageRole> messageRoles,
    required Map<String, String> permissionRequestToSession,
    required PushSessionStateMutator mutator,
  }) : _sessions = sessions,
       _messageRoles = messageRoles,
       _permissionRequestToSession = permissionRequestToSession,
       _mutator = mutator;

  void handleEvent({required SesoriSseEvent event, required DateTime now}) {
    switch (event) {
      case SesoriSessionCreated(:final info):
        _mutator.upsertSession(session: info, touchedAt: now);
      case SesoriSessionUpdated(:final info):
        _mutator.upsertSession(session: info, touchedAt: now);
      case SesoriSessionDeleted(:final info):
        _mutator.deleteSession(sessionId: info.id);
      case SesoriSessionStatus(:final sessionID, :final status):
        final sessionState = _mutator.stateForSession(sessionId: sessionID, touchedAt: now);
        switch (status) {
          case SessionStatusIdle():
            sessionState.status = null;
          case SessionStatusBusy():
          case SessionStatusRetry():
            sessionState.status = status;
            sessionState.previouslyBusy = true;
        }
      case SesoriMessageUpdated(:final info):
        _messageRoles[info.id] = PushTrackedMessageRole(role: info.role, sessionId: info.sessionID, updatedAt: now);
        _mutator.trackMessageForSession(sessionId: info.sessionID, messageId: info.id, touchedAt: now);
        _mutator.stateForSession(sessionId: info.sessionID, touchedAt: now);
      case SesoriMessageRemoved(:final messageID):
        final sessionId = _mutator.untrackMessage(messageId: messageID);
        if (sessionId != null) {
          _mutator.stateForSession(sessionId: sessionId, touchedAt: now);
        }
      case SesoriMessagePartUpdated(:final part):
        final messageRole = _messageRoles[part.messageID];
        if (messageRole != null) {
          _messageRoles[part.messageID] = PushTrackedMessageRole(
            role: messageRole.role,
            sessionId: messageRole.sessionId,
            updatedAt: now,
          );
        }
        _mutator.stateForSession(sessionId: part.sessionID, touchedAt: now);
        _mutator.updateLatestAssistantText(part: part);
      case SesoriQuestionAsked(:final sessionID):
        _mutator.stateForSession(sessionId: sessionID, touchedAt: now).hasPendingQuestion = true;
      case SesoriQuestionReplied(:final sessionID):
        final sessionState = _sessions[sessionID];
        if (sessionState != null) {
          sessionState.hasPendingQuestion = false;
          sessionState.lastTouchedAt = now;
        }
      case SesoriQuestionRejected(:final sessionID):
        final sessionState = _sessions[sessionID];
        if (sessionState != null) {
          sessionState.hasPendingQuestion = false;
          sessionState.lastTouchedAt = now;
        }
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _mutator.stateForSession(sessionId: sessionID, touchedAt: now).hasPendingPermission = true;
      case SesoriPermissionReplied(:final requestID):
        final sessionId = _permissionRequestToSession.remove(requestID);
        if (sessionId != null) {
          final sessionState = _sessions[sessionId];
          if (sessionState != null) {
            sessionState.hasPendingPermission = false;
            sessionState.lastTouchedAt = now;
          }
        }
      case SesoriProjectsSummary(:final projects):
        _mutator.applyProjectsSummaryChildLinks(projects: projects, touchedAt: now);
      default:
        break;
    }
  }
}
