import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Layer 2 repository wrapping [BridgePlugin] for permission operations.
///
/// Delegates directly to the plugin — mandatory even though it's a thin
/// wrapper, because [BridgePlugin] is Layer 1 and handlers must not call it
/// directly.
class PermissionRepository {
  final BridgePlugin _plugin;

  PermissionRepository({required BridgePlugin plugin}) : _plugin = plugin;

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required String response,
  }) => _plugin.replyToPermission(
    requestId: requestId,
    sessionId: sessionId,
    response: response,
  );
}
