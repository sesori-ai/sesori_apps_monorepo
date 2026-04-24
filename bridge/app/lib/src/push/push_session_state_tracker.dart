import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker_types.dart";

class PushSessionStateTracker {
  final Map<String, _PushTrackedSessionState> _sessions = {};
  final Map<String, _PushTrackedMessageRole> _messageRoles = {};
  final Map<String, String> _permissionRequestToSession = {};
  final DateTime Function() _now;

  PushSessionStateTracker({required DateTime Function() now}) : _now = now;

  void handleEvent(SesoriSseEvent event) {
    final now = _now();
    switch (event) {
      case SesoriSessionCreated(:final info):
        _upsertSession(session: info, touchedAt: now);
      case SesoriSessionUpdated(:final info):
        _upsertSession(session: info, touchedAt: now);
      case SesoriSessionDeleted(:final info):
        _deleteSession(sessionId: info.id);
      case SesoriSessionStatus(:final sessionID, :final status):
        final sessionState = _stateForSession(sessionId: sessionID, touchedAt: now);
        switch (status) {
          case SessionStatusIdle():
            sessionState.status = null;
          case SessionStatusBusy():
          case SessionStatusRetry():
            sessionState.status = status;
            sessionState.previouslyBusy = true;
        }
      case SesoriMessageUpdated(:final info):
        _messageRoles[info.id] = _PushTrackedMessageRole(
          role: info is MessageAssistant ? "assistant" : info is MessageUser ? "user" : "error",
          sessionId: info.sessionID,
          updatedAt: now,
        );
        _trackMessageForSession(
          sessionId: info.sessionID,
          messageId: info.id,
          touchedAt: now,
        );
        _stateForSession(sessionId: info.sessionID, touchedAt: now);
      case SesoriMessageRemoved(:final messageID):
        final sessionId = _untrackMessage(messageId: messageID);
        if (sessionId != null) {
          _stateForSession(sessionId: sessionId, touchedAt: now);
        }
      case SesoriMessagePartUpdated(:final part):
        final messageRole = _messageRoles[part.messageID];
        if (messageRole != null) {
          _messageRoles[part.messageID] = _PushTrackedMessageRole(
            role: messageRole.role,
            sessionId: messageRole.sessionId,
            updatedAt: now,
          );
        }
        _stateForSession(sessionId: part.sessionID, touchedAt: now);
        _updateLatestAssistantText(part: part);
      case SesoriQuestionAsked(:final sessionID):
        _stateForSession(sessionId: sessionID, touchedAt: now).hasPendingQuestion = true;
      case SesoriQuestionReplied(:final sessionID):
        _clearPendingQuestion(sessionId: sessionID, touchedAt: now);
      case SesoriQuestionRejected(:final sessionID):
        _clearPendingQuestion(sessionId: sessionID, touchedAt: now);
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _stateForSession(sessionId: sessionID, touchedAt: now).hasPendingPermission = true;
      case SesoriPermissionReplied(:final requestID):
        _clearPendingPermission(requestId: requestID, touchedAt: now);
      case SesoriProjectsSummary(:final projects):
        _applyProjectsSummaryChildLinks(projects: projects, touchedAt: now);
      default:
        break;
    }
  }

  bool isSessionGroupFullyIdle(String sessionId) {
    return _collectSubtreeStates(
      rootSessionId: sessionId,
    ).every((sessionState) => sessionState.status == null);
  }

  bool hasPendingInteraction(String sessionId) {
    return _collectSubtreeStates(rootSessionId: sessionId).any(
      (sessionState) => sessionState.hasPendingQuestion || sessionState.hasPendingPermission,
    );
  }

  bool wasPreviouslyBusy(String sessionId) {
    return _collectSubtreeStates(
      rootSessionId: sessionId,
    ).any((sessionState) => sessionState.previouslyBusy);
  }

  String? getSessionTitle(String sessionId) {
    return _sessions[sessionId]?.title;
  }

  String? getSessionProjectId({required String sessionId}) {
    return _sessions[sessionId]?.projectId;
  }

  String? getLatestAssistantText(String sessionId) {
    return _sessions[sessionId]?.latestAssistantText;
  }

  DateTime? getRootIdleSince({required String rootSessionId}) {
    return _resolveRootIdleSince(rootSessionId: rootSessionId);
  }

  List<String> findPrunableRootSessionIds() {
    return findPrunableRoots().map((root) => root.rootSessionId).toList(growable: false);
  }

  List<PushPrunableRoot> findPrunableRoots() {
    return _findPrunableRoots();
  }

  List<PushPrunableRoot> _findPrunableRoots() {
    final cutoff = _now().subtract(PushSessionMaintenancePolicy.rootIdlePruneTtl);
    final prunableRoots = <PushPrunableRoot>[];

    for (final rootSessionId in _findRootSessionIds()) {
      final idleSince = _resolveRootIdleSince(rootSessionId: rootSessionId);
      if (idleSince == null || idleSince.isAfter(cutoff)) {
        continue;
      }

      prunableRoots.add(
        PushPrunableRoot(
          rootSessionId: rootSessionId,
          idleSince: idleSince,
          retainedSessionCount: _collectSubtreeSessionIds(
            rootSessionId: rootSessionId,
          ).length,
        ),
      );
    }
    return prunableRoots;
  }

  PushPrunedSubtree pruneRootSubtree({required String rootSessionId}) {
    final subtreeSessionIds = _collectSubtreeSessionIds(rootSessionId: rootSessionId);
    final subtreeMessageIds = subtreeSessionIds
        .expand((sessionId) => _sessions[sessionId]?.messageIds ?? const <String>{})
        .toList(growable: false);
    if (subtreeSessionIds.isEmpty) {
      return PushPrunedSubtree(
        rootSessionId: rootSessionId,
        prunedSessionIds: const <String>[],
        removedSessionCount: 0,
        removedMessageRoleCount: 0,
        removedPermissionMappingCount: 0,
      );
    }

    final rootParentId = _sessions[rootSessionId]?.parentId;
    _sessions[rootParentId]?.childIds.remove(rootSessionId);
    subtreeSessionIds.forEach(_sessions.remove);

    for (final sessionState in _sessions.values) {
      sessionState.childIds.removeWhere(subtreeSessionIds.contains);
    }

    var removedMessageRoleCount = 0;
    for (final messageId in subtreeMessageIds) {
      if (_messageRoles.remove(messageId) != null) {
        removedMessageRoleCount += 1;
      }
    }

    var removedPermissionMappingCount = 0;
    _permissionRequestToSession.removeWhere((_, value) {
      final shouldRemove = subtreeSessionIds.contains(value);
      if (shouldRemove) {
        removedPermissionMappingCount += 1;
      }
      return shouldRemove;
    });

    return PushPrunedSubtree(
      rootSessionId: rootSessionId,
      prunedSessionIds: subtreeSessionIds.toList(growable: false),
      removedSessionCount: subtreeSessionIds.length,
      removedMessageRoleCount: removedMessageRoleCount,
      removedPermissionMappingCount: removedPermissionMappingCount,
    );
  }

  void clearLatestAssistantTextForRootSubtree({required String rootSessionId}) {
    for (final sessionId in _collectSubtreeSessionIds(rootSessionId: rootSessionId)) {
      _sessions[sessionId]?.latestAssistantText = null;
    }
  }

  void pruneMessageRoleMetadata() {
    final cutoff = _now().subtract(PushSessionMaintenancePolicy.messageRoleTtl);
    final expiredMessageIds = _messageRoles.entries
        .where((entry) => entry.value.updatedAt.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final messageId in expiredMessageIds) {
      _untrackMessage(messageId: messageId);
    }

    if (_messageRoles.length <= PushSessionMaintenancePolicy.messageRoleHardCap) {
      return;
    }

    final staleEntries = _messageRoles.entries.toList()
      ..sort((left, right) => left.value.updatedAt.compareTo(right.value.updatedAt));
    final overflow = _messageRoles.length - PushSessionMaintenancePolicy.messageRoleHardCap;
    for (final entry in staleEntries.take(overflow)) {
      _untrackMessage(messageId: entry.key);
    }
  }

  PushSessionTelemetrySnapshot createTelemetrySnapshot() {
    final rootSessionIds = _findRootSessionIds();
    var idleRootCount = 0;
    for (final rootSessionId in rootSessionIds) {
      if (_resolveRootIdleSince(rootSessionId: rootSessionId) != null) {
        idleRootCount += 1;
      }
    }

    var busySessionCount = 0;
    var pendingQuestionCount = 0;
    var pendingPermissionCount = 0;
    var previouslyBusyCount = 0;
    var latestAssistantTextCount = 0;
    var latestAssistantTextCharCount = 0;
    DateTime? oldestSessionActivityAt;
    for (final sessionState in _sessions.values) {
      if (sessionState.status != null) {
        busySessionCount += 1;
      }
      if (sessionState.hasPendingQuestion) {
        pendingQuestionCount += 1;
      }
      if (sessionState.hasPendingPermission) {
        pendingPermissionCount += 1;
      }
      if (sessionState.previouslyBusy) {
        previouslyBusyCount += 1;
      }
      final latestAssistantText = sessionState.latestAssistantText;
      if (latestAssistantText != null) {
        latestAssistantTextCount += 1;
        latestAssistantTextCharCount += latestAssistantText.length;
      }
      final touchedAt = sessionState.lastTouchedAt;
      if (touchedAt != null && (oldestSessionActivityAt == null || touchedAt.isBefore(oldestSessionActivityAt))) {
        oldestSessionActivityAt = touchedAt;
      }
    }

    DateTime? oldestMessageRoleUpdatedAt;
    for (final messageRole in _messageRoles.values) {
      if (oldestMessageRoleUpdatedAt == null || messageRole.updatedAt.isBefore(oldestMessageRoleUpdatedAt)) {
        oldestMessageRoleUpdatedAt = messageRole.updatedAt;
      }
    }

    return PushSessionTelemetrySnapshot(
      sessionCount: _sessions.length,
      rootSessionCount: rootSessionIds.length,
      idleRootCount: idleRootCount,
      busySessionCount: busySessionCount,
      pendingQuestionCount: pendingQuestionCount,
      pendingPermissionCount: pendingPermissionCount,
      permissionRequestCount: _permissionRequestToSession.length,
      previouslyBusyCount: previouslyBusyCount,
      latestAssistantTextCount: latestAssistantTextCount,
      latestAssistantTextCharCount: latestAssistantTextCharCount,
      messageRoleCount: _messageRoles.length,
      assistantMessageRoleCount: _messageRoles.values.where((messageRole) => messageRole.role == "assistant").length,
      oldestSessionActivityAt: oldestSessionActivityAt,
      oldestMessageRoleUpdatedAt: oldestMessageRoleUpdatedAt,
      prunableRoots: _findPrunableRoots(),
    );
  }

  String resolveRootSessionId(String sessionId) {
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

  void reset() {
    _sessions.clear();
    _messageRoles.clear();
    _permissionRequestToSession.clear();
  }

  void _applyProjectsSummaryChildLinks({
    required List<ProjectActivitySummary> projects,
    required DateTime touchedAt,
  }) {
    for (final project in projects) {
      for (final activeSession in project.activeSessions) {
        _summaryStateForSession(sessionId: activeSession.id, seededAt: touchedAt).projectId = project.id;
        for (final childId in activeSession.childSessionIds) {
          final childState = _summaryStateForSession(sessionId: childId, seededAt: touchedAt);
          childState.projectId = project.id;
          if (childState.parentId == null) {
            childState.parentId = activeSession.id;
            _summaryStateForSession(sessionId: activeSession.id, seededAt: touchedAt).childIds.add(childId);
          }
        }
      }
    }
  }

  Set<String> _collectSubtreeSessionIds({required String rootSessionId}) {
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

  Iterable<_PushTrackedSessionState> _collectSubtreeStates({required String rootSessionId}) {
    return _collectSubtreeSessionIds(
      rootSessionId: rootSessionId,
    ).map((sessionId) => _sessions[sessionId]).nonNulls;
  }

  void _clearPendingPermission({required String requestId, required DateTime touchedAt}) {
    final sessionId = _permissionRequestToSession.remove(requestId);
    if (sessionId == null) {
      return;
    }

    final sessionState = _sessions[sessionId];
    if (sessionState != null) {
      sessionState.hasPendingPermission = false;
      sessionState.lastTouchedAt = touchedAt;
    }
  }

  void _clearPendingQuestion({required String sessionId, required DateTime touchedAt}) {
    final sessionState = _sessions[sessionId];
    if (sessionState != null) {
      sessionState.hasPendingQuestion = false;
      sessionState.lastTouchedAt = touchedAt;
    }
  }

  void _deleteSession({required String sessionId}) {
    final removedSessionState = _sessions.remove(sessionId);
    final orphanedChildIds =
        removedSessionState?.childIds.toList(growable: false) ??
        _sessions.entries
            .where((entry) => entry.value.parentId == sessionId)
            .map((entry) => entry.key)
            .toList(growable: false);

    if (removedSessionState != null) {
      if (removedSessionState.parentId != null) {
        _sessions[removedSessionState.parentId]?.childIds.remove(sessionId);
      }

      removedSessionState.messageIds.forEach(_messageRoles.remove);
    }

    for (final childId in orphanedChildIds) {
      final childState = _sessions[childId];
      if (childState != null && childState.parentId == sessionId) {
        childState.parentId = null;
      }
    }

    _permissionRequestToSession.removeWhere((_, value) => value == sessionId);
  }

  Set<String> _findRootSessionIds() {
    return _sessions.entries
        .where(
          (entry) => entry.value.parentId == null || !_sessions.containsKey(entry.value.parentId),
        )
        .map((entry) => entry.key)
        .toSet();
  }

  void _rebuildChildLinksForParent({required String parentId}) {
    final parentState = _sessions[parentId];
    if (parentState == null) {
      return;
    }

    parentState.childIds.removeWhere((childId) => _sessions[childId]?.parentId != parentId);
    for (final entry in _sessions.entries) {
      if (entry.value.parentId == parentId) {
        parentState.childIds.add(entry.key);
      }
    }
  }

  DateTime? _resolveRootIdleSince({required String rootSessionId}) {
    final subtreeSessionIds = _collectSubtreeSessionIds(rootSessionId: rootSessionId);
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

  _PushTrackedSessionState _stateForSession({required String sessionId, DateTime? touchedAt}) {
    final sessionState = _sessions.putIfAbsent(sessionId, _PushTrackedSessionState.new);
    if (touchedAt != null) {
      sessionState.lastTouchedAt = touchedAt;
    }
    return sessionState;
  }

  _PushTrackedSessionState _summaryStateForSession({required String sessionId, required DateTime seededAt}) {
    final sessionState = _sessions.putIfAbsent(sessionId, _PushTrackedSessionState.new);
    sessionState.lastTouchedAt ??= seededAt;
    return sessionState;
  }

  void _trackMessageForSession({
    required String sessionId,
    required String messageId,
    DateTime? touchedAt,
  }) {
    _stateForSession(sessionId: sessionId, touchedAt: touchedAt).messageIds.add(messageId);
  }

  String? _untrackMessage({required String messageId}) {
    final sessionId = _messageRoles.remove(messageId)?.sessionId;
    if (sessionId != null) {
      _sessions[sessionId]?.messageIds.remove(messageId);
    }
    return sessionId;
  }

  void _updateLatestAssistantText({required MessagePart part}) {
    final messageRole = _messageRoles[part.messageID];
    if (part.type != MessagePartType.text || messageRole == null) {
      return;
    }
    final isAssistant = switch (messageRole.role) {
      "assistant" => true,
      _ => false,
    };
    if (!isAssistant) return;

    _stateForSession(sessionId: part.sessionID).latestAssistantText = part.text ?? "";
  }

  void _upsertSession({required Session session, required DateTime touchedAt}) {
    final sessionState = _stateForSession(sessionId: session.id, touchedAt: touchedAt);
    final prevParentId = sessionState.parentId;
    final nextParentId = session.parentID;

    if (prevParentId != null && prevParentId != nextParentId) {
      _sessions[prevParentId]?.childIds.remove(session.id);
    }

    sessionState.parentId = nextParentId;
    sessionState.title = session.title;
    sessionState.projectId = session.projectID;

    if (nextParentId != null) {
      _sessions[nextParentId]?.childIds.add(session.id);
    }
    _rebuildChildLinksForParent(parentId: session.id);
  }
}

final class _PushTrackedSessionState {
  String? parentId;
  String? projectId;
  String? title;
  SessionStatus? status;
  bool previouslyBusy = false;
  final Set<String> childIds = <String>{};
  final Set<String> messageIds = <String>{};
  String? latestAssistantText;
  bool hasPendingQuestion = false;
  bool hasPendingPermission = false;
  DateTime? lastTouchedAt;
}

final class _PushTrackedMessageRole {
  final String role;
  final String sessionId;
  final DateTime updatedAt;

  const _PushTrackedMessageRole({
    required this.role,
    required this.sessionId,
    required this.updatedAt,
  });
}
