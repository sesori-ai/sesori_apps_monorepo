import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/cursor_task_dto.dart";
import "repositories/cursor_generated_image_reader.dart";
import "trackers/cursor_task_tracker.dart";

/// Cursor's event mapper: the standard ACP `session/update` handling from
/// [AcpEventMapper] plus Cursor's `cursor/*` notification extensions.
///
/// cursor-agent sends some extensions (`cursor/generate_image`,
/// `cursor/update_todos`) as `extMethod` JSON-RPC *requests* even though it
/// treats them as fire-and-forget; the approval registry acks and re-injects
/// those into the notification pipeline (see
/// `CursorApprovalRegistry.handleExtensionRequest`), so this mapper is the
/// single handling site for both wire shapes.
class CursorEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final CursorGeneratedImageReader _generatedImageReader,
  required final CursorTaskTracker _taskTracker,

  /// The plugin's active-turn resolver ([AcpPlugin.activeTurnSessionId]) — the
  /// last-resort attribution for Cursor extension payloads that omit
  /// `sessionId` (cursor-agent's extension calls carry only the originating
  /// `toolCallId`, or nothing). The same closure backs the approval registry's
  /// session fallback, so "which session does an unattributed payload belong
  /// to" has exactly one owner: the plugin, which also clears its state when a
  /// session is deleted.
  required final String? Function() _activeSessionResolver,
}) extends AcpEventMapper {
  @override
  void beginTurn({required String sessionId, required String? messageId}) {
    _taskTracker.beginTurn(sessionId: sessionId);
    super.beginTurn(sessionId: sessionId, messageId: messageId);
  }

  @override
  List<BridgeSseEvent> map(AcpNotification notification) {
    final events = super.map(notification);
    _observeStandardTask(notification: notification, events: events);
    return events;
  }

  @override
  List<BridgeSseEvent> mapPromptResult({
    required String sessionId,
    required AcpStopReason stopReason,
  }) {
    if (stopReason != AcpStopReason.cancelled) return const [];
    return [
      for (final part in _taskTracker.takeActiveInvocations(sessionId: sessionId))
        BridgeSseMessagePartUpdated(
          part: _mapTerminalGeneric(
            genericPart: part,
            status: PluginToolStatus.cancelled,
            error: null,
          ),
        ),
    ];
  }

  @override
  List<BridgeSseEvent> mapPromptLifecycleFailure({
    required String sessionId,
    required String failureMessage,
  }) => [
    for (final part in _taskTracker.takeActiveInvocations(sessionId: sessionId))
      BridgeSseMessagePartUpdated(
        part: _mapTerminalGeneric(
          genericPart: part,
          status: PluginToolStatus.error,
          error: String.fromCharCodes(failureMessage.runes.take(maxToolOutputLength)),
        ),
      ),
  ];

  @override
  void forgetSession(String sessionId) {
    _taskTracker.forgetSession(sessionId: sessionId);
    super.forgetSession(sessionId);
  }

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    switch (notification.method) {
      case "cursor/update_todos":
        final sessionId = _extensionSessionId(notification.params);
        if (sessionId == null) return const [];
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
      case "cursor/generate_image":
        return _mapGenerateImage(notification: notification);
      case "cursor/task":
        return _mapTaskRequest(notification: notification);
    }
    // Other extension notifications have no sesori analog.
    return super.mapExtension(notification);
  }

  void _observeStandardTask({
    required AcpNotification notification,
    required List<BridgeSseEvent> events,
  }) {
    if (notification.method != AcpMethods.sessionUpdate) return;
    final sessionId = notification.params["sessionId"];
    final update = _map(notification.params["update"]);
    if (sessionId is! String || sessionId.isEmpty || update == null) return;
    final updateType = update["sessionUpdate"];
    if (updateType != "tool_call" && updateType != "tool_call_update") return;
    final toolCallId = update["toolCallId"];
    if (toolCallId is! String || toolCallId.isEmpty) return;
    final genericParts = events
        .whereType<BridgeSseMessagePartUpdated>()
        .map((event) => event.part)
        .whereType<PluginMessagePartTool>()
        .toList(growable: false);
    if (genericParts.isEmpty) return;
    final genericPart = genericParts.last;

    final knownTask = _taskTracker.hasInvocation(
      sessionId: sessionId,
      toolCallId: toolCallId,
    );
    final taskStatus = _parseTaskUpdateStatus(rawStatus: update["status"]);
    final terminalTaskUpdate = switch (taskStatus) {
      _CursorTaskUpdateStatus.completed || _CursorTaskUpdateStatus.failed => true,
      _CursorTaskUpdateStatus.active || _CursorTaskUpdateStatus.unknown => false,
      _CursorTaskUpdateStatus.omitted => genericPart.state.status.isTerminal,
    };
    if (!knownTask) {
      final input = _parseTaskInput(raw: update["rawInput"]);
      if (input?.toolName != CursorTaskTool.task) return;
      if (terminalTaskUpdate && updateType != "tool_call") return;
      _taskTracker.recordActiveInvocation(
        sessionId: sessionId,
        toolCallId: toolCallId,
        genericPart: genericPart,
      );
    } else if (!terminalTaskUpdate) {
      _taskTracker.recordActiveInvocation(
        sessionId: sessionId,
        toolCallId: toolCallId,
        genericPart: genericPart,
      );
    }
    if (!terminalTaskUpdate) return;

    if (genericPart.state.status != PluginToolStatus.completed) {
      _taskTracker.forgetInvocation(sessionId: sessionId, toolCallId: toolCallId);
      return;
    }
    final output = _parseTaskOutput(raw: update["rawOutput"]);
    if (output == null) {
      _taskTracker.forgetInvocation(sessionId: sessionId, toolCallId: toolCallId);
      return;
    }
    if (output.isBackground) {
      _taskTracker.recordUnresolvedBackgroundWork(
        sessionId: sessionId,
        toolCallId: toolCallId,
      );
      return;
    }
    _taskTracker.markForegroundCompleted(
      sessionId: sessionId,
      toolCallId: toolCallId,
      genericPart: genericPart,
    );
  }

  List<BridgeSseEvent> _mapTaskRequest({required AcpNotification notification}) {
    final request = _parseTaskRequest(raw: notification.params);
    if (request == null) return const [];
    final sessionId = switch (_taskSessionLookup(params: notification.params)) {
      CursorTaskSessionFound(:final sessionId) => sessionId,
      CursorTaskSessionNotFound() || CursorTaskSessionAmbiguous() => null,
    };
    if (sessionId == null) return const [];
    final genericPart = _taskTracker.takeForegroundCompleted(
      sessionId: sessionId,
      toolCallId: request.toolCallId,
    );
    if (genericPart == null) return const [];
    final replacement = _mapCompletedForeground(
      genericPart: genericPart,
      request: request,
    );
    return replacement == null ? const [] : [BridgeSseMessagePartUpdated(part: replacement)];
  }

  PluginMessagePart? _mapCompletedForeground({
    required PluginMessagePartTool genericPart,
    required CursorTaskRequestDto request,
  }) {
    final prompt = _nonblank(request.prompt);
    final description = _nonblank(request.description);
    final agent = switch (request.subagentType.custom) {
      CursorSubagentType.unspecified => CursorSubagentType.unspecified.name,
      CursorSubagentType.unknown || null => null,
    };
    if (prompt == null || description == null || agent == null) return null;

    return PluginMessagePart.subtask(
      id: genericPart.id,
      sessionID: genericPart.sessionID,
      messageID: genericPart.messageID,
      prompt: prompt,
      description: description,
      agent: agent,
      taskState: PluginToolState(
        status: PluginToolStatus.completed,
        title: genericPart.state.title,
        shellCommand: null,
        output: genericPart.state.output,
        error: null,
        attachments: genericPart.state.attachments,
      ),
      childSessionID: null,
    );
  }

  PluginMessagePart _mapTerminalGeneric({
    required PluginMessagePartTool genericPart,
    required PluginToolStatus status,
    required String? error,
  }) => PluginMessagePart.tool(
    id: genericPart.id,
    sessionID: genericPart.sessionID,
    messageID: genericPart.messageID,
    tool: genericPart.tool,
    state: PluginToolState(
      status: status,
      title: genericPart.state.title,
      shellCommand: genericPart.state.shellCommand,
      output: null,
      error: error,
      attachments: genericPart.state.attachments,
    ),
  );

  CursorTaskInputDto? _parseTaskInput({required Object? raw}) {
    final json = _map(raw);
    if (json == null) return null;
    try {
      return CursorTaskInputDto.fromJson(json);
    } on Object catch (error, stack) {
      Log.w("[cursor] malformed standard Task input ignored", error, stack);
      return null;
    }
  }

  CursorTaskOutputDto? _parseTaskOutput({required Object? raw}) {
    final json = _map(raw);
    if (json == null) return null;
    try {
      return CursorTaskOutputDto.fromJson(json);
    } on Object catch (error, stack) {
      Log.w("[cursor] malformed standard Task output ignored", error, stack);
      return null;
    }
  }

  CursorTaskRequestDto? _parseTaskRequest({required Object? raw}) {
    final json = _map(raw);
    if (json == null) return null;
    try {
      return CursorTaskRequestDto.fromJson(json);
    } on Object catch (error, stack) {
      Log.w("[cursor] malformed cursor/task request ignored", error, stack);
      return null;
    }
  }

  static String? _nonblank(String value) => value.trim().isEmpty ? null : value;

  static Map<String, dynamic>? _map(Object? raw) => raw is Map ? raw.cast<String, dynamic>() : null;

  List<BridgeSseEvent> _mapGenerateImage({required AcpNotification notification}) {
    final params = notification.params;
    final sessionId = _extensionSessionId(params);
    final path = _pathFromGenerateImageParams(params: params);
    if (sessionId == null || path == null) {
      // The registry already acked the request, so this drop is the last place
      // a lost image can be observed. Local logs keep the path (sanctioned
      // diagnostic context); only the transport stays basename-only.
      Log.w(
        "[cursor] ${notification.method} dropped: "
        "${sessionId == null ? "no resolvable session" : "session $sessionId"}, "
        "${path == null ? "no source path" : "path ${path.trim()}"}",
      );
      return const [];
    }

    final blocks = _generatedImageReader.read(path: path);
    if (blocks.isEmpty) return const [];

    final rawMessageId = params["messageId"];
    return appendAssistantImageBlocks(
      sessionId: sessionId,
      messageId: rawMessageId is String && rawMessageId.isNotEmpty ? rawMessageId : null,
      blocks: blocks,
    );
  }

  CursorTaskSessionLookup _taskSessionLookup({required Map<String, dynamic> params}) {
    final explicit = params["sessionId"];
    if (explicit is String) {
      final trimmed = explicit.trim();
      if (trimmed.isNotEmpty) return CursorTaskSessionFound(sessionId: trimmed);
    }
    final toolCallId = params["toolCallId"];
    if (toolCallId is String && toolCallId.isNotEmpty) {
      final lookup = _taskTracker.lookupSessionForToolCallId(toolCallId: toolCallId);
      if (lookup is! CursorTaskSessionNotFound) return lookup;
    }
    final activeSessionId = _activeSessionResolver();
    return activeSessionId == null
        ? const CursorTaskSessionNotFound()
        : CursorTaskSessionFound(sessionId: activeSessionId);
  }

  /// The session an extension payload belongs to: its explicit `sessionId`
  /// (trimmed, matching [AcpApprovalRegistry.resolveSessionId]), else the
  /// session owning the originating `toolCallId`, else the plugin's active
  /// turn. Null only when none is available — the caller must drop the payload
  /// (an event stamped with "" is discarded by the client).
  String? _extensionSessionId(Map<String, dynamic> params) {
    final explicit = params["sessionId"];
    if (explicit is String) {
      final trimmed = explicit.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final toolCallId = params["toolCallId"];
    if (toolCallId is String && toolCallId.isNotEmpty) {
      final fromTool = sessionIdForToolCallId(toolCallId: toolCallId);
      if (fromTool != null) return fromTool;
    }
    return _activeSessionResolver();
  }

  /// `filePath` is the live-verified key; `path` has provenance from the
  /// pre-PR wire tests. Only absolute paths are accepted: a relative or bare
  /// value would resolve against the bridge process CWD, not the session's
  /// project, so it must never be opened.
  static String? _pathFromGenerateImageParams({required Map<String, dynamic> params}) {
    for (final key in const ["filePath", "path"]) {
      final value = params[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (p.isAbsolute(trimmed)) return trimmed;
      Log.w("[cursor] generate_image rejected non-absolute source path: $trimmed");
    }
    return null;
  }

  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (_isGateNotice(text)) {
      // AcpEventMapper preserves cursor-agent's exact wording as the shown message.
      return const AcpHaltNotice(errorName: "cursor_gate");
    }
    return null;
  }

  /// cursor-agent account/plan/settings gate notices. When the selected model
  /// or action isn't permitted on the Cursor account, cursor-agent ends the
  /// turn normally (`stopReason: end_turn`) and streams one of these as an
  /// ordinary `agent_message_chunk` — on the wire it is indistinguishable from
  /// real output, so it is recognized here by exact (normalized) text.
  ///
  /// Add a phrase only with a captured wire trace of cursor-agent emitting it;
  /// a reworded or localized gate simply falls through to plain assistant text
  /// (the pre-existing behavior — no regression).
  static const Set<String> _gateNoticePhrases = {
    "check your settings to continue",
  };

  static _CursorTaskUpdateStatus _parseTaskUpdateStatus({required Object? rawStatus}) => switch (rawStatus) {
    "pending" || "in_progress" => _CursorTaskUpdateStatus.active,
    "completed" => _CursorTaskUpdateStatus.completed,
    "failed" => _CursorTaskUpdateStatus.failed,
    null => _CursorTaskUpdateStatus.omitted,
    _ => _CursorTaskUpdateStatus.unknown,
  };

  static bool _isGateNotice(String text) => _gateNoticePhrases.contains(_normalize(text));

  /// Normalizes a notice for matching against [_gateNoticePhrases]: collapses
  /// whitespace, lowercases, and strips surrounding punctuation/emoji so the
  /// leading newlines, case, or decoration cursor-agent varies do not defeat
  /// the match — while still requiring the whole message to BE the phrase, so
  /// ordinary prose that merely mentions it is never misclassified. Letters and
  /// digits of any script are content, never strippable decoration: a message
  /// carrying words beyond the phrase must not collapse into a gate match.
  static String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r"\s+"), " ").trim().toLowerCase();
    return collapsed.replaceAll(
      RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$", unicode: true),
      "",
    );
  }
}

enum _CursorTaskUpdateStatus() {
  active,
  completed,
  failed,
  unknown,
  omitted,
}
