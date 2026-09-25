import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show PendingPermission, PermissionReply, SessionApprovalMode;

import "../repositories/bridge_settings_repository.dart";
import "../repositories/permission_repository.dart";
import "../repositories/session_repository.dart";
import "pending_interaction_service.dart";

/// Owns YOLO approval: which sessions are in YOLO, and approving their
/// permission requests once.
class PermissionAutoApprovalService({
  required final SessionRepository _sessionRepository,
  required final PermissionRepository _permissionRepository,
  required final PendingInteractionService _pendingInteractionService,
  required final BridgeSettingsRepository _bridgeSettingsRepository,
}) {
  final Set<({String requestId, String sessionId})> _approvedPermissions = {};

  bool _disposed = false;

  bool consumeReply({required String requestId, required String sessionId}) {
    return _approvedPermissions.remove((requestId: requestId, sessionId: sessionId));
  }

  /// Whether [sessionId]'s permission requests are approved automatically:
  /// the session's own override, or its nearest ancestor's, when one is set;
  /// otherwise the bridge-wide YOLO setting.
  Future<bool> isYolo({required String sessionId}) async {
    return switch (await _sessionRepository.resolveApprovalOverride(sessionId: sessionId)) {
      SessionApprovalMode.yolo => true,
      SessionApprovalMode.ask => false,
      null => _bridgeSettingsRepository.currentSettings.yolo,
    };
  }

  /// Approves the request once when its session is in YOLO; a no-op otherwise.
  Future<void> approve({required String requestId, required String sessionId}) async {
    if (_disposed || !await isYolo(sessionId: sessionId)) return;
    final key = (requestId: requestId, sessionId: sessionId);
    if (!_approvedPermissions.add(key)) return;

    Log.i("[permissions] auto-approving request $requestId");
    try {
      await _pendingInteractionService.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: PermissionReply.once,
      );
    } on Object {
      _approvedPermissions.remove(key);
      rethrow;
    }
  }

  /// Resolves a pending-permission snapshot under YOLO before it is served.
  ///
  /// A permission whose session is not in YOLO passes through untouched. Each
  /// other permission is auto-approved and the ones that could not be approved
  /// are returned, so a request YOLO cannot answer — one asked before YOLO was
  /// enabled while no phone listened, or one whose reply failed — surfaces for
  /// manual action instead of staying invisible behind an "awaiting input"
  /// badge forever.
  Future<List<PendingPermission>> resolveSnapshot({required List<PendingPermission> permissions}) async {
    if (_disposed || permissions.isEmpty || !await _anySessionMayBeYolo()) return permissions;
    final unresolved = <PendingPermission>[];
    for (final permission in permissions) {
      // Check per item: switching YOLO off mid-snapshot makes approve() a
      // no-op, and hiding the untouched remainder would leave it unanswerable.
      if (_disposed || !await isYolo(sessionId: permission.sessionID)) {
        unresolved.add(permission);
        continue;
      }
      try {
        await approve(requestId: permission.id, sessionId: permission.sessionID);
      } on Object catch (error, stackTrace) {
        Log.w(
          "[permissions] failed to auto-approve snapshot request ${permission.id}; leaving it visible",
          error,
          stackTrace,
        );
        unresolved.add(permission);
      }
    }
    return unresolved;
  }

  /// Approves every pending request whose session is in YOLO. Runs when YOLO
  /// is switched on, for the bridge or for one session, and when a backend
  /// reconnects or reports project activity.
  Future<void> approvePending() async {
    if (_disposed) return;

    List<String> rootSessionIds;
    try {
      if (!await _anySessionMayBeYolo()) return;
      rootSessionIds = [
        for (final summary in await _sessionRepository.getProjectActivitySummaries())
          for (final session in summary.activeSessions)
            if (session.awaitingInput) session.id,
      ];
    } on Object catch (error, stackTrace) {
      Log.w("[permissions] failed to discover pending permissions for auto-approval", error, stackTrace);
      return;
    }

    for (final rootSessionId in rootSessionIds.toSet()) {
      if (_disposed) return;
      try {
        await _sessionRepository.getChildSessions(sessionId: rootSessionId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "[permissions] failed to hydrate children for session $rootSessionId",
          error,
          stackTrace,
        );
      }

      if (_disposed) return;
      final List<PendingPermission> permissions;
      try {
        permissions = await _permissionRepository.getPendingPermissions(sessionId: rootSessionId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "[permissions] failed to list pending permissions for session $rootSessionId",
          error,
          stackTrace,
        );
        continue;
      }

      for (final permission in permissions) {
        if (_disposed) return;
        try {
          await approve(
            requestId: permission.id,
            sessionId: permission.sessionID,
          );
        } on Object catch (error, stackTrace) {
          Log.w(
            "[permissions] failed to auto-approve pending request ${permission.id}",
            error,
            stackTrace,
          );
        }
      }
    }
  }

  /// A cheap gate that skips the pending-permission sweep while no session can
  /// be in YOLO.
  Future<bool> _anySessionMayBeYolo() async {
    return _bridgeSettingsRepository.currentSettings.yolo || await _sessionRepository.hasYoloApprovalOverride();
  }

  void dispose() {
    _disposed = true;
    _approvedPermissions.clear();
  }
}
