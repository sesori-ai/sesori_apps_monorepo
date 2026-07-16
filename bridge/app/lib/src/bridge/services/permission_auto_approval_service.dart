import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show PendingPermission, PermissionReply;

import "../repositories/permission_repository.dart";
import "../repositories/session_repository.dart";

class PermissionAutoApprovalService {
  final SessionRepository _sessionRepository;
  final PermissionRepository _permissionRepository;
  final Set<({String requestId, String sessionId})> _approvedPermissions = {};

  bool _disposed = false;

  PermissionAutoApprovalService({
    required SessionRepository sessionRepository,
    required PermissionRepository permissionRepository,
  }) : _sessionRepository = sessionRepository,
       _permissionRepository = permissionRepository;

  bool consumeReply({required String requestId, required String sessionId}) {
    return _approvedPermissions.remove((requestId: requestId, sessionId: sessionId));
  }

  Future<void> approve({required String requestId, required String sessionId}) async {
    if (_disposed) return;
    final key = (requestId: requestId, sessionId: sessionId);
    if (!_approvedPermissions.add(key)) return;

    Log.i("[permissions] auto-approving request $requestId");
    try {
      await _permissionRepository.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: PermissionReply.once,
      );
    } on Object {
      _approvedPermissions.remove(key);
      rethrow;
    }
  }

  Future<void> approvePending() async {
    if (_disposed) return;

    List<String> rootSessionIds;
    try {
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

  void dispose() {
    _disposed = true;
    _approvedPermissions.clear();
  }
}
