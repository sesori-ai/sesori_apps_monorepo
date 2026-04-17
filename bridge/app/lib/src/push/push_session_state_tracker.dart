import "package:sesori_shared/sesori_shared.dart";

import "push_session_event_reducer.dart";
import "push_session_maintenance_service.dart";
import "push_session_state_graph.dart";
import "push_session_state_mutator.dart";
import "push_session_state_tracker_models.dart";
import "push_session_state_tracker_state.dart";

class PushSessionStateTracker {
  final Map<String, PushTrackedSessionState> _sessions = {};
  final Map<String, PushTrackedMessageRole> _messageRoles = {};
  final Map<String, String> _permissionRequestToSession = {};
  final DateTime Function() _now;
  late final PushSessionStateGraph _graph;
  late final PushSessionStateMutator _mutator;
  late final PushSessionMaintenanceService _maintenance;
  late final PushSessionEventReducer _eventReducer;

  PushSessionStateTracker({required DateTime Function() now}) : _now = now {
    _initializeCollaborators();
  }

  void _initializeCollaborators() {
    _graph = PushSessionStateGraph(sessions: _sessions);
    _mutator = PushSessionStateMutator(
      sessions: _sessions,
      messageRoles: _messageRoles,
      permissionRequestToSession: _permissionRequestToSession,
    );
    _maintenance = PushSessionMaintenanceService(
      sessions: _sessions,
      messageRoles: _messageRoles,
      permissionRequestCount: () => _permissionRequestToSession.length,
      graph: _graph,
      now: _now,
    );
    _eventReducer = PushSessionEventReducer(
      sessions: _sessions,
      messageRoles: _messageRoles,
      permissionRequestToSession: _permissionRequestToSession,
      mutator: _mutator,
    );
  }

  void handleEvent(SesoriSseEvent event) {
    _eventReducer.handleEvent(event: event, now: _now());
  }

  bool isSessionGroupFullyIdle(String sessionId) {
    return _graph.collectSubtreeStates(rootSessionId: sessionId).every((sessionState) => sessionState.status == null);
  }

  bool hasPendingInteraction(String sessionId) {
    return _graph
        .collectSubtreeStates(rootSessionId: sessionId)
        .any((sessionState) => sessionState.hasPendingQuestion || sessionState.hasPendingPermission);
  }

  bool wasPreviouslyBusy(String sessionId) {
    return _graph.collectSubtreeStates(rootSessionId: sessionId).any((sessionState) => sessionState.previouslyBusy);
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
    return _graph.resolveRootIdleSince(rootSessionId: rootSessionId);
  }

  List<String> findPrunableRootSessionIds() {
    return findPrunableRoots().map((root) => root.rootSessionId).toList(growable: false);
  }

  List<PushPrunableRoot> findPrunableRoots() {
    return _maintenance.findPrunableRoots();
  }

  PushPrunedSubtree pruneRootSubtree({required String rootSessionId}) {
    final subtreeSessionIds = _graph.collectSubtreeSessionIds(
      rootSessionId: rootSessionId,
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
    final subtreeSessionIds = _graph.collectSubtreeSessionIds(
      rootSessionId: rootSessionId,
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
      _mutator.untrackMessage(messageId: messageId);
    }

    if (_messageRoles.length <= PushSessionMaintenancePolicy.messageRoleHardCap) {
      return;
    }

    final staleEntries = _messageRoles.entries.toList()
      ..sort((left, right) => left.value.updatedAt.compareTo(right.value.updatedAt));
    final overflow = _messageRoles.length - PushSessionMaintenancePolicy.messageRoleHardCap;
    for (final entry in staleEntries.take(overflow)) {
      _mutator.untrackMessage(messageId: entry.key);
    }
  }

  PushSessionTelemetrySnapshot createTelemetrySnapshot() {
    return _maintenance.buildTelemetrySnapshot();
  }

  String resolveRootSessionId(String sessionId) {
    return _graph.resolveRootSessionId(sessionId: sessionId);
  }

  void reset() {
    _sessions.clear();
    _messageRoles.clear();
    _permissionRequestToSession.clear();
  }
}
