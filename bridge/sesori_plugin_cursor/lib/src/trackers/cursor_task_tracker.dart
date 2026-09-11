import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Cursor-owned correlation for generic Task cards whose only terminal signal
/// may be the owning prompt lifecycle.
///
/// Records have no child identity and never affect root activity, counts,
/// fanout, process residency, or stop behavior.
final class CursorTaskTracker() {
  final Map<String, Map<String, PluginMessagePartTool>> _activeBySession = {};

  /// Deleted sessions for the current Cursor process. Process reset clears the
  /// tombstones after the old notification source has been drained.
  final Set<String> _deletedSessionIds = {};

  void recordInvocation({
    required String sessionId,
    required String toolCallId,
    required PluginMessagePartTool genericPart,
  }) {
    if (_deletedSessionIds.contains(sessionId)) return;
    (_activeBySession[sessionId] ??= {})[toolCallId] = genericPart;
  }

  bool hasInvocation({required String sessionId, required String toolCallId}) =>
      _activeBySession[sessionId]?.containsKey(toolCallId) ?? false;

  void forgetInvocation({required String sessionId, required String toolCallId}) {
    final tasks = _activeBySession[sessionId];
    if (tasks == null) return;
    tasks.remove(toolCallId);
    if (tasks.isEmpty) _activeBySession.remove(sessionId);
  }

  /// Takes and retires every active generic Task invocation for one prompt.
  List<PluginMessagePartTool> takeActiveInvocations({required String sessionId}) =>
      _activeBySession.remove(sessionId)?.values.toList(growable: false) ?? const [];

  /// Forgets one deleted session and fences its late frames in this process.
  void forgetSession({required String sessionId}) {
    _deletedSessionIds.add(sessionId);
    _activeBySession.remove(sessionId);
  }

  /// Drops all process-local correlation and deletion fences after reset.
  void clear() {
    _activeBySession.clear();
    _deletedSessionIds.clear();
  }
}
