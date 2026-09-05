import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/plugin_to_shared_mapping.dart";

/// Maps [BridgeSseEvent]s from the plugin to [SesoriSseEvent]s for relay delivery.
///
/// Handles all event type conversions and builds the projects summary event
/// from already-fetched summary data (the orchestrator owns fetching it).
class BridgeEventMapper({
  required final FailureReporter _failureReporter,
}) {
  /// Maps a [BridgeSseEvent] to a [SesoriSseEvent], or null if unmappable.
  SesoriSseEvent? map({required BridgeSseEvent event, required String pluginId}) {
    try {
      return switch (event) {
        BridgeSseTerminalHandoff() => throw StateError("terminal handoff must be unwrapped by Orchestrator"),
        BridgeSseServerConnected() => null,
        BridgeSseServerHeartbeat() => null,
        BridgeSseServerInstanceDisposed() => null,
        BridgeSseGlobalDisposed() => null,
        // Refreshes the options cache through SessionOptionsChangedRefreshListener;
        // clients hear about it as `session.options_updated` once that commits.
        BridgeSseCommandCatalogUpdated() => null,
        BridgeSseSessionCreated(:final info) => _tryParseSseEvent({"type": "session.created", "info": info}),
        BridgeSseSessionUpdated(:final info) => _tryParseSseEvent({"type": "session.updated", "info": info}),
        BridgeSseSessionOptionsChanged() => null,
        BridgeSseSessionPromptDefaultsChanged(
          :final sessionID,
          :final agent,
          model: final pluginModel,
        ) =>
          SesoriSseEvent.sessionPromptDefaultsChanged(
            sessionID: sessionID,
            promptDefaults: SessionPromptDefaults(
              agent: agent,
              model: switch (pluginModel) {
                PluginAgentModel(:final providerID, :final modelID, :final variant) => AgentModel(
                  providerID: providerID,
                  modelID: modelID,
                  variant: variant,
                ),
                null => null,
              },
            ),
          ),
        BridgeSseSessionDeleted(:final info) => _tryParseSseEvent({"type": "session.deleted", "info": info}),
        BridgeSseSessionDiff(:final sessionID) => SesoriSseEvent.sessionDiff(sessionID: sessionID),
        BridgeSseSessionError(:final sessionID) => SesoriSseEvent.sessionError(sessionID: sessionID),
        BridgeSseSessionCompacted(:final sessionID) => SesoriSseEvent.sessionCompacted(sessionID: sessionID),
        BridgeSseSessionStatus() => throw StateError("session status is normalized before it reaches the mapper"),
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
        BridgeSseMessageUpdated() => throw StateError("message updates are normalized before they reach the mapper"),
        BridgeSseMessageRemoved(:final sessionID, :final messageID) => SesoriSseEvent.messageRemoved(
          sessionID: sessionID,
          messageID: messageID,
        ),
        // Finalized parts are stored before delivery, so the Orchestrator maps
        // them through [mapMessagePart] and [buildMessagePartEvent].
        BridgeSseMessagePartUpdated() => null,
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
          :final displaySessionId,
          :final tool,
          :final description,
          :final allowAlways,
        ) =>
          SesoriSseEvent.permissionAsked(
            requestID: requestID,
            sessionID: sessionID,
            displaySessionId: displaySessionId,
            tool: tool,
            description: description,
            allowAlways: allowAlways,
          ),
        BridgeSsePermissionReplied(:final requestID, :final sessionID, :final displaySessionId, :final reply) =>
          SesoriSseEvent.permissionReplied(
            requestID: requestID,
            sessionID: sessionID,
            displaySessionId: displaySessionId,
            reply: reply,
          ),
        BridgeSsePermissionUpdated() => const SesoriSseEvent.permissionUpdated(),
        BridgeSseQuestionAsked(:final id, :final sessionID, :final displaySessionId, :final questions) =>
          SesoriSseEvent.questionAsked(
            id: id,
            sessionID: sessionID,
            displaySessionId: displaySessionId,
            questions: questions.map((q) => q.toSharedQuestionInfo()).toList(),
          ),
        BridgeSseQuestionReplied(:final requestID, :final sessionID, :final displaySessionId) =>
          SesoriSseEvent.questionReplied(
            requestID: requestID,
            sessionID: sessionID,
            displaySessionId: displaySessionId,
          ),
        BridgeSseQuestionRejected(:final requestID, :final sessionID, :final displaySessionId) =>
          SesoriSseEvent.questionRejected(
            requestID: requestID,
            sessionID: sessionID,
            displaySessionId: displaySessionId,
          ),
        BridgeSseTodoUpdated(:final sessionID) => SesoriSseEvent.todoUpdated(sessionID: sessionID),
        BridgeSseQueuedPromptsUpdated(:final sessionID, :final prompts) => SesoriSseEvent.sessionQueuedPrompts(
          sessionID: sessionID,
          prompts: prompts.toSharedQueuedPrompts(),
        ),
        // BridgeSseProjectUpdated triggers a full projects-summary rebuild, but
        // the summary needs repository data (the bridge's session→project
        // attribution) — the orchestrator fetches it and builds the event via
        // [buildProjectsSummaryEvent] before reaching this mapper.
        BridgeSseProjectUpdated() => null,
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
        BridgeSseTuiToastShow(:final sessionID, :final title, :final message, :final variant) =>
          SesoriSseEvent.tuiToastShow(
            sessionID: sessionID,
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
            .catchError((Object reportError, StackTrace reportStackTrace) {
              Log.w("[sse-mapper] failed to report mapping failure", reportError, reportStackTrace);
            }),
      );
      return null;
    }
  }

  /// Maps one finalized plugin part into its shared form.
  ///
  /// Exposed because the Orchestrator both stores and delivers that part, and
  /// the stored transcript must not disagree with the event a phone renders.
  MessagePart mapMessagePart({required PluginMessagePart part}) {
    final truncated = _truncateToolOutput(part);
    return truncated.toShared(sessionId: truncated.sessionID);
  }

  bool isMessagePartVisible({required PluginMessagePart part}) => part.type.isVisible;

  SesoriSseEvent buildMessagePartEvent({required MessagePart part}) {
    return SesoriSseEvent.messagePartUpdated(part: part);
  }

  /// Builds the public status event from the already-normalized shared status.
  SesoriSseEvent buildSessionStatusEvent({required String sessionId, required SessionStatus status}) {
    return SesoriSseEvent.sessionStatus(sessionID: sessionId, status: status);
  }

  /// Builds the public message event from the already-normalized shared message.
  SesoriSseEvent buildMessageUpdatedEvent({required Message message}) {
    return SesoriSseEvent.messageUpdated(info: message);
  }

  /// Builds a projects summary event from already-remapped summary data
  /// (see `SessionRepository.getProjectActivitySummaries`).
  SesoriSseEvent buildProjectsSummaryEvent({required List<ProjectActivitySummary> projects}) {
    return SesoriSseEvent.projectsSummary(projects: projects);
  }

  /// Attempts to parse a session SSE event from its JSON payload.
  ///
  /// The payload carries the session's title and directory, so only the event
  /// type is logged alongside the error.
  SesoriSseEvent? _tryParseSseEvent(Map<String, dynamic> payload) {
    try {
      return SesoriSseEvent.fromJson(payload);
    } catch (e, st) {
      Log.w("failed to parse SSE event ${payload["type"]}", e, st);
      return null;
    }
  }

  /// Returns [part] with tool output truncated to [maxToolOutputLength]
  /// runes, or the original part if no truncation is needed.
  /// Uses rune-based truncation to avoid splitting UTF-16 surrogate pairs.
  PluginMessagePart _truncateToolOutput(PluginMessagePart part) {
    if (part case PluginMessagePartTool(:final state)) {
      final output = state.output;
      if (output != null && output.length > maxToolOutputLength) {
        return part.copyWith(
          state: state.copyWith(output: String.fromCharCodes(output.runes.take(maxToolOutputLength))),
        );
      }
    }
    return part;
  }
}
