import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "mappers/plugin_permission_mapper.dart";

/// Layer 2 repository wrapping [plugin_interface.BridgePlugin] for permission operations.
///
/// Delegates directly to the plugin — mandatory even though it's a thin
/// wrapper, because [plugin_interface.BridgePlugin] is Layer 1 and handlers
/// must not call it directly.
///
/// Also maps the wire-format [PermissionReply] (from `sesori_shared`) to the
/// plugin-contract [plugin_interface.PermissionReply] to keep the two enums
/// decoupled.
class PermissionRepository {
  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;

  PermissionRepository({required BridgePluginApi plugin, required SessionDao sessionDao})
    : _plugin = plugin,
      _sessionDao = sessionDao;

  /// Pending permissions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async {
    Set<String>? tombstoned;
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
      tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
      if (tombstoned.contains(sessionId)) return const [];
    }
    final pluginPermissions = await _plugin.getPendingPermissions(sessionId: sessionId);
    return [
      for (final permission in pluginPermissions)
        if (tombstoned == null || _isVisible(permission, tombstoned)) permission.toSharedPendingPermission(),
    ];
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
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
      if (await _sessionDao.isSessionTombstoned(sessionId: sessionId, pluginId: plugin.id)) {
        throw PluginOperationException.notFound(
          "replyToPermission",
          message: "session $sessionId was deleted",
        );
      }
    }
    return _plugin.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: _toPluginReply(reply),
    );
  }

  static PluginPermissionReply _toPluginReply(PermissionReply reply) => switch (reply) {
    .once => .once,
    .always => .always,
    .reject => .reject,
  };
}
