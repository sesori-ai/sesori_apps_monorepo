import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";

class PushSessionMaintenancePolicy() {
  static const rootIdlePruneTtl = Duration(minutes: 30);
  static const messageRoleTtl = Duration(minutes: 30);
  static const messageRoleHardCap = 10000;
}

class PushSessionStateTracker({required final DateTime Function() _now}) {
  final Map<String, _PushTrackedSessionState> _sessions = {};
  final Map<String, _PushTrackedMessageRole> _messageRoles = {};

  int get sessionCount => _sessions.length;

  int get messageRoleCount => _messageRoles.length;

  void handleEvent({required SesoriSseEvent event}) {
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
          role: switch (info) {
            MessageAssistant(sender: MessageSender.agent) => _PushMessageRole.assistant,
            MessageAssistant() => _PushMessageRole.system,
            MessageUser() => _PushMessageRole.user,
            MessageError() => _PushMessageRole.error,
          },
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
      case SesoriQuestionAsked(:final id, :final sessionID):
        _stateForSession(sessionId: sessionID, touchedAt: now).pendingQuestionIds.add(id);
      case SesoriQuestionReplied(:final requestID, :final sessionID):
        _clearPendingQuestion(sessionId: sessionID, questionId: requestID, touchedAt: now);
      case SesoriQuestionRejected(:final requestID, :final sessionID):
        _clearPendingQuestion(sessionId: sessionID, questionId: requestID, touchedAt: now);
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _stateForSession(sessionId: sessionID, touchedAt: now).pendingPermissionRequestIds.add(requestID);
      case SesoriPermissionReplied(:final requestID, :final sessionID):
        _clearPendingPermission(sessionId: sessionID, requestId: requestID, touchedAt: now);
      case SesoriProjectsSummary(:final projects):
        _applyProjectsSummaryChildLinks(projects: projects, touchedAt: now);
      default:
        break;
    }
  }

  bool isSessionGroupFullyIdle({required String sessionId}) {
    return _collectSubtreeStates(
      rootSessionId: sessionId,
    ).every((sessionState) => sessionState.status == null);
  }

  bool hasPendingInteraction({required String sessionId}) {
    return _collectSubtreeStates(rootSessionId: sessionId).any(
      (sessionState) =>
          sessionState.pendingQuestionIds.isNotEmpty || sessionState.pendingPermissionRequestIds.isNotEmpty,
    );
  }

  bool wasPreviouslyBusy({required String sessionId}) {
    return _collectSubtreeStates(
      rootSessionId: sessionId,
    ).any((sessionState) => sessionState.previouslyBusy);
  }

  String? getSessionProjectId({required String sessionId}) {
    return _sessions[sessionId]?.projectId;
  }

  String? getLatestAssistantText({required String sessionId}) {
    return _sessions[sessionId]?.latestAssistantText;
  }

  /// Root session ids whose whole subtree has been idle for at least
  /// [PushSessionMaintenancePolicy.rootIdlePruneTtl].
  List<String> findPrunableRoots() {
    final cutoff = _now().subtract(PushSessionMaintenancePolicy.rootIdlePruneTtl);
    return _findRootSessionIds()
        .where((rootSessionId) {
          final idleSince = _resolveRootIdleSince(rootSessionId: rootSessionId);
          return idleSince != null && !idleSince.isAfter(cutoff);
        })
        .toList(growable: false);
  }

  /// Forgets the subtree under [rootSessionId] and returns its session ids.
  List<String> pruneRootSubtree({required String rootSessionId}) {
    final subtreeSessionIds = _collectSubtreeSessionIds(rootSessionId: rootSessionId);
    if (subtreeSessionIds.isEmpty) {
      return const <String>[];
    }
    final subtreeMessageIds = subtreeSessionIds
        .expand((sessionId) => _sessions[sessionId]?.messageIds ?? const <String>{})
        .toList(growable: false);

    final rootParentId = _sessions[rootSessionId]?.parentId;
    _sessions[rootParentId]?.childIds.remove(rootSessionId);
    subtreeSessionIds.forEach(_sessions.remove);

    for (final sessionState in _sessions.values) {
      sessionState.childIds.removeWhere(subtreeSessionIds.contains);
    }

    subtreeMessageIds.forEach(_messageRoles.remove);

    return subtreeSessionIds.toList(growable: false);
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

  void _clearPendingPermission({
    required String sessionId,
    required String requestId,
    required DateTime touchedAt,
  }) {
    final sessionState = _sessions[sessionId];
    if (sessionState != null) {
      sessionState.pendingPermissionRequestIds.remove(requestId);
      sessionState.lastTouchedAt = touchedAt;
    }
  }

  void _clearPendingQuestion({
    required String sessionId,
    required String questionId,
    required DateTime touchedAt,
  }) {
    final sessionState = _sessions[sessionId];
    if (sessionState != null) {
      sessionState.pendingQuestionIds.remove(questionId);
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
      if (sessionState.status != null ||
          sessionState.pendingQuestionIds.isNotEmpty ||
          sessionState.pendingPermissionRequestIds.isNotEmpty) {
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
    if (part is! MessagePartText || messageRole == null) {
      return;
    }
    if (messageRole.role != _PushMessageRole.assistant) return;

    _stateForSession(sessionId: part.sessionID).latestAssistantText = part.text;
  }

  void _upsertSession({required Session session, required DateTime touchedAt}) {
    final sessionState = _stateForSession(sessionId: session.id, touchedAt: touchedAt);
    final prevParentId = sessionState.parentId;
    final nextParentId = session.parentID;

    if (prevParentId != null && prevParentId != nextParentId) {
      _sessions[prevParentId]?.childIds.remove(session.id);
    }

    sessionState.parentId = nextParentId;
    sessionState.projectId = session.projectID;

    if (nextParentId != null) {
      _sessions[nextParentId]?.childIds.add(session.id);
    }
    _rebuildChildLinksForParent(parentId: session.id);
  }
}

final class _PushTrackedSessionState() {
  String? parentId;
  String? projectId;
  SessionStatus? status;
  bool previouslyBusy = false;
  final Set<String> childIds = <String>{};
  final Set<String> messageIds = <String>{};
  String? latestAssistantText;
  final Set<String> pendingQuestionIds = <String>{};
  final Set<String> pendingPermissionRequestIds = <String>{};
  DateTime? lastTouchedAt;
}

enum _PushMessageRole() { user, assistant, system, error }

final class const _PushTrackedMessageRole({
  required final _PushMessageRole role,
  required final String sessionId,
  required final DateTime updatedAt,
});
