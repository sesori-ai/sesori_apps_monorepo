import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../models/claude_task_status.dart";
import "../../models/claude_tool_use_result.dart";
import "../mappers/claude_task_status_mapping.dart";

/// An immutable presentation snapshot of one Claude tool call.
sealed class const ClaudeTrackedTool({
  required final String id,
  required final String messageId,
  required final String name,
  required final Object? input,
  required final PluginToolState state,

  /// Whether this update should emit the session's one-shot diff signal.
  required final bool sessionDiffRequired,

  /// Whether this terminal update invalidates the session's todo projection.
  required final bool todoRefreshRequired,
}) {
  /// The one part shape for this call, shared by live dispatch and replay.
  ///
  /// A task renders only once its input carries the description and prompt
  /// the subtask part requires; while the input is still streaming there is
  /// nothing honest to show, so the caller emits no part.
  PluginMessagePart? toPart({required String sessionId}) => switch (this) {
    ClaudeTrackedToolCall() => PluginMessagePart.tool(
      id: id,
      sessionID: sessionId,
      messageID: messageId,
      tool: name,
      state: state,
    ),
    ClaudeTrackedTask(:final childSessionId) => switch (input) {
      {"description": final String description, "prompt": final String prompt} => PluginMessagePart.subtask(
        id: id,
        sessionID: sessionId,
        messageID: messageId,
        prompt: prompt,
        description: description,
        // The CLI runs the general-purpose agent when the call names none.
        agent: switch (input) {
          {"subagent_type": final String agent} when agent.isNotEmpty => agent,
          _ => "general-purpose",
        },
        taskState: state,
        childSessionID: childSessionId,
      ),
      _ => null,
    },
  };
}

/// An ordinary tool call, rendered as a tool part.
final class const ClaudeTrackedToolCall({
  required super.id,
  required super.messageId,
  required super.name,
  required super.input,
  required super.state,
  required super.sessionDiffRequired,
  required super.todoRefreshRequired,
}) extends ClaudeTrackedTool;

/// An `Agent` launch, rendered as a subtask part.
final class const ClaudeTrackedTask({
  /// The sub-agent's transcript id (`agent-<agentId>`) once a task frame or
  /// tool result named it.
  required final String? childSessionId,
  required super.id,
  required super.messageId,
  required super.name,
  required super.input,
  required super.state,
  required super.sessionDiffRequired,
  required super.todoRefreshRequired,
}) extends ClaudeTrackedTool;

/// Tracks Claude `tool_use` blocks from their streamed start through the
/// matching `tool_result` block.
///
/// `Agent` calls are tracked as tasks in a second per-session map that
/// survives [beginTurn], because a background sub-agent outlives the turn that
/// launched it; only [cancelAll] and [forgetSession] clear it.
final class ClaudeToolTracker() {
  final Map<String, _SessionTools> _sessions = {};
  final Map<String, Map<String, _TrackedTool>> _tasks = {};

  ClaudeTrackedTool start({
    required String sessionId,
    required String messageId,
    required int blockIndex,
    required String toolId,
    required String name,
    required Object? input,
  }) {
    final session = _sessions.putIfAbsent(sessionId, _SessionTools.new);
    final block = session.block(messageId: messageId, blockIndex: blockIndex)..toolId = toolId;
    final tool = _track(
      sessionId: sessionId,
      session: session,
      toolId: toolId,
      messageId: messageId,
      name: name,
      input: input,
      status: block.partialInput.isEmpty ? PluginToolStatus.pending : PluginToolStatus.running,
    );
    if (input != null) tool.input = input;
    if (!_isTerminal(tool.status) && block.partialInput.isNotEmpty) tool.status = PluginToolStatus.running;
    return tool.snapshot(sessionDiffRequired: false);
  }

  /// Applies the complete tool block carried by an assistant message.
  ///
  /// Complete assistant messages arrive before `content_block_stop`, so this
  /// enriches the tracked call without treating it as completed.
  ClaudeTrackedTool upsertCompleteBlock({
    required String sessionId,
    required String messageId,
    required int blockIndex,
    required String toolId,
    required String name,
    required Object? input,
  }) {
    final session = _sessions.putIfAbsent(sessionId, _SessionTools.new);
    session.block(messageId: messageId, blockIndex: blockIndex)
      ..toolId = toolId
      ..hasCompleteInput = true;
    final tool = _track(
      sessionId: sessionId,
      session: session,
      toolId: toolId,
      messageId: messageId,
      name: name,
      input: input,
      status: PluginToolStatus.running,
    );
    tool.input = input;
    if (!_isTerminal(tool.status)) tool.status = PluginToolStatus.running;
    return tool.snapshot(sessionDiffRequired: false);
  }

  _TrackedTool _track({
    required String sessionId,
    required _SessionTools session,
    required String toolId,
    required String messageId,
    required String name,
    required Object? input,
    required PluginToolStatus status,
  }) {
    final tool = session.tools.putIfAbsent(
      toolId,
      () => _TrackedTool(id: toolId, messageId: messageId, name: name, input: input, status: status),
    );
    tool.name = name;
    if (tool.isTask) _tasks.putIfAbsent(sessionId, () => {}).putIfAbsent(toolId, () => tool);
    return tool;
  }

  /// Buffers one `input_json_delta` fragment in wire order.
  ClaudeTrackedTool? appendInput({
    required String sessionId,
    required String messageId,
    required int blockIndex,
    required String partialJson,
  }) {
    final session = _sessions.putIfAbsent(sessionId, _SessionTools.new);
    final block = session.block(messageId: messageId, blockIndex: blockIndex);
    if (partialJson.isNotEmpty) block.partialInput.write(partialJson);
    final toolId = block.toolId;
    if (toolId == null) return null;
    final tool = session.tools[toolId];
    if (tool == null) return null;
    if (!_isTerminal(tool.status)) tool.status = PluginToolStatus.running;
    return tool.snapshot(sessionDiffRequired: false);
  }

  /// Finalizes the buffered input for one content block.
  ClaudeTrackedTool? stopInput({
    required String sessionId,
    required String messageId,
    required int blockIndex,
  }) {
    final session = _sessions[sessionId];
    final block = session?.blocks[messageId]?[blockIndex];
    if (session == null || block == null) return null;
    final toolId = block.toolId;
    if (toolId == null) return null;
    final tool = session.tools[toolId];
    if (tool == null) return null;

    if (!block.hasCompleteInput && block.partialInput.isNotEmpty) {
      try {
        tool.input = jsonDecodeMap(block.partialInput.toString());
      } on FormatException {
        // The exception embeds the partial JSON, which can contain source code
        // or paths and has no diagnostic value beyond the failed decode.
        Log.w(
          "[claude] streamed tool input could not be decoded; retaining the tool without partial input",
        );
      }
    }
    if (!_isTerminal(tool.status)) tool.status = PluginToolStatus.running;
    return tool.snapshot(sessionDiffRequired: false);
  }

  /// Applies a normalized `tool_result`. Unknown ids do not create orphan tool
  /// cards because their originating message identity is unavailable.
  ///
  /// For a task the result is a fallback: an async launch never finalizes and
  /// only binds the child id, any other result finalizes per [isError] unless
  /// a task notification already did, and a later notification replaces it.
  ClaudeTrackedTool? complete({
    required String sessionId,
    required String toolId,
    required String? output,
    required bool isError,
    required List<PluginMessageAttachment> attachments,
    required ClaudeToolUseResult result,
  }) {
    final tool = _sessions[sessionId]?.tools[toolId] ?? _tasks[sessionId]?[toolId];
    if (tool == null) return null;
    if (tool.isTask) {
      switch (result) {
        case ClaudeToolUseResultAsyncLaunched(:final agentId):
          tool.taskId ??= agentId;
          if (!_isTerminal(tool.status)) tool.status = PluginToolStatus.running;
          return tool.snapshot(sessionDiffRequired: false);
        case ClaudeToolUseResultCompleted(:final agentId):
          tool.taskId ??= agentId;
        case ClaudeToolUseResultAbsent() || ClaudeToolUseResultUnknown():
          break;
      }
      if (tool.notified) return tool.snapshot(sessionDiffRequired: false);
    }
    if (_isTerminal(tool.status)) {
      return tool.snapshot(sessionDiffRequired: false, todoRefreshRequired: false);
    }
    tool
      ..status = isError ? PluginToolStatus.error : PluginToolStatus.completed
      ..output = isError ? null : output
      ..error = isError ? output : null
      ..attachments = List.unmodifiable(attachments);
    final sessionDiffRequired = tool.isEdit && !tool.diffEmitted;
    if (sessionDiffRequired) tool.diffEmitted = true;
    return tool.snapshot(
      sessionDiffRequired: sessionDiffRequired,
      todoRefreshRequired: tool.isTodoWrite,
    );
  }

  /// Binds a `task_started` frame to its launching call.
  ClaudeTrackedTool? taskStarted({required String sessionId, required String toolUseId, required String taskId}) {
    final task = _tasks[sessionId]?[toolUseId];
    if (task == null) return null;
    task.taskId ??= taskId;
    if (!_isTerminal(task.status)) task.status = PluginToolStatus.running;
    return task.snapshot(sessionDiffRequired: false);
  }

  /// Applies the authoritative terminal notification for a task, replacing
  /// any tool-result fallback. Returns null when [toolUseId] is not a task in
  /// this session, so callers keep an unmatched envelope visible.
  ClaudeTrackedTool? taskNotified({
    required String sessionId,
    required String toolUseId,
    required String taskId,
    required ClaudeTaskStatus status,
    required String? summary,
    required String? result,
  }) {
    final task = _tasks[sessionId]?[toolUseId];
    if (task == null) return null;
    final mapped = status.toPluginToolStatus();
    task
      ..taskId ??= taskId
      ..notified = true
      ..status = mapped
      ..output = mapped == PluginToolStatus.completed ? _bounded(result ?? summary) : null
      ..error = mapped == PluginToolStatus.error ? _bounded(summary) : null;
    return task.snapshot(sessionDiffRequired: false);
  }

  bool isKnownTask({required String sessionId, required String toolUseId}) =>
      _tasks[sessionId]?.containsKey(toolUseId) ?? false;

  ClaudeTrackedTool? task({required String sessionId, required String toolUseId}) =>
      _tasks[sessionId]?[toolUseId]?.snapshot(sessionDiffRequired: false);

  /// The tool-use ids of tasks still running inside the session's process.
  Set<String> runningTaskToolUseIds({required String sessionId}) => {
    for (final task in _tasks[sessionId]?.values ?? const <_TrackedTool>[])
      if (!_isTerminal(task.status)) task.id,
  };

  /// Marks one running task cancelled; null when it is unknown or already done.
  ClaudeTrackedTool? cancelTask({required String sessionId, required String toolUseId}) {
    final task = _tasks[sessionId]?[toolUseId];
    if (task == null || _isTerminal(task.status)) return null;
    task.status = PluginToolStatus.cancelled;
    return task.snapshot(sessionDiffRequired: false);
  }

  /// Marks every running task cancelled — the process that hosted them is
  /// gone — and forgets the session's tasks. Returns the updated snapshots.
  List<ClaudeTrackedTool> cancelAll({required String sessionId}) {
    final cancelled = [
      for (final toolUseId in runningTaskToolUseIds(sessionId: sessionId))
        ?cancelTask(sessionId: sessionId, toolUseId: toolUseId),
    ];
    _tasks.remove(sessionId);
    return cancelled;
  }

  /// Starts a new turn with no retained block or result correlation state.
  void beginTurn({required String sessionId}) => _sessions.remove(sessionId);

  void forgetSession({required String sessionId}) {
    _sessions.remove(sessionId);
    _tasks.remove(sessionId);
  }
}

final class _SessionTools() {
  final Map<String, _TrackedTool> tools = {};
  final Map<String, Map<int, _StreamedToolBlock>> blocks = {};

  _StreamedToolBlock block({required String messageId, required int blockIndex}) =>
      blocks.putIfAbsent(messageId, () => {}).putIfAbsent(blockIndex, _StreamedToolBlock.new);
}

final class _StreamedToolBlock() {
  String? toolId;
  bool hasCompleteInput = false;
  final StringBuffer partialInput = StringBuffer();
}

final class _TrackedTool({
  required final String id,
  required final String messageId,
  required var String _name,
  required var Object? input,
  required var PluginToolStatus status,
}) {
  String get name => _name;
  set name(String value) {
    _name = value;
    kind = _ClaudeToolKind.parse(value);
  }

  _ClaudeToolKind kind = _ClaudeToolKind.parse(_name);
  String? output;
  String? error;
  List<PluginMessageAttachment> attachments = const [];
  bool diffEmitted = false;

  /// The sub-agent id, once a task frame or tool result named it.
  String? taskId;

  /// Whether a task notification finalized this task; a later tool result
  /// must not overwrite the authoritative status.
  bool notified = false;

  bool get isEdit => kind == _ClaudeToolKind.edit;
  bool get isTodoWrite => kind == _ClaudeToolKind.todoWrite;
  bool get isTask => kind == _ClaudeToolKind.task;

  ClaudeTrackedTool snapshot({required bool sessionDiffRequired, bool todoRefreshRequired = false}) {
    final state = PluginToolState(status: status, title: null, output: output, error: error, attachments: attachments);
    return isTask
        ? ClaudeTrackedTask(
            childSessionId: switch (taskId) {
              final id? => "agent-$id",
              null => null,
            },
            id: id,
            messageId: messageId,
            name: name,
            input: input,
            state: state,
            sessionDiffRequired: sessionDiffRequired,
            todoRefreshRequired: todoRefreshRequired,
          )
        : ClaudeTrackedToolCall(
            id: id,
            messageId: messageId,
            name: name,
            input: input,
            state: state,
            sessionDiffRequired: sessionDiffRequired,
            todoRefreshRequired: todoRefreshRequired,
          );
  }
}

bool _isTerminal(PluginToolStatus status) => status.isTerminal;

String? _bounded(String? value) =>
    value == null || value.isEmpty ? null : String.fromCharCodes(value.runes.take(maxToolOutputLength));

enum _ClaudeToolKind() {
  edit,
  todoWrite,
  task,
  other;

  static _ClaudeToolKind parse(String raw) => switch (raw.toLowerCase()) {
    "edit" || "multiedit" || "notebookedit" || "write" => edit,
    "todowrite" => todoWrite,
    "agent" || "task" => task,
    _ => other,
  };
}
