import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/normalized_bridge_event.dart";
import "plugin_message_mapper.dart";
import "plugin_session_status_mapper.dart";

class const SessionEventMapper() {
  /// Converts an id-translated event into the value higher layers consume.
  ///
  /// The final step of normalization: payload kinds with a typed shared form
  /// are mapped here, once, so delivery and storage never re-parse them.
  NormalizedBridgeEvent normalize({required BridgeSseEvent event}) => switch (event) {
    BridgeSseTerminalHandoff(:final event) => NormalizedTerminalHandoff(payload: _normalizePayload(event: event)),
    _ => _normalizePayload(event: event),
  };

  NormalizedBridgePayload _normalizePayload({required BridgeSseEvent event}) => switch (event) {
    BridgeSseTerminalHandoff() => throw StateError("terminal handoff must not wrap another terminal handoff"),
    BridgeSseSessionStatus(:final sessionID, :final status) => NormalizedStatusEvent(
      sessionId: sessionID,
      status: status.toSharedSessionStatus(),
    ),
    BridgeSseMessageUpdated(:final info) => NormalizedMessageEvent(
      message: info.toSharedMessage(sessionId: info.sessionID),
    ),
    _ => NormalizedOtherEvent(event: event),
  };

  Session? sessionInfo({required BridgeSseEvent event}) {
    return switch (event) {
      BridgeSseTerminalHandoff(:final event) => sessionInfo(event: event),
      BridgeSseSessionCreated(:final info) ||
      BridgeSseSessionUpdated(:final info) ||
      BridgeSseSessionDeleted(:final info) => Session.fromJson(info),
      _ => null,
    };
  }

  Set<String> backendSessionIds({required BridgeSseEvent event}) {
    final session = sessionInfo(event: event);
    if (session != null) {
      return {session.id, ?session.parentID};
    }
    return switch (event) {
      BridgeSseTerminalHandoff(:final event) => backendSessionIds(event: event),
      BridgeSseSessionDiff(:final sessionID) ||
      BridgeSseSessionCompacted(:final sessionID) ||
      BridgeSseSessionPromptDefaultsChanged(:final sessionID) ||
      BridgeSseSessionStatus(:final sessionID) ||
      BridgeSseSessionIdle(:final sessionID) ||
      BridgeSseCommandExecuted(:final sessionID) ||
      BridgeSseMessageRemoved(:final sessionID) ||
      BridgeSseMessagePartDelta(:final sessionID) ||
      BridgeSseMessagePartRemoved(:final sessionID) ||
      BridgeSseQueuedPromptsUpdated(:final sessionID) ||
      BridgeSseTodoUpdated(:final sessionID) => {sessionID},
      BridgeSseSessionError(:final sessionID) || BridgeSseTuiToastShow(:final sessionID) => {?sessionID},
      BridgeSseMessageUpdated(:final info) => {info.sessionID},
      BridgeSseMessagePartUpdated(:final part) => {part.sessionID},
      BridgeSsePermissionAsked(:final sessionID, :final displaySessionId) ||
      BridgeSsePermissionReplied(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionAsked(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionReplied(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionRejected(:final sessionID, :final displaySessionId) => {
        sessionID,
        ?displaySessionId,
      },
      BridgeSseServerConnected() ||
      BridgeSseServerHeartbeat() ||
      BridgeSseServerInstanceDisposed() ||
      BridgeSseGlobalDisposed() ||
      BridgeSseCommandCatalogUpdated() ||
      BridgeSseSessionOptionsChanged() ||
      BridgeSsePtyCreated() ||
      BridgeSsePtyUpdated() ||
      BridgeSsePtyExited() ||
      BridgeSsePtyDeleted() ||
      BridgeSsePermissionUpdated() ||
      BridgeSseProjectUpdated() ||
      BridgeSseVcsBranchUpdated() ||
      BridgeSseFileEdited() ||
      BridgeSseFileWatcherUpdated() ||
      BridgeSseLspUpdated() ||
      BridgeSseLspClientDiagnostics() ||
      BridgeSseMcpToolsChanged() ||
      BridgeSseMcpBrowserOpenFailed() ||
      BridgeSseInstallationUpdated() ||
      BridgeSseInstallationUpdateAvailable() ||
      BridgeSseWorkspaceReady() ||
      BridgeSseWorkspaceFailed() ||
      BridgeSseWorktreeReady() ||
      BridgeSseWorktreeFailed() => const <String>{},
      BridgeSseSessionCreated() ||
      BridgeSseSessionUpdated() ||
      BridgeSseSessionDeleted() => throw StateError("session event parsing unexpectedly returned no session"),
    };
  }

  /// Backend session ids an event only refers to.
  ///
  /// Unlike [backendSessionIds] these never gate delivery: the event is
  /// translated whether or not they resolve, and an unresolved one becomes
  /// null. Keeping them out of the required set is what lets a plugin name a
  /// child session before the bridge has bound it.
  Set<String> optionalBackendSessionIds({required BridgeSseEvent event}) => switch (event) {
    BridgeSseTerminalHandoff(:final event) => optionalBackendSessionIds(event: event),
    BridgeSseMessagePartUpdated(part: PluginMessagePartSubtask(:final childSessionID)) => {?childSessionID},
    _ => const <String>{},
  };

  BridgeSseEvent? map({
    required BridgeSseEvent event,
    required Map<String, String> sessionIdsByBackendId,
  }) {
    String? mapped(String backendId) => sessionIdsByBackendId[backendId];

    String? mappedOptional(String? backendId) {
      if (backendId == null) return null;
      return mapped(backendId);
    }

    Session? mappedSession(Map<String, dynamic> info) {
      final session = Session.fromJson(info);
      final sessionId = mapped(session.id);
      if (sessionId == null) return null;
      final parentId = mappedOptional(session.parentID);
      if (session.parentID != null && parentId == null) return null;
      return session.copyWith(id: sessionId, parentID: parentId);
    }

    return switch (event) {
      BridgeSseTerminalHandoff(:final event) => switch (map(
        event: event,
        sessionIdsByBackendId: sessionIdsByBackendId,
      )) {
        final mappedEvent? => BridgeSseTerminalHandoff(event: mappedEvent),
        null => null,
      },
      BridgeSseSessionCreated(:final info) => switch (mappedSession(info)) {
        final session? => BridgeSseSessionCreated(info: session.toJson()),
        null => null,
      },
      BridgeSseSessionUpdated(:final info, :final titleChanged) => switch (mappedSession(info)) {
        final session? => BridgeSseSessionUpdated(info: session.toJson(), titleChanged: titleChanged),
        null => null,
      },
      BridgeSseSessionDeleted(:final info) => switch (mappedSession(info)) {
        final session? => BridgeSseSessionDeleted(info: session.toJson()),
        null => null,
      },
      BridgeSseSessionDiff(:final sessionID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseSessionDiff(sessionID: sessionId),
        null => null,
      },
      BridgeSseSessionError(:final sessionID) => switch (sessionID) {
        final backendId? => switch (mapped(backendId)) {
          final sessionId? => BridgeSseSessionError(sessionID: sessionId),
          null => null,
        },
        null => const BridgeSseSessionError(sessionID: null),
      },
      BridgeSseSessionCompacted(:final sessionID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseSessionCompacted(sessionID: sessionId),
        null => null,
      },
      BridgeSseSessionPromptDefaultsChanged(
        :final sessionID,
        :final agent,
        :final model,
      ) =>
        switch (mapped(sessionID)) {
          final sessionId? => BridgeSseSessionPromptDefaultsChanged(
            sessionID: sessionId,
            agent: agent,
            model: model,
          ),
          null => null,
        },
      BridgeSseSessionStatus(:final sessionID, :final status) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseSessionStatus(sessionID: sessionId, status: status),
        null => null,
      },
      BridgeSseSessionIdle(:final sessionID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseSessionIdle(sessionID: sessionId),
        null => null,
      },
      BridgeSseCommandExecuted(:final name, :final sessionID, :final arguments, :final messageID) => switch (mapped(
        sessionID,
      )) {
        final sessionId? => BridgeSseCommandExecuted(
          name: name,
          sessionID: sessionId,
          arguments: arguments,
          messageID: messageID,
        ),
        null => null,
      },
      BridgeSseMessageUpdated(:final info) => switch (mapped(info.sessionID)) {
        final sessionId? => BridgeSseMessageUpdated(info: info.copyWith(sessionID: sessionId)),
        null => null,
      },
      BridgeSseMessageRemoved(:final sessionID, :final messageID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseMessageRemoved(sessionID: sessionId, messageID: messageID),
        null => null,
      },
      BridgeSseQueuedPromptsUpdated(:final sessionID, :final prompts) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseQueuedPromptsUpdated(sessionID: sessionId, prompts: prompts),
        null => null,
      },
      BridgeSseMessagePartUpdated(:final part) => switch (mapped(part.sessionID)) {
        final sessionId? => BridgeSseMessagePartUpdated(
          part: switch (part) {
            // Only a subtask names a child, and that reference is optional:
            // one the bridge has not bound yet becomes null rather than
            // withholding the part.
            final PluginMessagePartSubtask subtask => subtask.copyWith(
              sessionID: sessionId,
              childSessionID: mappedOptional(subtask.childSessionID),
            ),
            _ => part.copyWith(sessionID: sessionId),
          },
        ),
        null => null,
      },
      BridgeSseMessagePartDelta(:final sessionID, :final messageID, :final partID, :final field, :final delta) =>
        switch (mapped(sessionID)) {
          final sessionId? => BridgeSseMessagePartDelta(
            sessionID: sessionId,
            messageID: messageID,
            partID: partID,
            field: field,
            delta: delta,
          ),
          null => null,
        },
      BridgeSseMessagePartRemoved(:final sessionID, :final messageID, :final partID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseMessagePartRemoved(
          sessionID: sessionId,
          messageID: messageID,
          partID: partID,
        ),
        null => null,
      },
      BridgeSsePermissionAsked(
        :final requestID,
        :final sessionID,
        :final displaySessionId,
        :final tool,
        :final description,
        :final allowAlways,
      ) =>
        switch ((mapped(sessionID), mappedOptional(displaySessionId))) {
          (final sessionId?, final displayId) when displaySessionId == null || displayId != null =>
            BridgeSsePermissionAsked(
              requestID: requestID,
              sessionID: sessionId,
              displaySessionId: displayId,
              tool: tool,
              description: description,
              allowAlways: allowAlways,
            ),
          _ => null,
        },
      BridgeSsePermissionReplied(:final requestID, :final sessionID, :final displaySessionId, :final reply) => switch ((
        mapped(sessionID),
        mappedOptional(displaySessionId),
      )) {
        (final sessionId?, final displayId) when displaySessionId == null || displayId != null =>
          BridgeSsePermissionReplied(
            requestID: requestID,
            sessionID: sessionId,
            displaySessionId: displayId,
            reply: reply,
          ),
        _ => null,
      },
      BridgeSseQuestionAsked(:final id, :final sessionID, :final displaySessionId, :final questions) => switch ((
        mapped(sessionID),
        mappedOptional(displaySessionId),
      )) {
        (final sessionId?, final displayId) when displaySessionId == null || displayId != null =>
          BridgeSseQuestionAsked(
            id: id,
            sessionID: sessionId,
            displaySessionId: displayId,
            questions: questions,
          ),
        _ => null,
      },
      BridgeSseQuestionReplied(:final requestID, :final sessionID, :final displaySessionId) => switch ((
        mapped(sessionID),
        mappedOptional(displaySessionId),
      )) {
        (final sessionId?, final displayId) when displaySessionId == null || displayId != null =>
          BridgeSseQuestionReplied(
            requestID: requestID,
            sessionID: sessionId,
            displaySessionId: displayId,
          ),
        _ => null,
      },
      BridgeSseQuestionRejected(:final requestID, :final sessionID, :final displaySessionId) => switch ((
        mapped(sessionID),
        mappedOptional(displaySessionId),
      )) {
        (final sessionId?, final displayId) when displaySessionId == null || displayId != null =>
          BridgeSseQuestionRejected(
            requestID: requestID,
            sessionID: sessionId,
            displaySessionId: displayId,
          ),
        _ => null,
      },
      BridgeSseTodoUpdated(:final sessionID) => switch (mapped(sessionID)) {
        final sessionId? => BridgeSseTodoUpdated(sessionID: sessionId),
        null => null,
      },
      BridgeSseTuiToastShow(:final sessionID, :final title, :final message, :final variant) => switch (sessionID) {
        final backendId? => switch (mapped(backendId)) {
          final sessionId? => BridgeSseTuiToastShow(
            sessionID: sessionId,
            title: title,
            message: message,
            variant: variant,
          ),
          null => null,
        },
        null => event,
      },
      BridgeSseServerConnected() ||
      BridgeSseServerHeartbeat() ||
      BridgeSseServerInstanceDisposed() ||
      BridgeSseGlobalDisposed() ||
      BridgeSseCommandCatalogUpdated() ||
      BridgeSseSessionOptionsChanged() ||
      BridgeSsePtyCreated() ||
      BridgeSsePtyUpdated() ||
      BridgeSsePtyExited() ||
      BridgeSsePtyDeleted() ||
      BridgeSsePermissionUpdated() ||
      BridgeSseProjectUpdated() ||
      BridgeSseVcsBranchUpdated() ||
      BridgeSseFileEdited() ||
      BridgeSseFileWatcherUpdated() ||
      BridgeSseLspUpdated() ||
      BridgeSseLspClientDiagnostics() ||
      BridgeSseMcpToolsChanged() ||
      BridgeSseMcpBrowserOpenFailed() ||
      BridgeSseInstallationUpdated() ||
      BridgeSseInstallationUpdateAvailable() ||
      BridgeSseWorkspaceReady() ||
      BridgeSseWorkspaceFailed() ||
      BridgeSseWorktreeReady() ||
      BridgeSseWorktreeFailed() => event,
    };
  }
}
