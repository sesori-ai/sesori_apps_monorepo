import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/codex_sub_agent_rollout_fact.dart";
import "models/codex_thread_record.dart";

/// One service-owned sub-agent tile snapshot. [callId] is both the persisted
/// `spawn_agent` call id and the live `subAgentActivity` item id.
final class const CodexTrackedSubAgent({
  required final String callId,
  required final CodexThreadRecord child,
  required final String prompt,
  required final String agent,
  required final PluginToolStatus status,
});

/// Layer-2 owner of Codex sub-agent ancestry, root busy accounting, and tile
/// lifecycle.
///
/// Codex never emits `thread/started` for a spawned child. The parent's
/// `subAgentActivity started` item supplies child id and exact spawn call id.
/// A genuine plaintext child `NEW_TASK` supplies the preferred prompt. Normal
/// encrypted input keeps the exact matching `spawn_agent` message fallback.
class CodexSubAgentTracker() {
  final Map<String, CodexThreadRecord> _children = {};
  final Map<String, String> _rootByChild = {};
  final Map<String, Set<String>> _childrenByRoot = {};
  final Set<String> _activeChildren = {};
  final Map<String, CodexSubAgentSpawnFact> _spawns = {};
  final Map<String, _CodexTrackedSubAgentState> _tasksByChild = {};

  /// Roots whose own turn ended while a descendant was still running. Their
  /// idle transition is held until the last busy descendant finishes.
  final Set<String> _rootsAwaitingIdle = {};

  bool isChild({required String sessionId}) => _rootByChild.containsKey(sessionId);

  /// Root session a child rolls up to, or `null` for a root.
  String? rootOf({required String sessionId}) => _rootByChild[sessionId];

  CodexThreadRecord? child({required String sessionId}) => _children[sessionId];

  bool isChildActive({required String sessionId}) => _activeChildren.contains(sessionId);

  Set<String> get activeRootIds => {
    for (final childId in _activeChildren) ?_rootByChild[childId],
  };

  /// Records [child] under its direct parent. Returns false when already known.
  bool record({required CodexThreadRecord child}) {
    final parentId = child.parentId;
    if (parentId == null || _children.containsKey(child.id)) return false;
    final root = _rootByChild[parentId] ?? parentId;
    _children[child.id] = child;
    _rootByChild[child.id] = root;
    (_childrenByRoot[root] ??= {}).add(child.id);
    return true;
  }

  /// Replaces display metadata without changing ancestry or lifecycle.
  void replaceChild({required CodexThreadRecord child}) {
    if (!_children.containsKey(child.id) || _children[child.id]?.parentId != child.parentId) return;
    _children[child.id] = child;
    final task = _tasksByChild[child.id];
    if (task != null) task.child = child;
  }

  /// Records exact call-correlated delegated input. No title, timing, parent
  /// user message, or child ordering participates in this join.
  CodexTrackedSubAgent? observeSpawn({
    required String parentId,
    required CodexSubAgentSpawnFact fact,
  }) {
    _spawns[_callKey(parentId: parentId, callId: fact.callId)] = fact;
    for (final task in _tasksByChild.values) {
      if (task.parentId == parentId && task.callId == fact.callId) {
        final changed = task.agent != fact.agent || task.prompt == null;
        task
          ..agent = fact.agent
          ..prompt ??= _CodexCorrelatedSpawnPrompt(text: fact.message);
        return changed ? task.snapshotIfReady() : null;
      }
    }
    return null;
  }

  /// Joins one activity to its child and exact spawn call. Repeated activity
  /// frames keep one tile per child.
  CodexTrackedSubAgent? observeStarted({
    required CodexThreadRecord child,
    required String callId,
    PluginToolStatus status = PluginToolStatus.running,
  }) {
    final parentId = child.parentId;
    if (parentId == null || _tasksByChild.containsKey(child.id)) return null;
    final spawn = _spawns[_callKey(parentId: parentId, callId: callId)];
    final task = _CodexTrackedSubAgentState(
      callId: callId,
      parentId: parentId,
      child: child,
      prompt: spawn == null ? null : _CodexCorrelatedSpawnPrompt(text: spawn.message),
      agent: spawn?.agent ?? "codex",
      status: status,
    );
    _tasksByChild[child.id] = task;
    return task.snapshotIfReady();
  }

  /// Binds the first child-owned turn. Later resumed turns cannot become tile
  /// prompt or terminal provenance.
  void observeTurnStarted({required String childId, required String turnId}) {
    final task = _tasksByChild[childId];
    if (task == null || turnId.trim().isEmpty) return;
    task.initialTurnId ??= turnId;
  }

  /// A complete plaintext `NEW_TASK` may replace the spawn fallback once.
  /// Encrypted content remains opaque and changes nothing.
  CodexTrackedSubAgent? observeInitialInput({
    required String childId,
    required CodexSubAgentInitialInputFact fact,
  }) {
    final task = _tasksByChild[childId];
    if (task == null || task.initialTurnId != fact.turnId || task.prompt is _CodexChildPlaintextPrompt) return null;
    final input = fact.input;
    if (input is! CodexSubAgentPlaintextInput) return null;
    final changed = task.prompt?.text != input.message;
    task.prompt = _CodexChildPlaintextPrompt(text: input.message);
    return changed || !task.rendered ? task.snapshotIfReady() : null;
  }

  /// Applies authoritative child terminal lifecycle. First terminal state wins,
  /// so a later `thread/closed` cannot overwrite completed/failed/interrupted.
  CodexTrackedSubAgent? finish({
    required String childId,
    required PluginToolStatus status,
    required String? turnId,
  }) {
    final task = _tasksByChild[childId];
    if (task == null || task.status != PluginToolStatus.running || turnId != null && task.initialTurnId != turnId) {
      return null;
    }
    task.status = status;
    return task.snapshotIfReady();
  }

  /// Cancels every still-open tile, optionally limited to a deleted subtree.
  List<CodexTrackedSubAgent> cancelOpen({Set<String>? sessionIds}) {
    final cancelled = <CodexTrackedSubAgent>[];
    for (final task in _tasksByChild.values) {
      if (task.status != PluginToolStatus.running ||
          (sessionIds != null && !sessionIds.contains(task.parentId) && !sessionIds.contains(task.child.id))) {
        continue;
      }
      task.status = PluginToolStatus.cancelled;
      final snapshot = task.snapshotIfReady();
      if (snapshot != null) cancelled.add(snapshot);
    }
    return cancelled;
  }

  bool hasRenderedTile({required String parentId, required String callId}) {
    for (final task in _tasksByChild.values) {
      if (task.parentId == parentId && task.callId == callId && task.rendered) return true;
    }
    return false;
  }

  /// Children whose direct parent is [parentId].
  List<CodexThreadRecord> childrenOf({required String parentId}) => [
    for (final child in _children.values)
      if (child.parentId == parentId) child,
  ];

  /// Every known descendant below [parentId], parent before child.
  List<CodexThreadRecord> descendantsOf({required String parentId}) {
    final descendants = <CodexThreadRecord>[];
    final seenIds = <String>{parentId};
    var parents = <String>{parentId};
    while (parents.isNotEmpty) {
      final nextParents = <String>{};
      for (final child in _children.values) {
        if (parents.contains(child.parentId) && seenIds.add(child.id)) {
          descendants.add(child);
          nextParents.add(child.id);
        }
      }
      parents = nextParents;
    }
    return descendants;
  }

  void setChildActive({required String childId, required bool active}) {
    if (!_rootByChild.containsKey(childId)) return;
    if (active) {
      _activeChildren.add(childId);
    } else {
      _activeChildren.remove(childId);
    }
  }

  List<String> busyChildIds({required String rootId}) => [
    for (final childId in _childrenByRoot[rootId] ?? const <String>{})
      if (_activeChildren.contains(childId)) childId,
  ];

  Set<String> get deferredRootIds => Set.unmodifiable(_rootsAwaitingIdle);

  void deferRootIdle({required String rootId}) => _rootsAwaitingIdle.add(rootId);

  void cancelDeferredRootIdle({required String rootId}) => _rootsAwaitingIdle.remove(rootId);

  String? releaseRootIdleIfSettled({required String childId}) {
    final root = _rootByChild[childId];
    if (root == null || !_rootsAwaitingIdle.contains(root) || busyChildIds(rootId: root).isNotEmpty) return null;
    _rootsAwaitingIdle.remove(root);
    return root;
  }

  void forget({required String sessionId}) {
    final forgottenIds = {
      sessionId,
      for (final child in descendantsOf(parentId: sessionId)) child.id,
    };
    for (final forgottenId in forgottenIds) {
      _children.remove(forgottenId);
      _rootByChild.remove(forgottenId);
      _activeChildren.remove(forgottenId);
      _rootsAwaitingIdle.remove(forgottenId);
      _tasksByChild.remove(forgottenId);
    }
    _tasksByChild.removeWhere((_, task) => forgottenIds.contains(task.parentId));
    _spawns.removeWhere((key, _) => forgottenIds.any((id) => key.startsWith("$id\u0000")));
    for (final children in _childrenByRoot.values) {
      children.removeAll(forgottenIds);
    }
    _childrenByRoot.removeWhere((rootId, children) => forgottenIds.contains(rootId) || children.isEmpty);
  }

  void clear() {
    _children.clear();
    _rootByChild.clear();
    _childrenByRoot.clear();
    _activeChildren.clear();
    _spawns.clear();
    _tasksByChild.clear();
    _rootsAwaitingIdle.clear();
  }

  String _callKey({required String parentId, required String callId}) => "$parentId\u0000$callId";
}

sealed class const _CodexSubAgentPrompt({required final String text});

final class const _CodexCorrelatedSpawnPrompt({required super.text}) extends _CodexSubAgentPrompt;

final class const _CodexChildPlaintextPrompt({required super.text}) extends _CodexSubAgentPrompt;

final class _CodexTrackedSubAgentState({
  required final String callId,
  required final String parentId,
  required var CodexThreadRecord child,
  required var _CodexSubAgentPrompt? prompt,
  required var String agent,
  required var PluginToolStatus status,
}) {
  String? initialTurnId;
  bool rendered = false;

  CodexTrackedSubAgent? snapshotIfReady() {
    final value = prompt?.text;
    if (value == null) return null;
    rendered = true;
    return CodexTrackedSubAgent(
      callId: callId,
      child: child,
      prompt: value,
      agent: agent,
      status: status,
    );
  }
}
