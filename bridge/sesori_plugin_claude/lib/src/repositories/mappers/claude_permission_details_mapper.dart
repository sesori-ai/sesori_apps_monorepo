import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/claude_permission_input_dto.dart";

class const ClaudePermissionDetailsMapper() {
  PluginPermissionDetails map({required String tool, required Map<String, Object?> input}) {
    if (!const {"Bash", "Edit", "MultiEdit", "Write", "NotebookEdit", "WebFetch"}.contains(tool)) {
      return const PluginPermissionDetails.generic();
    }
    final value = ClaudePermissionInputDto.fromJson(input);
    return switch (tool) {
      "Bash" when value.command != null && value.command!.isNotEmpty => PluginPermissionDetails.command(
        command: value.command!,
      ),
      "Edit" ||
      "MultiEdit" ||
      "Write" when value.filePath != null && value.filePath!.isNotEmpty => PluginPermissionDetails.fileChanges(
        files: [
          PluginPermissionFile(path: value.filePath!, operation: PluginPermissionFileOperation.write),
        ],
      ),
      "NotebookEdit" when value.notebookPath != null && value.notebookPath!.isNotEmpty =>
        PluginPermissionDetails.fileChanges(
          files: [
            PluginPermissionFile(path: value.notebookPath!, operation: PluginPermissionFileOperation.write),
          ],
        ),
      "WebFetch" when value.url != null && value.url!.isNotEmpty => PluginPermissionDetails.network(
        targets: [value.url!],
        command: null,
      ),
      _ => const PluginPermissionDetails.generic(),
    };
  }
}
