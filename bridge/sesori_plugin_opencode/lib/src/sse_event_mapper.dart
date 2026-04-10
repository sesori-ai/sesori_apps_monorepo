import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/message_part.dart";
import "models/sse_event_data.dart";
import "session_plugin_mapper.dart";

/// Maps OpenCode SSE events and message parts to plugin interface types.
///
/// Extracted from [OpenCodePlugin] to isolate the mapping concern.
/// This class is stateless — all methods are pure transformations.
class SseEventMapper {
  final SessionPluginMapper _sessionMapper;

  SseEventMapper({required SessionPluginMapper sessionMapper}) : _sessionMapper = sessionMapper;

  /// Maps an [SseEventData] to a [BridgeSseEvent], or null if the event
  /// type has no plugin representation.
  BridgeSseEvent? map(SseEventData event) {
    return switch (event) {
      SseServerConnected() => const BridgeSseServerConnected(),
      SseServerHeartbeat() => const BridgeSseServerHeartbeat(),
      SseServerInstanceDisposed(:final directory) => BridgeSseServerInstanceDisposed(directory: directory),
      SseGlobalDisposed() => const BridgeSseGlobalDisposed(),
      SseSessionCreated(:final info) => BridgeSseSessionCreated(
        info: _sessionMapper.toBridgeSessionInfo(session: info, fallbackProjectID: info.projectID),
      ),
      SseSessionUpdated(:final info) => BridgeSseSessionUpdated(
        info: _sessionMapper.toBridgeSessionInfo(session: info, fallbackProjectID: info.projectID),
      ),
      SseSessionDeleted(:final info) => BridgeSseSessionDeleted(
        info: _sessionMapper.toBridgeSessionInfo(session: info, fallbackProjectID: info.projectID),
      ),
      SseSessionDiff(:final sessionID) => BridgeSseSessionDiff(
        sessionID: sessionID,
      ),
      SseSessionError(:final sessionID) => BridgeSseSessionError(sessionID: sessionID),
      SseSessionCompacted(:final sessionID) => BridgeSseSessionCompacted(sessionID: sessionID),
      SseSessionStatus(:final sessionID, :final status) => BridgeSseSessionStatus(
        sessionID: sessionID,
        status: status.toJson(),
      ),
      // ignore: deprecated_member_use, forwards legacy idle event for backward compatibility
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseMessageUpdated(:final info) => BridgeSseMessageUpdated(info: info.toJson()),
      SseMessageRemoved(:final sessionID, :final messageID) => BridgeSseMessageRemoved(
        sessionID: sessionID,
        messageID: messageID,
      ),
      SseMessagePartUpdated(:final part) => BridgeSseMessagePartUpdated(part: mapPart(part)),
      SseMessagePartDelta(
        :final sessionID,
        :final messageID,
        :final partID,
        :final field,
        :final delta,
      ) =>
        BridgeSseMessagePartDelta(
          sessionID: sessionID,
          messageID: messageID,
          partID: partID,
          field: field,
          delta: delta,
        ),
      SseMessagePartRemoved(:final sessionID, :final messageID, :final partID) => BridgeSseMessagePartRemoved(
        sessionID: sessionID,
        messageID: messageID,
        partID: partID,
      ),
      SsePtyCreated() => const BridgeSsePtyCreated(),
      SsePtyUpdated() => const BridgeSsePtyUpdated(),
      SsePtyExited(:final id, :final exitCode) => BridgeSsePtyExited(id: id, exitCode: exitCode),
      SsePtyDeleted(:final id) => BridgeSsePtyDeleted(id: id),
      SsePermissionAsked(:final requestID, :final sessionID, :final tool, :final description) =>
        BridgeSsePermissionAsked(
          requestID: requestID,
          sessionID: sessionID,
          tool: tool,
          description: description,
        ),
      SsePermissionReplied(:final requestID, :final sessionID, :final reply) => BridgeSsePermissionReplied(
        requestID: requestID,
        sessionID: sessionID,
        reply: reply,
      ),
      SsePermissionUpdated() => const BridgeSsePermissionUpdated(),
      SseQuestionAsked(:final id, :final sessionID, :final questions) => BridgeSseQuestionAsked(
        id: id,
        sessionID: sessionID,
        questions: questions.map((q) => q.toJson()).toList(),
      ),
      SseQuestionReplied(:final requestID, :final sessionID) => BridgeSseQuestionReplied(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseQuestionRejected(:final requestID, :final sessionID) => BridgeSseQuestionRejected(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseTodoUpdated(:final sessionID) => BridgeSseTodoUpdated(sessionID: sessionID),
      SseProjectUpdated() => const BridgeSseProjectUpdated(),
      SseVcsBranchUpdated() => const BridgeSseVcsBranchUpdated(),
      SseFileEdited(:final file) => BridgeSseFileEdited(file: file),
      SseFileWatcherUpdated(:final file, :final event) => BridgeSseFileWatcherUpdated(file: file, event: event),
      SseLspUpdated() => const BridgeSseLspUpdated(),
      SseLspClientDiagnostics(:final serverID, :final path) => BridgeSseLspClientDiagnostics(
        serverID: serverID,
        path: path,
      ),
      SseMcpToolsChanged() => const BridgeSseMcpToolsChanged(),
      SseMcpBrowserOpenFailed() => const BridgeSseMcpBrowserOpenFailed(),
      SseInstallationUpdated(:final version) => BridgeSseInstallationUpdated(version: version),
      SseInstallationUpdateAvailable(:final version) => BridgeSseInstallationUpdateAvailable(version: version),
      SseWorkspaceReady(:final name) => BridgeSseWorkspaceReady(name: name),
      SseWorkspaceFailed(:final message) => BridgeSseWorkspaceFailed(message: message),
      SseTuiToastShow(:final title, :final message, :final variant) => BridgeSseTuiToastShow(
        title: title,
        message: message,
        variant: variant,
      ),
      SseWorktreeReady() => const BridgeSseWorktreeReady(),
      SseWorktreeFailed() => const BridgeSseWorktreeFailed(),
    };
  }

  /// Maps an OpenCode [MessagePart] to a [PluginMessagePart].
  PluginMessagePart mapPart(MessagePart raw) {
    return PluginMessagePart(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      type: toPluginPartType(type: raw.type),
      text: raw.text,
      tool: raw.tool,
      state: switch (raw.state) {
        ToolState(:final status, :final title, :final output, :final error) => PluginToolState(
          status: status,
          title: title,
          output: output != null && output.length > maxToolOutputLength
              ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
              : output,
          error: error,
        ),
        null => null,
      },
      prompt: raw.prompt,
      description: raw.description,
      agent: raw.agent,
      agentName: raw.name,
      attempt: raw.attempt,
      retryError: (raw.error?['data'] as Map<String, dynamic>?)?['message']?.toString(),
    );
  }

  /// Maps an OpenCode part type string to [PluginMessagePartType].
  /// Unknown types are mapped to [PluginMessagePartType.unknown] (invisible)
  /// and logged as a warning so new types are noticed.
  static PluginMessagePartType toPluginPartType({required String type}) => switch (type) {
    "text" => PluginMessagePartType.text,
    "reasoning" => PluginMessagePartType.reasoning,
    "tool" => PluginMessagePartType.tool,
    "subtask" => PluginMessagePartType.subtask,
    "step-start" => PluginMessagePartType.stepStart,
    "step-finish" => PluginMessagePartType.stepFinish,
    "file" => PluginMessagePartType.file,
    "snapshot" => PluginMessagePartType.snapshot,
    "patch" => PluginMessagePartType.patch,
    "agent" => PluginMessagePartType.agent,
    "retry" => PluginMessagePartType.retry,
    "compaction" => PluginMessagePartType.compaction,
    _ => () {
      Log.w("Unknown message part type: '$type' — filtering out");
      return PluginMessagePartType.unknown;
    }(),
  };
}
