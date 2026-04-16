import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker_events.dart";
import "push_session_state_tracker_graph.dart";
import "push_session_state_tracker_maintenance.dart";
import "push_session_state_tracker_models.dart";
import "push_session_state_tracker_mutations.dart";
import "push_session_state_tracker_state.dart";

class PushSessionStateTracker {
  final Map<String, PushTrackedSessionState> _sessions = {};
  final Map<String, PushTrackedMessageRole> _messageRoles = {};
  final Map<String, String> _permissionRequestToSession = {};
  final DateTime Function() _now;

  PushSessionStateTracker() : _now = DateTime.now;

  PushSessionStateTracker.testable({required DateTime Function() now}) : _now = now;

  void handleEvent(SesoriSseEvent event) {
    handleTrackedEvent(
      event: event,
      now: _now(),
      sessions: _sessions,
      messageRoles: _messageRoles,
      permissionRequestToSession: _permissionRequestToSession,
    );
  }

  bool isSessionGroupFullyIdle(String sessionId) {
    return collectTrackedSubtreeStates(
      rootSessionId: sessionId,
      sessions: _sessions,
    ).every((sessionState) => sessionState.status == null);
  }

  bool hasPendingInteraction(String sessionId) {
    return collectTrackedSubtreeStates(
      rootSessionId: sessionId,
      sessions: _sessions,
    ).any((sessionState) => sessionState.hasPendingQuestion || sessionState.hasPendingPermission);
  }

  bool wasPreviouslyBusy(String sessionId) {
    return collectTrackedSubtreeStates(
      rootSessionId: sessionId,
      sessions: _sessions,
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
    return resolveTrackedRootIdleSince(rootSessionId: rootSessionId, sessions: _sessions);
  }

  List<String> findPrunableRootSessionIds() {
    return findPrunableRoots().map((root) => root.rootSessionId).toList(growable: false);
  }

  List<PushPrunableRoot> findPrunableRoots() {
    return findTrackedPrunableRoots(sessions: _sessions, now: _now());
  }

  PushPrunedSubtree pruneRootSubtree({required String rootSessionId}) {
    final subtreeSessionIds = collectTrackedSubtreeSessionIds(
      rootSessionId: rootSessionId,
      sessions: _sessions,
    );
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
    final subtreeSessionIds = collectTrackedSubtreeSessionIds(
      rootSessionId: rootSessionId,
      sessions: _sessions,
    );
    for (final sessionId in subtreeSessionIds) {
      _sessions[sessionId]?.latestAssistantText = null;
    }
  }

  void pruneMessageRoleMetadata() {
    final now = _now();
    final cutoff = now.subtract(PushSessionMaintenancePolicy.messageRoleTtl);
    final expiredMessageIds = _messageRoles.entries
        .where((entry) => entry.value.updatedAt.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final messageId in expiredMessageIds) {
      untrackMessage(messageId: messageId, sessions: _sessions, messageRoles: _messageRoles);
    }

    if (_messageRoles.length <= PushSessionMaintenancePolicy.messageRoleHardCap) {
      return;
    }

    final staleEntries = _messageRoles.entries.toList()
      ..sort((left, right) => left.value.updatedAt.compareTo(right.value.updatedAt));
    final overflow = _messageRoles.length - PushSessionMaintenancePolicy.messageRoleHardCap;
    for (final entry in staleEntries.take(overflow)) {
      untrackMessage(messageId: entry.key, sessions: _sessions, messageRoles: _messageRoles);
    }
  }

  PushSessionTelemetrySnapshot createTelemetrySnapshot() {
    return buildTrackedTelemetrySnapshot(
      sessions: _sessions,
      messageRoles: _messageRoles,
      permissionRequestCount: _permissionRequestToSession.length,
      now: _now(),
    );
  }

  String resolveRootSessionId(String sessionId) {
    return resolveTrackedRootSessionId(sessionId: sessionId, sessions: _sessions);
  }

  void reset() {
    _sessions.clear();
    _messageRoles.clear();
    _permissionRequestToSession.clear();
  }
}
