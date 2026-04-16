import "dart:collection";

import "push_session_state_tracker_state.dart";

class PushSessionStateGraph {
  final Map<String, PushTrackedSessionState> _sessions;

  PushSessionStateGraph({required Map<String, PushTrackedSessionState> sessions}) : _sessions = sessions;

  Set<String> collectSubtreeSessionIds({required String rootSessionId}) {
    if (!_sessions.containsKey(rootSessionId)) {
      return <String>{};
    }

    final queue = Queue<String>()..add(rootSessionId);
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final currentId = queue.removeFirst();
      if (!visited.add(currentId)) {
        continue;
      }

      final sessionState = _sessions[currentId];
      if (sessionState == null) {
        continue;
      }

      for (final childId in sessionState.childIds) {
        if (_sessions[childId]?.parentId == currentId) {
          queue.add(childId);
        }
      }
    }

    return visited;
  }

  Set<String> findRootSessionIds() {
    return _sessions.entries
        .where((entry) => entry.value.parentId == null || !_sessions.containsKey(entry.value.parentId))
        .map((entry) => entry.key)
        .toSet();
  }

  Iterable<PushTrackedSessionState> collectSubtreeStates({required String rootSessionId}) {
    return collectSubtreeSessionIds(rootSessionId: rootSessionId).map((sessionId) => _sessions[sessionId]).nonNulls;
  }

  DateTime? resolveRootIdleSince({required String rootSessionId}) {
    final subtreeSessionIds = collectSubtreeSessionIds(rootSessionId: rootSessionId);
    if (subtreeSessionIds.isEmpty) {
      return null;
    }

    DateTime? latestTouch;
    for (final sessionId in subtreeSessionIds) {
      final sessionState = _sessions[sessionId];
      if (sessionState == null) {
        continue;
      }
      if (sessionState.status != null || sessionState.hasPendingQuestion || sessionState.hasPendingPermission) {
        return null;
      }

      final touchedAt = sessionState.lastTouchedAt;
      if (touchedAt == null) {
        return null;
      }
      if (latestTouch == null || touchedAt.isAfter(latestTouch)) {
        latestTouch = touchedAt;
      }
    }

    return latestTouch;
  }

  String resolveRootSessionId({required String sessionId}) {
    var current = sessionId;
    final visited = <String>{};

    while (true) {
      if (!visited.add(current)) {
        return current;
      }

      final parentId = _sessions[current]?.parentId;
      if (parentId == null || !_sessions.containsKey(parentId)) {
        return current;
      }

      current = parentId;
    }
  }
}
