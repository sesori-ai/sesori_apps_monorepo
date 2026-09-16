import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/open_code_permission_metadata_dto.dart";

/// One normalization path for native pending snapshots and permission.asked.
class const PermissionDetailsMapper() {
  PluginPermissionDetails map({required String permission, required Map<String, dynamic>? metadata}) {
    if (metadata == null || !const {"bash", "edit", "webfetch"}.contains(permission)) {
      return const PluginPermissionDetails.generic();
    }
    final value = OpenCodePermissionMetadataDto.fromJson(metadata);
    switch (permission) {
      case "bash":
        final command = value.command;
        if (command != null && command.isNotEmpty) return PluginPermissionDetails.command(command: command);
      case "edit":
        if (value.files.isNotEmpty) {
          return PluginPermissionDetails.fileChanges(
            files: [
              for (final file in value.files)
                PluginPermissionFile(
                  path: file.filePath,
                  operation: switch (file.type) {
                    OpenCodePermissionFileType.add => PluginPermissionFileOperation.create,
                    OpenCodePermissionFileType.update => PluginPermissionFileOperation.write,
                    OpenCodePermissionFileType.delete => PluginPermissionFileOperation.delete,
                    OpenCodePermissionFileType.move || OpenCodePermissionFileType.unknown => null,
                  },
                ),
              for (final file in value.files)
                if (file.movePath case final target? when target.isNotEmpty)
                  PluginPermissionFile(path: target, operation: null),
            ],
          );
        }
        final path = value.filepath;
        if (path != null && path.isNotEmpty) {
          return PluginPermissionDetails.fileChanges(
            files: [
              PluginPermissionFile(path: path, operation: PluginPermissionFileOperation.write),
            ],
          );
        }
      case "webfetch":
        final url = value.url;
        if (url != null && url.isNotEmpty) return PluginPermissionDetails.network(targets: [url], command: null);
    }
    return const PluginPermissionDetails.generic();
  }
}
