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
    details: details.toShared(),
    allowAlways: allowAlways,
  );
}

extension PluginPermissionAskedMapping on BridgeSsePermissionAsked {
  SesoriSseEvent toSharedPermissionAsked() => SesoriSseEvent.permissionAsked(
    requestID: requestID,
    sessionID: sessionID,
    displaySessionId: displaySessionId,
    tool: tool,
    description: description,
    details: details.toShared(),
    allowAlways: allowAlways,
  );
}

extension PluginPermissionDetailsMapping on PluginPermissionDetails {
  PermissionDetails toShared() => switch (this) {
    PluginGenericPermissionDetails() => const PermissionDetails.generic(),
    PluginCommandPermissionDetails(:final command) => PermissionDetails.command(command: command),
    PluginFileChangesPermissionDetails(:final files) => PermissionDetails.fileChanges(
      files: [
        for (final file in files)
          PermissionFile(
            path: file.path,
            operation: switch (file.operation) {
              PluginPermissionFileOperation.create => PermissionFileOperation.create,
              PluginPermissionFileOperation.write => PermissionFileOperation.write,
              PluginPermissionFileOperation.delete => PermissionFileOperation.delete,
              null => null,
            },
          ),
      ],
    ),
    PluginNetworkPermissionDetails(:final targets, :final command) => PermissionDetails.network(
      targets: targets,
      command: command,
    ),
  };
}
