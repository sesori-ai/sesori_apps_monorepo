import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "message_part_mapper.dart";
import "models/sse_event_data.g.dart";

/// Maps OpenCode SSE events and message parts to plugin interface types.
///
/// Extracted from [OpenCodePlugin] to isolate the mapping concern.
/// This class is stateless — all methods are pure transformations.
class SseEventMapper {
  final MessagePartMapper _messagePartMapper = const MessagePartMapper();

  /// Narrows a union's `Object? toJson()` result to the JSON map the bridge
  /// model carries — without a null-assertion (`!`). Known variants always
  /// encode to a map; the fallback only covers an unknown variant whose raw
  /// payload is not a map.
  static Map<String, dynamic> _asMap(Object? json) =>
      json is Map<String, dynamic> ? json : const <String, dynamic>{};

  /// Maps an [SseEventData] to a [BridgeSseEvent], or null if the event
  /// type has no plugin representation.
  ///
  /// [displaySessionId] is the already-resolved root session for permission/
  /// question events (see [OpenCodePlugin._displaySessionIdForEvent]); it is
  /// null for all other event types. Kept as a passed-in value so this mapper
  /// stays a pure, dependency-free transformation.
  BridgeSseEvent? map(SseEventData event, {String? displaySessionId}) {
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
        status: _asMap(status.toJson()),
      ),
      // ignore: deprecated_member_use, forwards legacy idle event for backward compatibility
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseCommandExecuted(:final name, :final sessionID, :final arguments, :final messageID) => BridgeSseCommandExecuted(
        name: name,
        sessionID: sessionID,
        arguments: arguments,
        messageID: messageID,
      ),
      SseMessageUpdated(:final info) => BridgeSseMessageUpdated(info: _asMap(info.toJson())),
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
      // OpenCode's permission.asked payload carries `id` (the permission
      // request id), `permission` (the tool/permission identifier) and the
      // requested `patterns`; there is no separate `description` field, so
      // the requested patterns stand in for the human-readable detail.
      SsePermissionAsked(:final id, :final sessionID, :final permission, :final patterns) =>
        BridgeSsePermissionAsked(
          requestID: id,
          sessionID: sessionID,
          displaySessionId: displaySessionId,
          tool: permission,
          description: patterns.join(", "),
        ),
      SsePermissionReplied(:final requestID, :final sessionID, :final reply) => BridgeSsePermissionReplied(
        requestID: requestID,
        sessionID: sessionID,
        displaySessionId: displaySessionId,
        reply: reply,
      ),
      SsePermissionUpdated() => const BridgeSsePermissionUpdated(),
      SseQuestionAsked(:final id, :final sessionID, :final questions) => BridgeSseQuestionAsked(
        id: id,
        sessionID: sessionID,
        displaySessionId: displaySessionId,
        questions: questions.map((q) => q.toJson()).toList(),
      ),
      SseQuestionReplied(:final requestID, :final sessionID) => BridgeSseQuestionReplied(
        requestID: requestID,
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      SseQuestionRejected(:final requestID, :final sessionID) => BridgeSseQuestionRejected(
        requestID: requestID,
        sessionID: sessionID,
        displaySessionId: displaySessionId,
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
