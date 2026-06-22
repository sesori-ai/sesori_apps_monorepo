import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

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

  PermissionRepository({required BridgePluginApi plugin}) : _plugin = plugin;

  /// Pending permissions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async {
    final pluginPermissions = await _plugin.getPendingPermissions(sessionId: sessionId);
    return pluginPermissions.map((p) => p.toSharedPendingPermission()).toList();
  }

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) => _plugin.replyToPermission(
    requestId: requestId,
    sessionId: sessionId,
    reply: _toPluginReply(reply),
  );

  static PluginPermissionReply _toPluginReply(PermissionReply reply) => switch (reply) {
    .once => .once,
    .always => .always,
    .reject => .reject,
  };
}
