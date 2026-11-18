import "dart:async";
import "dart:convert";
import "dart:math";

import "package:sesori_shared/sesori_shared.dart" show PendingPermission, PermissionReply;

import "mappers/agent_approval_mapper.dart";
import "models/agent_approval.dart";
import "models/scheduled_task_agent_change.dart";

/// The in-memory approvals agents are waiting on, at most one per session.
///
/// Nothing is persisted: a bridge restart drops every approval. Request ids
/// are random, so a stale request a phone still shows after a restart can
/// never answer a newer one.
class AgentApprovalRepository({required final Random _random}) {
  static const int _idBytes = 16;

  /// Pending approvals by the session that asked.
  final Map<String, AgentApproval> _bySession = {};
  final StreamController<AgentApprovalEvent> _events = StreamController.broadcast();

  /// Every request asked and settled, already in the shared permission shape.
  Stream<AgentApprovalEvent> get events => _events.stream;

  /// Asks for [change] on [sessionId], withdrawing the session's previous
  /// request. Returns whether there was one.
  bool add({
    required String sessionId,
    required String? displaySessionId,
    required ScheduledTaskAgentChange change,
    required String description,
  }) {
    final previous = _bySession.remove(sessionId);
    if (previous != null) _settled(approval: previous, reply: PermissionReply.reject);
    final approval = AgentApproval(
      requestId: "sesori-approval-${base64Url.encode(List.generate(_idBytes, (_) => _random.nextInt(256)))}",
      sessionId: sessionId,
      displaySessionId: displaySessionId,
      change: change,
      description: description,
    );
    _bySession[sessionId] = approval;
    _emit(AgentApprovalAsked(permission: approval.toPendingPermission()));
    return previous != null;
  }

  /// Removes and returns the approval [requestId] names, announcing [reply];
  /// null when no pending approval has that id.
  AgentApproval? take({required String requestId, required PermissionReply reply}) {
    final approval = _bySession.values.where((approval) => approval.requestId == requestId).firstOrNull;
    if (approval == null) return null;
    _bySession.remove(approval.sessionId);
    _settled(approval: approval, reply: reply);
    return approval;
  }

  /// The requests to show on [sessionId]'s screen: its own, and those of
  /// sessions surfaced under it.
  List<PendingPermission> pendingPermissions({required String sessionId}) {
    return [
      for (final approval in _bySession.values)
        if (approval.sessionId == sessionId || approval.displaySessionId == sessionId) approval.toPendingPermission(),
    ];
  }

  /// The root sessions with a pending approval.
  Set<String> get awaitingRootSessionIds => {
    for (final approval in _bySession.values) approval.displaySessionId ?? approval.sessionId,
  };

  Future<void> dispose() => _events.close();

  void _settled({required AgentApproval approval, required PermissionReply reply}) {
    _emit(
      AgentApprovalSettled(
        requestId: approval.requestId,
        sessionId: approval.sessionId,
        displaySessionId: approval.displaySessionId,
        reply: reply,
      ),
    );
  }

  void _emit(AgentApprovalEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
