import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

/// An immutable presentation snapshot of one Claude tool call.
final class ClaudeTrackedTool {
  const ClaudeTrackedTool({
    required this.id,
    required this.messageId,
    required this.name,
    required this.input,
    required this.state,
    required this.sessionDiffRequired,
  });

  final String id;
  final String messageId;
  final String name;
  final Object? input;
  final PluginToolState state;

  /// Whether this update should emit the session's one-shot diff signal.
  final bool sessionDiffRequired;
}

/// Tracks Claude `tool_use` blocks from their streamed start through the
/// matching `tool_result` block.
final class ClaudeToolTracker {
  final Map<String, _SessionTools> _sessions = {};

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
    final tool = session.tools.putIfAbsent(
      toolId,
      () => _TrackedTool(
        id: toolId,
        messageId: messageId,
        name: name,
        input: input,
        status: block.partialInput.isEmpty ? PluginToolStatus.pending : PluginToolStatus.running,
      ),
    );
    tool.name = name;
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
    final tool = session.tools.putIfAbsent(
      toolId,
      () => _TrackedTool(
        id: toolId,
        messageId: messageId,
        name: name,
        input: input,
        status: PluginToolStatus.running,
      ),
    );
    tool.name = name;
    tool.input = input;
    if (!_isTerminal(tool.status)) tool.status = PluginToolStatus.running;
    return tool.snapshot(sessionDiffRequired: false);
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
  ClaudeTrackedTool? complete({
    required String sessionId,
    required String toolId,
    required String? output,
    required bool isError,
    required List<PluginMessageAttachment> attachments,
  }) {
    final tool = _sessions[sessionId]?.tools[toolId];
    if (tool == null) return null;
    tool
      ..status = isError ? PluginToolStatus.error : PluginToolStatus.completed
      ..output = isError ? null : output
      ..error = isError ? output : null
      ..attachments = List.unmodifiable(attachments);
    final sessionDiffRequired = tool.isEdit && !tool.diffEmitted;
    if (sessionDiffRequired) tool.diffEmitted = true;
    return tool.snapshot(sessionDiffRequired: sessionDiffRequired);
  }

  /// Starts a new turn with no retained block or result correlation state.
  void beginTurn({required String sessionId}) => _sessions.remove(sessionId);

  void forgetSession({required String sessionId}) => _sessions.remove(sessionId);
}

final class _SessionTools {
  final Map<String, _TrackedTool> tools = {};
  final Map<String, Map<int, _StreamedToolBlock>> blocks = {};

  _StreamedToolBlock block({required String messageId, required int blockIndex}) =>
      blocks.putIfAbsent(messageId, () => {}).putIfAbsent(blockIndex, _StreamedToolBlock.new);
}

final class _StreamedToolBlock {
  String? toolId;
  bool hasCompleteInput = false;
  final StringBuffer partialInput = StringBuffer();
}

final class _TrackedTool {
  _TrackedTool({
    required this.id,
    required this.messageId,
    required this.name,
    required this.input,
    required this.status,
  });

  final String id;
  final String messageId;
  String name;
  Object? input;
  PluginToolStatus status;
  String? output;
  String? error;
  List<PluginMessageAttachment> attachments = const [];
  bool diffEmitted = false;

  bool get isEdit => const {"edit", "multiedit", "notebookedit", "write"}.contains(name.toLowerCase());

  ClaudeTrackedTool snapshot({required bool sessionDiffRequired}) => ClaudeTrackedTool(
    id: id,
    messageId: messageId,
    name: name,
    input: input,
    state: PluginToolState(
      status: status,
      title: null,
      output: output,
      error: error,
      attachments: attachments,
    ),
    sessionDiffRequired: sessionDiffRequired,
  );
}

bool _isTerminal(PluginToolStatus status) => status == PluginToolStatus.completed || status == PluginToolStatus.error;
