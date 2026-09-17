import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/acp_permission_details_dto.dart";

class const AcpPermissionDetailsMapper() {
  PluginPermissionDetails map({required Map<String, dynamic> toolCall, required String? command}) {
    if (command != null && command.isNotEmpty) return PluginPermissionDetails.command(command: command);
    final AcpPermissionDetailsDto value;
    try {
      value = AcpPermissionDetailsDto.fromJson(toolCall);
    } on Object catch (error, stackTrace) {
      Log.w("[acp] cannot decode optional permission details for ${toolCall["toolCallId"]}", error, stackTrace);
      return const PluginPermissionDetails.generic();
    }
    final diffs = value.content.whereType<AcpPermissionDiffDto>();
    final files = <PluginPermissionFile>[
      for (final diff in diffs)
        PluginPermissionFile(
          path: diff.path,
          operation: switch (value.kind) {
            AcpPermissionToolKind.delete => PluginPermissionFileOperation.delete,
            AcpPermissionToolKind.move => null,
            _ => diff.oldText == null ? PluginPermissionFileOperation.create : PluginPermissionFileOperation.write,
          },
        ),
      if (value.kind == AcpPermissionToolKind.edit ||
          value.kind == AcpPermissionToolKind.delete ||
          value.kind == AcpPermissionToolKind.move)
        for (final location in value.locations)
          if (!diffs.any((diff) => diff.path == location.path))
            PluginPermissionFile(
              path: location.path,
              operation: switch (value.kind) {
                AcpPermissionToolKind.delete => PluginPermissionFileOperation.delete,
                AcpPermissionToolKind.edit => PluginPermissionFileOperation.write,
                _ => null,
              },
            ),
    ];
    if (files.isNotEmpty) return PluginPermissionDetails.fileChanges(files: files);
    if (value.kind == AcpPermissionToolKind.fetch) {
      final targets = [
        for (final item in value.content)
          if (item case AcpPermissionStandardContentDto(content: AcpPermissionResourceLinkDto(:final uri))) uri,
      ];
      if (targets.isNotEmpty) return PluginPermissionDetails.network(targets: targets, command: null);
    }
    return const PluginPermissionDetails.generic();
  }
}
