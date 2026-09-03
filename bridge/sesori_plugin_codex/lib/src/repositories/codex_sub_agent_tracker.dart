import "models/codex_thread_record.dart";

/// Layer-2 tracker of the sub-agent threads learned on this connection and
/// of the root busy accounting they drive.
///
/// codex-cli 0.148.0 never emits `thread/started` for a spawned child; the
/// parent's `subAgentActivity started` item names it, and the session service
/// resolves the child through `thread/read` before recording it here. Each
/// child maps to its direct parent and to the root it rolls up to, so busy
/// children and a root's deferred idle transition span nested spawns.
class CodexSubAgentTracker() {
  final Map<String, CodexThreadRecord> _children = {};
  final Map<String, String> _rootByChild = {};
  final Map<String, Set<String>> _childrenByRoot = {};
  final Set<String> _activeChildren = {};

  /// Roots whose own turn ended while a descendant was still running. Their
  /// idle transition is held until the last busy descendant finishes, so the
  /// idle reaper and safe stops never kill a running child and the completion
  /// push fires once.
  final Set<String> _rootsAwaitingIdle = {};

  bool isChild({required String sessionId}) => _rootByChild.containsKey(sessionId);

  /// The root session a child rolls up to, or `null` for a root.
  String? rootOf({required String sessionId}) => _rootByChild[sessionId];

  /// Records [child] under its direct parent. Returns `false` when the child
  /// was already known, so a repeated activity item is not re-announced.
  bool record({required CodexThreadRecord child}) {
    final parentId = child.parentId;
    if (parentId == null || _children.containsKey(child.id)) return false;
    final root = _rootByChild[parentId] ?? parentId;
    _children[child.id] = child;
    _rootByChild[child.id] = root;
    (_childrenByRoot[root] ??= {}).add(child.id);
    return true;
  }

  /// The children whose direct parent is [parentId].
  List<CodexThreadRecord> childrenOf({required String parentId}) => [
    for (final child in _children.values)
      if (child.parentId == parentId) child,
  ];

  /// Every known descendant below [parentId], in parent-before-child order.
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

  /// Records whether a known child is running its own turn; ignored for a
  /// session that is not a recorded child.
  void setChildActive({required String childId, required bool active}) {
    if (!_rootByChild.containsKey(childId)) return;
    if (active) {
      _activeChildren.add(childId);
    } else {
      _activeChildren.remove(childId);
    }
  }

  /// The descendants of [rootId] still running, across nesting depth.
  List<String> busyChildIds({required String rootId}) => [
    for (final childId in _childrenByRoot[rootId] ?? const <String>{})
      if (_activeChildren.contains(childId)) childId,
  ];

  /// Roots whose idle transition is currently deferred.
  Set<String> get deferredRootIds => Set.unmodifiable(_rootsAwaitingIdle);

  void deferRootIdle({required String rootId}) => _rootsAwaitingIdle.add(rootId);

  /// A root starting a new turn of its own is busy again in its own right.
  void cancelDeferredRootIdle({required String rootId}) => _rootsAwaitingIdle.remove(rootId);

  /// Returns the root of [childId] when its deferred idle transition can now
  /// be released because no descendant is busy anymore; `null` otherwise.
  String? releaseRootIdleIfSettled({required String childId}) {
    final root = _rootByChild[childId];
    if (root == null || !_rootsAwaitingIdle.contains(root) || busyChildIds(rootId: root).isNotEmpty) {
      return null;
    }
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
    }
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
    _rootsAwaitingIdle.clear();
  }
}
