import "package:sesori_plugin_interface/sesori_plugin_interface.dart" as plugin_interface;
import "package:sesori_shared/sesori_shared.dart";

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
  final plugin_interface.BridgePlugin _plugin;

  PermissionRepository({required plugin_interface.BridgePlugin plugin}) : _plugin = plugin;

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) => _plugin.replyToPermission(
    requestId: requestId,
    sessionId: sessionId,
    reply: _toPluginReply(reply),
  );

  static plugin_interface.PermissionReply _toPluginReply(PermissionReply reply) {
    switch (reply) {
      case PermissionReply.once:
        return plugin_interface.PermissionReply.once;
      case PermissionReply.always:
        return plugin_interface.PermissionReply.always;
      case PermissionReply.reject:
        return plugin_interface.PermissionReply.reject;
    }
  }
}
