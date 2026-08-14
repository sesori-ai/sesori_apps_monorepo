import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

final class const PiTrackedTool({
  required final String id,
  required final String messageId,
  required final String name,
  required final PluginToolState state,
  required final bool sessionDiffRequired,
});

final class PiToolTracker() {
  final Map<String, Map<String, _TrackedTool>> _sessions = {};

  PiTrackedTool? pending({
    required String sessionId,
    required String messageId,
    required String toolId,
    required String name,
  }) {
    if (toolId.isEmpty || name.isEmpty) return null;
    final tools = _sessions.putIfAbsent(sessionId, () => {});
    final tool = tools.putIfAbsent(
      toolId,
      () => _TrackedTool(id: toolId, messageId: messageId, name: name),
    );
    tool
      ..messageId = messageId
      ..name = name;
    return tool.snapshot(sessionDiffRequired: false);
  }

  PiTrackedTool? running({
    required String sessionId,
    required String toolId,
    required String? name,
    required PluginToolState state,
  }) {
    final tool = _sessions[sessionId]?[toolId];
    if (tool == null || tool.isTerminal) return null;
    if (name != null && name.isNotEmpty) tool.name = name;
    tool.state = state;
    return tool.snapshot(sessionDiffRequired: false);
  }

  PiTrackedTool? complete({
    required String sessionId,
    required String toolId,
    required String? name,
    required PluginToolState state,
  }) {
    final tool = _sessions[sessionId]?[toolId];
    if (tool == null || tool.isTerminal) return null;
    if (name != null && name.isNotEmpty) tool.name = name;
    tool.state = state;
    final diff = tool.isEdit && !tool.diffEmitted;
    if (diff) tool.diffEmitted = true;
    return tool.snapshot(sessionDiffRequired: diff);
  }

  void beginTurn({required String sessionId}) => _sessions.remove(sessionId);

  void forgetSession({required String sessionId}) => _sessions.remove(sessionId);
}

final class _TrackedTool({
  required final String id,
  required var String messageId,
  required var String name,
}) {
  PluginToolState state = const PluginToolState(
    status: PluginToolStatus.pending,
    title: null,
    output: null,
    error: null,
    attachments: [],
  );
  bool diffEmitted = false;

  bool get isTerminal => state.status == PluginToolStatus.completed || state.status == PluginToolStatus.error;
  bool get isEdit => name.toLowerCase() == "edit" || name.toLowerCase() == "write";

  PiTrackedTool snapshot({required bool sessionDiffRequired}) => PiTrackedTool(
    id: id,
    messageId: messageId,
    name: name,
    state: state,
    sessionDiffRequired: sessionDiffRequired,
  );
}
