import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show writeRestrictedFile;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginAgentToolHost, PluginAgentToolServices, PluginPrivateFileService;

class const BridgePluginAgentToolServices({
  @override required final PluginAgentToolHost tools,
  @override required final PluginPrivateFileService privateFiles,
}) implements PluginAgentToolServices;

class BridgePluginPrivateFileService({required final String stateDirectory}) implements PluginPrivateFileService {
  @override
  Future<String> write({required String name, required String contents}) async {
    _validateName(name);
    final filePath = path.join(stateDirectory, name);
    await writeRestrictedFile(filePath: filePath, contents: contents);
    return filePath;
  }

  @override
  Future<void> delete({required String name}) async {
    _validateName(name);
    final file = File(path.join(stateDirectory, name));
    try {
      await file.delete();
    } on FileSystemException {
      if (file.existsSync()) rethrow;
    }
  }

  static void _validateName(String name) {
    if (name.isEmpty || name == "." || name == ".." || name.contains("/") || name.contains(r"\")) {
      throw ArgumentError.value(name, "name", "must be a plain file name");
    }
  }
}
