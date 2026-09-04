/// Owns the correlation between DeepSeek's standard ACP delegation tool calls
/// and its extension lifecycle notifications. A correlation survives parent
/// turn boundaries and is released only after both the child lifecycle and the
/// standard tool call are terminal, or when its session is forgotten.
final class DeepSeekDelegationTracker() {
  final Map<String, Map<String, _Delegation>> _byParent = {};
  final Map<String, _Delegation> _byChild = {};

  bool isStarted({required String parentSessionId, required String toolCallId}) =>
      _byParent[parentSessionId]?.containsKey(toolCallId) ?? false;

  String? sessionIdForToolCallId({required String toolCallId}) {
    for (final entry in _byParent.entries) {
      if (entry.value.containsKey(toolCallId)) return entry.key;
    }
    return null;
  }

  void start({
    required String parentSessionId,
    required String toolCallId,
    required String childSessionId,
  }) {
    final existing = _byParent[parentSessionId]?[toolCallId];
    if (existing != null && existing.childSessionId == childSessionId) return;
    if (existing != null) _remove(existing);
    final priorChildDelegation = _byChild[childSessionId];
    if (priorChildDelegation != null) _remove(priorChildDelegation);
    final delegation = _Delegation(
      parentSessionId: parentSessionId,
      toolCallId: toolCallId,
      childSessionId: childSessionId,
    );
    (_byParent[parentSessionId] ??= {})[toolCallId] = delegation;
    _byChild[childSessionId] = delegation;
  }

  void markToolTerminal({required String parentSessionId, required String toolCallId}) {
    final delegation = _byParent[parentSessionId]?[toolCallId];
    if (delegation == null) return;
    delegation.toolTerminalSeen = true;
    _removeIfSettled(delegation);
  }

  void markChildEnded({required String childSessionId}) {
    final delegation = _byChild[childSessionId];
    if (delegation == null) return;
    delegation.childEnded = true;
    _removeIfSettled(delegation);
  }

  void forgetSession({required String sessionId}) {
    final childDelegation = _byChild[sessionId];
    if (childDelegation != null) _remove(childDelegation);
    final parentDelegations = _byParent.remove(sessionId);
    if (parentDelegations == null) return;
    for (final delegation in parentDelegations.values) {
      _byChild.remove(delegation.childSessionId);
    }
  }

  void clear() {
    _byParent.clear();
    _byChild.clear();
  }

  void _removeIfSettled(_Delegation delegation) {
    if (delegation.childEnded && delegation.toolTerminalSeen) _remove(delegation);
  }

  void _remove(_Delegation delegation) {
    final byToolCall = _byParent[delegation.parentSessionId];
    if (identical(byToolCall?[delegation.toolCallId], delegation)) {
      byToolCall?.remove(delegation.toolCallId);
      if (byToolCall?.isEmpty ?? false) _byParent.remove(delegation.parentSessionId);
    }
    if (identical(_byChild[delegation.childSessionId], delegation)) {
      _byChild.remove(delegation.childSessionId);
    }
  }
}

final class _Delegation({
  required final String parentSessionId,
  required final String toolCallId,
  required final String childSessionId,
}) {
  bool childEnded = false;
  bool toolTerminalSeen = false;
}
