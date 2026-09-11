import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Live correlation phase for one generic Cursor Task card.
enum CursorTaskPhase() {
  activeModeUnknown,
  foregroundCompleted,
}

/// Closed result for Cursor-local Task tool-call ownership lookup.
sealed class const CursorTaskSessionLookup();

final class const CursorTaskSessionNotFound() extends CursorTaskSessionLookup;

final class const CursorTaskSessionAmbiguous() extends CursorTaskSessionLookup;

final class const CursorTaskSessionFound({required final String sessionId}) extends CursorTaskSessionLookup;

/// Cursor-owned correlation for generic Task cards whose foreground/background
/// mode becomes known only on an explicit terminal standard update.
///
/// Records have no child identity and never affect root activity, child counts,
/// or fanout. Active mode-unknown records and root-level unresolved-background
/// observations inform Cursor's narrow safe-stop policy.
final class CursorTaskTracker() {
  final Map<String, Map<String, _CursorTaskRecord>> _bySession = {};
  final Set<String> _rootsWithUnresolvedBackgroundWork = {};
  final StreamController<void> _residencyChanges = StreamController<void>.broadcast(sync: true);

  /// Emits only when unresolved process-residency state changes.
  Stream<void> get residencyChanges => _residencyChanges.stream;

  bool get requiresProcessResidency => _rootsWithUnresolvedBackgroundWork.isNotEmpty;

  int activeTaskCount({required String sessionId}) =>
      _bySession[sessionId]?.values.where((record) => record.phase == CursorTaskPhase.activeModeUnknown).length ?? 0;

  bool hasUnresolvedBackgroundWork({required String sessionId}) =>
      _rootsWithUnresolvedBackgroundWork.contains(sessionId);

  /// Deleted sessions for the current Cursor process. Process reset clears the
  /// tombstones after the old notification source has been drained.
  final Set<String> _deletedSessionIds = {};

  /// Records or updates one pending/running generic Task card.
  void recordActiveInvocation({
    required String sessionId,
    required String toolCallId,
    required PluginMessagePartTool genericPart,
  }) {
    if (_deletedSessionIds.contains(sessionId)) return;
    final invocations = _bySession[sessionId] ??= {};
    if (invocations[toolCallId]?.phase == CursorTaskPhase.foregroundCompleted) return;
    invocations[toolCallId] = _CursorTaskRecord(
      genericPart: genericPart,
      phase: CursorTaskPhase.activeModeUnknown,
    );
  }

  bool hasInvocation({required String sessionId, required String toolCallId}) =>
      _bySession[sessionId]?.containsKey(toolCallId) ?? false;

  /// Marks one exact known Task as explicitly foreground-completed, retaining
  /// the latest generic completed card for the following `cursor/task` request.
  void markForegroundCompleted({
    required String sessionId,
    required String toolCallId,
    required PluginMessagePartTool genericPart,
  }) {
    final invocation = _bySession[sessionId]?[toolCallId];
    if (invocation == null) return;
    invocation
      ..genericPart = genericPart
      ..phase = CursorTaskPhase.foregroundCompleted;
  }

  /// Resolves one exact tool-call identity without collapsing duplicate ids
  /// across roots into the not-found case.
  CursorTaskSessionLookup lookupSessionForToolCallId({required String toolCallId}) {
    final sessionIds = <String>{
      for (final entry in _bySession.entries)
        if (entry.value.containsKey(toolCallId)) entry.key,
    };
    return switch (sessionIds.toList(growable: false)) {
      [final sessionId] => CursorTaskSessionFound(sessionId: sessionId),
      [] => const CursorTaskSessionNotFound(),
      _ => const CursorTaskSessionAmbiguous(),
    };
  }

  /// Retires one known Task into a root-level observation. Cursor exposes no
  /// terminal identity or running count for work launched in background.
  void recordUnresolvedBackgroundWork({required String sessionId, required String toolCallId}) {
    if (_deletedSessionIds.contains(sessionId)) return;
    forgetInvocation(sessionId: sessionId, toolCallId: toolCallId);
    if (_rootsWithUnresolvedBackgroundWork.add(sessionId)) _notifyResidencyChanged();
  }

  void forgetInvocation({required String sessionId, required String toolCallId}) {
    final invocations = _bySession[sessionId];
    if (invocations == null) return;
    invocations.remove(toolCallId);
    if (invocations.isEmpty) _bySession.remove(sessionId);
  }

  /// Takes the exact completed generic card once. Active mode-unknown records
  /// cannot be projected as completed tiles.
  PluginMessagePartTool? takeForegroundCompleted({
    required String sessionId,
    required String toolCallId,
  }) {
    final invocation = _bySession[sessionId]?[toolCallId];
    if (invocation?.phase != CursorTaskPhase.foregroundCompleted) return null;
    forgetInvocation(sessionId: sessionId, toolCallId: toolCallId);
    return invocation?.genericPart;
  }

  /// Takes and retires only active mode-unknown Tasks for prompt cancellation
  /// or failure settlement. Completed correlation remains consumable.
  List<PluginMessagePartTool> takeActiveInvocations({required String sessionId}) {
    final invocations = _bySession[sessionId];
    if (invocations == null) return const [];
    final active = [
      for (final invocation in invocations.values)
        if (invocation.phase == CursorTaskPhase.activeModeUnknown) invocation.genericPart,
    ];
    invocations.removeWhere((_, invocation) => invocation.phase == CursorTaskPhase.activeModeUnknown);
    if (invocations.isEmpty) _bySession.remove(sessionId);
    return active;
  }

  /// Clears every prior-turn Task record at the next root turn.
  void beginTurn({required String sessionId}) {
    _bySession.remove(sessionId);
  }

  /// Forgets one deleted session and fences its late frames in this process.
  /// AcpPlugin invokes mapper cleanup for every descendant before dropping its
  /// child tracker, so descendant Task correlation receives the same fence.
  void forgetSession({required String sessionId}) {
    _deletedSessionIds.add(sessionId);
    _bySession.remove(sessionId);
    if (_rootsWithUnresolvedBackgroundWork.remove(sessionId)) _notifyResidencyChanged();
  }

  /// Drops all process-local correlation and deletion fences after reset.
  void clear() {
    final residencyChanged = _rootsWithUnresolvedBackgroundWork.isNotEmpty;
    _bySession.clear();
    _deletedSessionIds.clear();
    _rootsWithUnresolvedBackgroundWork.clear();
    if (residencyChanged) _notifyResidencyChanged();
  }

  Future<void> dispose() async {
    clear();
    await _residencyChanges.close();
  }

  void _notifyResidencyChanged() {
    if (!_residencyChanges.isClosed) _residencyChanges.add(null);
  }
}

final class _CursorTaskRecord({
  required var PluginMessagePartTool genericPart,
  required var CursorTaskPhase phase,
});
