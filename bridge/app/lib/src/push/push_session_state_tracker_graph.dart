import "dart:collection";

import "push_session_state_tracker_state.dart";

Set<String> collectTrackedSubtreeSessionIds({
  required String rootSessionId,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  if (!sessions.containsKey(rootSessionId)) {
    return <String>{};
  }

  final queue = Queue<String>()..add(rootSessionId);
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final currentId = queue.removeFirst();
    if (!visited.add(currentId)) {
      continue;
    }

    final sessionState = sessions[currentId];
    if (sessionState == null) {
      continue;
    }

    for (final childId in sessionState.childIds) {
      if (sessions[childId]?.parentId == currentId) {
        queue.add(childId);
      }
    }
  }

  return visited;
}

Set<String> findTrackedRootSessionIds({required Map<String, PushTrackedSessionState> sessions}) {
  return sessions.entries
      .where((entry) => entry.value.parentId == null || !sessions.containsKey(entry.value.parentId))
      .map((entry) => entry.key)
      .toSet();
}

Iterable<PushTrackedSessionState> collectTrackedSubtreeStates({
  required String rootSessionId,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  return collectTrackedSubtreeSessionIds(
    rootSessionId: rootSessionId,
    sessions: sessions,
  ).map((sessionId) => sessions[sessionId]).nonNulls;
}

DateTime? resolveTrackedRootIdleSince({
  required String rootSessionId,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  final subtreeSessionIds = collectTrackedSubtreeSessionIds(
    rootSessionId: rootSessionId,
    sessions: sessions,
  );
  if (subtreeSessionIds.isEmpty) {
    return null;
  }

  DateTime? latestTouch;
  for (final sessionId in subtreeSessionIds) {
    final sessionState = sessions[sessionId];
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

String resolveTrackedRootSessionId({
  required String sessionId,
  required Map<String, PushTrackedSessionState> sessions,
}) {
  var current = sessionId;
  final visited = <String>{};

  while (true) {
    if (!visited.add(current)) {
      return current;
    }

    final parentId = sessions[current]?.parentId;
    if (parentId == null || !sessions.containsKey(parentId)) {
      return current;
    }

    current = parentId;
  }
}
