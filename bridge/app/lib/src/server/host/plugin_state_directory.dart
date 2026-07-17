import "package:path/path.dart" as p;

import "../../updater/models/managed_runtime_paths.dart";

/// Descriptor id of the OpenCode plugin.
const String openCodePluginId = "opencode";

/// The private state directory handed to plugin [pluginId] as
/// `PluginHost.stateDirectory`.
///
/// Plugins live under `<installRoot>/plugins/<id>/` — except OpenCode, which
/// is handed `<cacheDirectory>/runtime`: its ownership file
/// `opencode-processes.json` lives there under a frozen cross-version
/// contract and can never move.
String pluginStateDirectoryPath({
  required ManagedRuntimePaths paths,
  required String pluginId,
}) {
  if (pluginId.isEmpty || pluginId == "." || pluginId == ".." || pluginId.contains("/") || pluginId.contains(r"\")) {
    throw ArgumentError.value(pluginId, "pluginId", "must be a plain directory name");
  }

  if (pluginId == openCodePluginId) {
    return p.join(paths.cacheDirectory, "runtime");
  }

  return p.join(paths.installRoot, "plugins", pluginId);
}
