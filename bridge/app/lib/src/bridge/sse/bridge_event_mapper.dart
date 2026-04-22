import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../plugin_to_shared_mapping.dart";

/// Maps [BridgeSseEvent]s from the plugin to [SesoriSseEvent]s for relay delivery.
///
/// Handles all event type conversions and builds the projects summary event.
class BridgeEventMapper {
  final BridgePlugin _plugin;
  final FailureReporter _failureReporter;

  BridgeEventMapper({
    required BridgePlugin plugin,
    required FailureReporter failureReporter,
  }) : _plugin = plugin,
       _failureReporter = failureReporter;

  /// Maps a [BridgeSseEvent] to a [SesoriSseEvent], or null if unmappable.
  SesoriSseEvent? map(BridgeSseEvent event) {
    try {
      return switch (event) {
        BridgeSseServerConnected() => const SesoriSseEvent.serverConnected(),
        BridgeSseServerHeartbeat() => null,
        BridgeSseServerInstanceDisposed(:final directory) => SesoriSseEvent.serverInstanceDisposed(
          directory: directory,
        ),
        BridgeSseGlobalDisposed() => const SesoriSseEvent.globalDisposed(),
        BridgeSseSessionCreated(:final info) => _tryParseSseEvent({"type": "session.created", "info": info}),
        BridgeSseSessionUpdated(:final info) => _tryParseSseEvent({"type": "session.updated", "info": info}),
        BridgeSseSessionDeleted(:final info) => _tryParseSseEvent({"type": "session.deleted", "info": info}),
        BridgeSseSessionDiff(:final sessionID) => SesoriSseEvent.sessionDiff(sessionID: sessionID),
        BridgeSseSessionError(:final sessionID, :final error) => SesoriSseEvent.sessionError(
          sessionID: sessionID,
          error: error != null
            ? SessionError(name: error.name, message: error.message)
            : null,
        ),
        BridgeSseSessionCompacted(:final sessionID) => SesoriSseEvent.sessionCompacted(sessionID: sessionID),
        BridgeSseSessionStatus(:final sessionID, :final status) => _tryParseSseEvent({
          "type": "session.status",
          "sessionID": sessionID,
          "status": status,
        }),
        BridgeSseSessionIdle(:final sessionID) => SesoriSseEvent.sessionStatus(
          sessionID: sessionID,
          status: const SessionStatus.idle(),
        ),
        BridgeSseCommandExecuted(:final name, :final sessionID, :final arguments, :final messageID) =>
          SesoriSseEvent.commandExecuted(
            name: name,
            sessionID: sessionID,
            arguments: arguments,
            messageID: messageID,
          ),
        BridgeSseMessageUpdated(:final info) => _tryParseSseEvent({"type": "message.updated", "info": info}),
        BridgeSseMessageRemoved(:final sessionID, :final messageID) => SesoriSseEvent.messageRemoved(
          sessionID: sessionID,
          messageID: messageID,
        ),
        BridgeSseMessagePartUpdated(:final part) => () {
          if (!part.type.isVisible) return null;
          final truncated = _truncateToolOutput(part);
          return SesoriSseEvent.messagePartUpdated(part: truncated.toShared());
        }(),
        BridgeSseMessagePartDelta(
          :final sessionID,
          :final messageID,
          :final partID,
          :final field,
          :final delta,
        ) =>
          SesoriSseEvent.messagePartDelta(
            sessionID: sessionID,
            messageID: messageID,
            partID: partID,
            field: field,
            delta: delta,
          ),
        BridgeSseMessagePartRemoved(
          :final sessionID,
          :final messageID,
          :final partID,
        ) =>
          SesoriSseEvent.messagePartRemoved(
            sessionID: sessionID,
            messageID: messageID,
            partID: partID,
          ),
        BridgeSsePtyCreated() => const SesoriSseEvent.ptyCreated(),
        BridgeSsePtyUpdated() => const SesoriSseEvent.ptyUpdated(),
        BridgeSsePtyExited(:final id, :final exitCode) => SesoriSseEvent.ptyExited(id: id, exitCode: exitCode),
        BridgeSsePtyDeleted(:final id) => SesoriSseEvent.ptyDeleted(id: id),
        BridgeSsePermissionAsked(
          :final requestID,
          :final sessionID,
          :final tool,
          :final description,
        ) =>
          SesoriSseEvent.permissionAsked(
            requestID: requestID,
            sessionID: sessionID,
            tool: tool,
            description: description,
          ),
        BridgeSsePermissionReplied(:final requestID, :final sessionID, :final reply) =>
          SesoriSseEvent.permissionReplied(
            requestID: requestID,
            sessionID: sessionID,
            reply: reply,
          ),
        BridgeSsePermissionUpdated() => const SesoriSseEvent.permissionUpdated(),
        BridgeSseQuestionAsked(:final id, :final sessionID, :final questions) => _tryParseSseEvent({
          "type": "question.asked",
          "id": id,
          "sessionID": sessionID,
          "questions": questions,
        }),
        BridgeSseQuestionReplied(:final requestID, :final sessionID) => SesoriSseEvent.questionReplied(
          requestID: requestID,
          sessionID: sessionID,
        ),
        BridgeSseQuestionRejected(:final requestID, :final sessionID) => SesoriSseEvent.questionRejected(
          requestID: requestID,
          sessionID: sessionID,
        ),
        BridgeSseTodoUpdated(:final sessionID) => SesoriSseEvent.todoUpdated(sessionID: sessionID),
        // BridgeSseProjectUpdated is emitted on both activity changes and project
        // metadata changes. We always send the full projectsSummary so the mobile
        // client receives updated activity data in real time.
        BridgeSseProjectUpdated() => buildProjectsSummaryEvent(),
        BridgeSseVcsBranchUpdated() => const SesoriSseEvent.vcsBranchUpdated(),
        BridgeSseFileEdited(:final file) => SesoriSseEvent.fileEdited(file: file),
        BridgeSseFileWatcherUpdated(:final file, :final event) => SesoriSseEvent.fileWatcherUpdated(
          file: file,
          event: event,
        ),
        BridgeSseLspUpdated() => const SesoriSseEvent.lspUpdated(),
        BridgeSseLspClientDiagnostics(:final serverID, :final path) => SesoriSseEvent.lspClientDiagnostics(
          serverID: serverID,
          path: path,
        ),
        BridgeSseMcpToolsChanged() => const SesoriSseEvent.mcpToolsChanged(),
        BridgeSseMcpBrowserOpenFailed() => const SesoriSseEvent.mcpBrowserOpenFailed(),
        BridgeSseInstallationUpdated(:final version) => SesoriSseEvent.installationUpdated(version: version),
        BridgeSseInstallationUpdateAvailable(:final version) => SesoriSseEvent.installationUpdateAvailable(
          version: version,
        ),
        BridgeSseWorkspaceReady(:final name) => SesoriSseEvent.workspaceReady(name: name),
        BridgeSseWorkspaceFailed(:final message) => SesoriSseEvent.workspaceFailed(message: message),
        BridgeSseTuiToastShow(:final title, :final message, :final variant) => SesoriSseEvent.tuiToastShow(
          title: title,
          message: message,
          variant: variant,
        ),
        BridgeSseWorktreeReady() => const SesoriSseEvent.worktreeReady(),
        BridgeSseWorktreeFailed() => const SesoriSseEvent.worktreeFailed(),
      };
    } catch (e, st) {
      Log.e("[sse-mapper] error mapping event ${event.runtimeType}: $e\n$st");
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_event_mapping:${event.runtimeType}",
              fatal: false,
              reason: "Failed to map SSE event",
              information: [event.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
      return null;
    }
  }

  /// Builds a projects summary event from the current active sessions.
  SesoriSseEvent? buildProjectsSummaryEvent() {
    try {
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
                        awaitingInput: a.awaitingInput,
                        childSessionIds: a.childSessionIds,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      );
    } catch (e, st) {
      Log.e("[sse-mapper] error building projects summary: $e\n$st");
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_projects_summary",
              fatal: false,
              reason: "Failed to build projects summary event",
              information: const [],
            )
            .catchError((_) {}),
      );
      return null;
    }
  }

  /// Attempts to parse an SSE event from a JSON payload.
  SesoriSseEvent? _tryParseSseEvent(Map<String, dynamic> payload) {
    try {
      return SesoriSseEvent.fromJson(payload);
    } catch (e) {
      Log.w("failed to parse SSE event from payload: $payload, error: $e");
      return null;
    }
  }

  /// Returns [part] with tool output truncated to [maxToolOutputLength]
  /// runes, or the original part if no truncation is needed.
  /// Uses rune-based truncation to avoid splitting UTF-16 surrogate pairs.
  PluginMessagePart _truncateToolOutput(PluginMessagePart part) {
    final output = part.state?.output;
    if (output == null || output.length <= maxToolOutputLength) return part;
    return part.copyWith(
      state: part.state!.copyWith(
        output: String.fromCharCodes(output.runes.take(maxToolOutputLength)),
      ),
    );
  }
}
