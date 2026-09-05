import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "assistant_message_mapper.dart";
import "message_part_mapper.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/message.g.dart";
import "models/openapi/user_message.g.dart";
import "models/sse_event_data.g.dart";
import "plugin_model_mapper.dart";
import "question_info_mapper.dart";

/// Maps OpenCode SSE events and message parts to plugin interface types.
///
/// Extracted from [OpenCodePlugin] to isolate the mapping concern.
/// This class is stateless — all methods are pure transformations.
class SseEventMapper({final AssistantMessageMapper _assistantMessageMapper = const AssistantMessageMapper()}) {
  final MessagePartMapper _messagePartMapper = const MessagePartMapper();
  final QuestionInfoMapper _questionInfoMapper = const QuestionInfoMapper();

  /// Maps a `message.updated` payload to its plugin envelope, mirroring the
  /// REST load path ([PluginModelMapper.mapMessageWithParts]). Crucially this
  /// collapses an errored assistant message (`role: "assistant"` + `error`)
  /// into the error envelope via [AssistantMessageMapper]; forwarding it as an
  /// assistant message would leave a blank turn on the phone until the session
  /// is re-opened.
  PluginMessage? _mapMessageInfo(Message info, {required String? promptId}) {
    final pluginMessage = switch (info) {
      UserMessage(:final id, :final sessionID, :final agent, :final time) => PluginMessage.user(
        id: id,
        sessionID: sessionID,
        agent: agent,
        time: PluginMessageTime(created: time.created.toInt(), completed: null),
        // Set for a message this bridge's own send created; a message authored
        // anywhere else (the OpenCode TUI, another tool) has none.
        promptId: promptId,
      ),
      AssistantMessage() => _assistantMessageMapper.map(info),
      // Unknown roles from a newer OpenCode server have no plugin shape the
      // bridge can deliver; the event is dropped here.
      _ => null,
    };
    return pluginMessage;
  }

  /// Maps an [SseEventData] to a [BridgeSseEvent], or null if the event
  /// type has no plugin representation.
  ///
  /// [displaySessionId] is the already-resolved root session for permission/
  /// question events (see [OpenCodePlugin._displaySessionIdForEvent]); it is
  /// null for all other event types. [promptId] is likewise resolved by the
  /// plugin (see [OpenCodePlugin._promptIdForEvent]) for the user message its
  /// own send created. Both are passed-in values so this mapper stays a pure,
  /// dependency-free transformation.
  BridgeSseEvent? map(SseEventData event, {String? displaySessionId, String? promptId}) {
    return switch (event) {
      SseServerConnected() => const BridgeSseServerConnected(),
      SseServerHeartbeat() => const BridgeSseServerHeartbeat(),
      SseServerInstanceDisposed(:final directory) => BridgeSseServerInstanceDisposed(directory: directory),
      SseGlobalDisposed() => const BridgeSseGlobalDisposed(),
      SseSessionCreated(:final info) => BridgeSseSessionCreated(info: info.toJson()),
      SseSessionUpdated(:final info) => BridgeSseSessionUpdated(info: info.toJson(), titleChanged: false),
      SseSessionDeleted(:final info) => BridgeSseSessionDeleted(info: info.toJson()),
      SseSessionDiff(:final sessionID) => BridgeSseSessionDiff(
        sessionID: sessionID,
      ),
      SseSessionError(:final sessionID) => BridgeSseSessionError(sessionID: sessionID),
      SseSessionCompacted(:final sessionID) => BridgeSseSessionCompacted(sessionID: sessionID),
      SseSessionStatus(:final sessionID, :final status) => switch (knownPluginSessionStatus(status)) {
        final pluginStatus? => BridgeSseSessionStatus(sessionID: sessionID, status: pluginStatus),
        // A status kind this plugin does not know carries nothing the bridge
        // can deliver; the event is dropped here instead of at the relay.
        null => null,
      },
      // COMPATIBILITY 2026-05-18 (v0.7.0): Older OpenCode runtimes emit session.idle. Remove this branch and manifest variant when those runtimes are unsupported.
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseCommandExecuted(:final name, :final sessionID, :final arguments, :final messageID) => BridgeSseCommandExecuted(
        name: name,
        sessionID: sessionID,
        arguments: arguments,
        messageID: messageID,
      ),
      SseMessageUpdated(:final info) => switch (_mapMessageInfo(info, promptId: promptId)) {
        final message? => BridgeSseMessageUpdated(info: message),
        null => null,
      },
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
      // OpenCode's permission.asked payload carries `id` (the permission
      // request id), `permission` (the tool/permission identifier) and the
      // requested `patterns`; there is no separate `description` field, so
      // the requested patterns stand in for the human-readable detail.
      SsePermissionAsked(:final id, :final sessionID, :final permission, :final patterns) => BridgeSsePermissionAsked(
        requestID: id,
        sessionID: sessionID,
        displaySessionId: displaySessionId,
        tool: permission,
        description: patterns.join(", "),
        allowAlways: true,
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
        questions: _questionInfoMapper.mapQuestionInfos(questions),
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
      SseInstallationUpdateAvailable(:final version) => BridgeSseInstallationUpdateAvailable(version: version),
      // Editor and runtime housekeeping no client consumes: PTY, file-watcher,
      // LSP, MCP, installation-updated, workspace and worktree notifications
      // stop here.
      SsePtyCreated() ||
      SsePtyUpdated() ||
      SsePtyExited() ||
      SsePtyDeleted() ||
      SseFileWatcherUpdated() ||
      SseLspUpdated() ||
      SseLspClientDiagnostics() ||
      SseMcpToolsChanged() ||
      SseMcpBrowserOpenFailed() ||
      SseInstallationUpdated() ||
      SseWorkspaceReady() ||
      SseWorkspaceFailed() ||
      SseWorktreeReady() ||
      SseWorktreeFailed() => null,
      SseTuiToastShow(:final title, :final message, :final variant) => BridgeSseTuiToastShow(
        sessionID: null,
        title: title,
        message: message,
        variant: variant,
      ),
    };
  }
}
