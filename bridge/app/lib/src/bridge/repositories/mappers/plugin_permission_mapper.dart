import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginPendingPermissionMapping on PluginPendingPermission {
  /// Maps to the shared [PendingPermission] wire model for the mobile client.
  PendingPermission toSharedPendingPermission({
    required String sessionId,
    required String? displaySessionId,
  }) => PendingPermission(
    id: id,
    sessionID: sessionId,
    displaySessionId: displaySessionId,
    tool: tool,
    description: description,
  );
}
