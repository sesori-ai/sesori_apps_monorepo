import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "message_part_mapper.dart";
import "models/sse_event_data.g.dart";

/// Maps OpenCode SSE events and message parts to plugin interface types.
///
/// Extracted from [OpenCodePlugin] to isolate the mapping concern.
/// This class is stateless — all methods are pure transformations.
class SseEventMapper {
  final MessagePartMapper _messagePartMapper = const MessagePartMapper();

  /// Maps an [SseEventData] to a [BridgeSseEvent], or null if the event
  /// type has no plugin representation.
  BridgeSseEvent? map(SseEventData event) {
    return switch (event) {
      SseServerConnected() => const BridgeSseServerConnected(),
      SseServerHeartbeat() => const BridgeSseServerHeartbeat(),
      SseServerInstanceDisposed(:final directory) => BridgeSseServerInstanceDisposed(directory: directory),
      SseGlobalDisposed() => const BridgeSseGlobalDisposed(),
      SseSessionCreated(:final info) => BridgeSseSessionCreated(info: info.toJson()),
      SseSessionUpdated(:final info) => BridgeSseSessionUpdated(info: info.toJson()),
      SseSessionDeleted(:final info) => BridgeSseSessionDeleted(info: info.toJson()),
      SseSessionDiff(:final sessionID) => BridgeSseSessionDiff(
        sessionID: sessionID,
      ),
      SseSessionError(:final sessionID) => BridgeSseSessionError(sessionID: sessionID),
      SseSessionCompacted(:final sessionID) => BridgeSseSessionCompacted(sessionID: sessionID),
      SseSessionStatus(:final sessionID, :final status) => BridgeSseSessionStatus(
        sessionID: sessionID,
        status: status.toJson()! as Map<String, dynamic>,
      ),
      // ignore: deprecated_member_use, forwards legacy idle event for backward compatibility
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseCommandExecuted(:final name, :final sessionID, :final arguments, :final messageID) => BridgeSseCommandExecuted(
        name: name,
        sessionID: sessionID,
        arguments: arguments,
        messageID: messageID,
      ),
      SseMessageUpdated(:final info) => BridgeSseMessageUpdated(info: info.toJson()! as Map<String, dynamic>),
      SseMessageRemoved(:final sessionID, :final messageID) => BridgeSseMessageRemoved(
        sessionID: sessionID,
        messageID: messageID,
      ),
      SseMessagePartUpdated(:final part) => BridgeSseMessagePartUpdated(part: _messagePartMapper.mapPart(part)),
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
}
