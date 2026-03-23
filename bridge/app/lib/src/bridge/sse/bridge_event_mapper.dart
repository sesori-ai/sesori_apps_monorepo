import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps [BridgeSseEvent]s from the plugin to [SesoriSseEvent]s for relay delivery.
///
/// Handles all event type conversions and builds the projects summary event.
class BridgeEventMapper {
  final BridgePlugin _plugin;

  BridgeEventMapper(this._plugin);

  /// Maps a [BridgeSseEvent] to a [SesoriSseEvent], or null if unmappable.
  SesoriSseEvent? map(BridgeSseEvent event) {
    switch (event) {
      case BridgeSseServerConnected():
        return const SesoriSseEvent.serverConnected();
      case BridgeSseServerHeartbeat():
        return const SesoriSseEvent.serverHeartbeat();
      case BridgeSseServerInstanceDisposed(:final directory):
        return SesoriSseEvent.serverInstanceDisposed(directory: directory);
      case BridgeSseGlobalDisposed():
        return const SesoriSseEvent.globalDisposed();
      case BridgeSseSessionCreated(:final info):
        return _tryParseSseEvent({"type": "session.created", "info": info});
      case BridgeSseSessionUpdated(:final info):
        return _tryParseSseEvent({"type": "session.updated", "info": info});
      case BridgeSseSessionDeleted(:final info):
        return _tryParseSseEvent({"type": "session.deleted", "info": info});
      case BridgeSseSessionDiff(:final sessionID, :final diff):
        return _tryParseSseEvent({
          "type": "session.diff",
          "sessionID": sessionID,
          "diff": diff,
        });
      case BridgeSseSessionError(:final sessionID):
        return SesoriSseEvent.sessionError(sessionID: sessionID);
      case BridgeSseSessionCompacted(:final sessionID):
        return SesoriSseEvent.sessionCompacted(sessionID: sessionID);
      case BridgeSseSessionStatus(:final sessionID, :final status):
        return _tryParseSseEvent({
          "type": "session.status",
          "sessionID": sessionID,
          "status": status,
        });
      case BridgeSseSessionIdle(:final sessionID):
        return SesoriSseEvent.sessionStatus(
          sessionID: sessionID,
          status: const SessionStatus.idle(),
        );
      case BridgeSseMessageUpdated(:final info):
        return _tryParseSseEvent({"type": "message.updated", "info": info});
      case BridgeSseMessageRemoved(:final sessionID, :final messageID):
        return SesoriSseEvent.messageRemoved(
          sessionID: sessionID,
          messageID: messageID,
        );
      case BridgeSseMessagePartUpdated(:final part):
        return _tryParseSseEvent({"type": "message.part.updated", "part": part});
      case BridgeSseMessagePartDelta(
        :final sessionID,
        :final messageID,
        :final partID,
        :final field,
        :final delta,
      ):
        return SesoriSseEvent.messagePartDelta(
          sessionID: sessionID,
          messageID: messageID,
          partID: partID,
          field: field,
          delta: delta,
        );
      case BridgeSseMessagePartRemoved(
        :final sessionID,
        :final messageID,
        :final partID,
      ):
        return SesoriSseEvent.messagePartRemoved(
          sessionID: sessionID,
          messageID: messageID,
          partID: partID,
        );
      case BridgeSsePtyCreated():
        return const SesoriSseEvent.ptyCreated();
      case BridgeSsePtyUpdated():
        return const SesoriSseEvent.ptyUpdated();
      case BridgeSsePtyExited(:final id, :final exitCode):
        return SesoriSseEvent.ptyExited(id: id, exitCode: exitCode);
      case BridgeSsePtyDeleted(:final id):
        return SesoriSseEvent.ptyDeleted(id: id);
      case BridgeSsePermissionAsked(
        :final requestID,
        :final sessionID,
        :final tool,
        :final description,
      ):
        return SesoriSseEvent.permissionAsked(
          requestID: requestID,
          sessionID: sessionID,
          tool: tool,
          description: description,
        );
      case BridgeSsePermissionReplied(:final requestID, :final reply):
        return SesoriSseEvent.permissionReplied(
          requestID: requestID,
          reply: reply,
        );
      case BridgeSsePermissionUpdated():
        return const SesoriSseEvent.permissionUpdated();
      case BridgeSseQuestionAsked(:final id, :final sessionID, :final questions):
        return _tryParseSseEvent({
          "type": "question.asked",
          "id": id,
          "sessionID": sessionID,
          "questions": questions,
        });
      case BridgeSseQuestionReplied(:final requestID, :final sessionID):
        return SesoriSseEvent.questionReplied(
          requestID: requestID,
          sessionID: sessionID,
        );
      case BridgeSseQuestionRejected(:final requestID, :final sessionID):
        return SesoriSseEvent.questionRejected(
          requestID: requestID,
          sessionID: sessionID,
        );
      case BridgeSseTodoUpdated(:final sessionID):
        return SesoriSseEvent.todoUpdated(sessionID: sessionID);
      // BridgeSseProjectUpdated is emitted on both activity changes and project
      // metadata changes. We always send the full projectsSummary so the mobile
      // client receives updated activity data in real time.
      case BridgeSseProjectUpdated():
        return buildProjectsSummaryEvent();
      case BridgeSseVcsBranchUpdated():
        return const SesoriSseEvent.vcsBranchUpdated();
      case BridgeSseFileEdited(:final file):
        return SesoriSseEvent.fileEdited(file: file);
      case BridgeSseFileWatcherUpdated(:final file, :final event):
        return SesoriSseEvent.fileWatcherUpdated(file: file, event: event);
      case BridgeSseLspUpdated():
        return const SesoriSseEvent.lspUpdated();
      case BridgeSseLspClientDiagnostics(:final serverID, :final path):
        return SesoriSseEvent.lspClientDiagnostics(serverID: serverID, path: path);
      case BridgeSseMcpToolsChanged():
        return const SesoriSseEvent.mcpToolsChanged();
      case BridgeSseMcpBrowserOpenFailed():
        return const SesoriSseEvent.mcpBrowserOpenFailed();
      case BridgeSseInstallationUpdated(:final version):
        return SesoriSseEvent.installationUpdated(version: version);
      case BridgeSseInstallationUpdateAvailable(:final version):
        return SesoriSseEvent.installationUpdateAvailable(version: version);
      case BridgeSseWorkspaceReady(:final name):
        return SesoriSseEvent.workspaceReady(name: name);
      case BridgeSseWorkspaceFailed(:final message):
        return SesoriSseEvent.workspaceFailed(message: message);
      case BridgeSseTuiToastShow(:final title, :final message, :final variant):
        return SesoriSseEvent.tuiToastShow(
          title: title,
          message: message,
          variant: variant,
        );
      case BridgeSseWorktreeReady():
        return const SesoriSseEvent.worktreeReady();
      case BridgeSseWorktreeFailed():
        return const SesoriSseEvent.worktreeFailed();
    }
  }

  /// Builds a projects summary event from the current active sessions.
  SesoriSseEvent buildProjectsSummaryEvent() {
    final summary = _plugin.getActiveSessionsSummary();
    return SesoriSseEvent.projectsSummary(
      projects: summary
          .map(
            (e) => ProjectActivitySummary(
              id: e.id,
              activeSessions: e.activeSessions
                  .map(
                    (a) => ActiveSession(
                      id: a.id,
                      mainAgentRunning: a.mainAgentRunning,
                      childSessionIds: a.childSessionIds,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  /// Attempts to parse an SSE event from a JSON payload.
  SesoriSseEvent? _tryParseSseEvent(Map<String, dynamic> payload) {
    try {
      return SesoriSseEvent.fromJson(payload);
    } catch (_) {
      return null;
    }
  }
}
