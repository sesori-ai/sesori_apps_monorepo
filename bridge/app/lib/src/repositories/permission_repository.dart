import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/session_dao.dart";
import "../api/database/tables/session_table.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/plugin_permission_mapper.dart";
import "models/session_operation.dart";

/// Layer 2 repository wrapping [plugin_interface.BridgePlugin] for permission operations.
///
/// Delegates directly to the plugin — mandatory even though it's a thin
/// wrapper, because [plugin_interface.BridgePlugin] is Layer 1 and handlers
/// must not call it directly.
///
/// Also maps the wire-format [PermissionReply] (from `sesori_shared`) to the
/// plugin-contract [plugin_interface.PermissionReply] to keep the two enums
/// decoupled.
class PermissionRepository({required final PluginRuntime _runtime, required final SessionDao _sessionDao}) {
  /// Pending permissions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingPermissions,
    );
    // Deliberately does not start a stopped backend — see the matching note in
    // QuestionRepository. A stopped backend holds no pending permissions, so
    // waking it to ask could only answer "none".
    final pending = await _runtime.useIfActive(
      pluginId: binding.pluginId,
      operation: SessionOperation.getPendingPermissions,
      body: (plugin, _) async {
        Set<String>? tombstoned;
        if (plugin is BridgeDerivedProjectsPluginApi) {
          tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
          if (tombstoned.contains(binding.backendSessionId)) return const <PendingPermission>[];
        }
        final permissions = await plugin.getPendingPermissions(sessionId: binding.backendSessionId);
        return await _mapPendingPermissions(
          pluginId: plugin.id,
          permissions: [
            for (final permission in permissions)
              if (tombstoned == null || _isVisible(permission, tombstoned)) permission,
          ],
        );
      },
    );
    // Null means the backend is not running, which is indistinguishable from
    // "it has none" for this question.
    return pending ?? const [];
  }

  static bool _isVisible(PluginPendingPermission permission, Set<String> tombstoned) {
    return !tombstoned.contains(permission.sessionID) &&
        (permission.displaySessionId == null || !tombstoned.contains(permission.displaySessionId));
  }

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.replyToPermission,
    );
    return await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.replyToPermission,
      body: (plugin) async {
        if (plugin is BridgeDerivedProjectsPluginApi) {
          final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
          if (tombstoned.contains(binding.backendSessionId)) {
            throw PluginOperationException.notFound(
              SessionOperation.replyToPermission.name,
              message: "session ${binding.backendSessionId} was deleted",
            );
          }
          final pending = await plugin.getPendingPermissions(sessionId: binding.backendSessionId);
          for (final permission in pending) {
            if (permission.id != requestId) continue;
            if (tombstoned.contains(permission.sessionID)) {
              throw PluginOperationException.notFound(
                SessionOperation.replyToPermission.name,
                message: "session ${permission.sessionID} was deleted",
              );
            }
            if (permission.displaySessionId case final displaySessionId? when tombstoned.contains(displaySessionId)) {
              throw PluginOperationException.notFound(
                SessionOperation.replyToPermission.name,
                message: "display session $displaySessionId was deleted",
              );
            }
            break;
          }
        }
        return await plugin.replyToPermission(
          requestId: requestId,
          sessionId: binding.backendSessionId,
          reply: _toPluginReply(reply),
        );
      },
    );
  }

  static PluginPermissionReply _toPluginReply(PermissionReply reply) => switch (reply) {
    .once => .once,
    .always => .always,
    .reject => .reject,
  };

  Future<SessionDto> _requireBinding({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    return binding;
  }

  Future<List<PendingPermission>> _mapPendingPermissions({
    required String pluginId,
    required List<PluginPendingPermission> permissions,
  }) async {
    final backendSessionIds = {
      for (final permission in permissions) ...{
        permission.sessionID,
        ?permission.displaySessionId,
      },
    };
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    return [
      for (final permission in permissions)
        if (bindings[permission.sessionID] case final session?)
          if (permission.displaySessionId == null || bindings.containsKey(permission.displaySessionId))
            permission.toSharedPendingPermission(
              sessionId: session.sessionId,
              displaySessionId: permission.displaySessionId == null
                  ? null
                  : bindings[permission.displaySessionId]!.sessionId,
            ),
    ];
  }
}
