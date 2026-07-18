import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStateStorage;

import "../../updater/models/managed_runtime_paths.dart";

/// The private state directory handed to plugin [pluginId] as
/// `PluginHost.stateDirectory`.
///
/// Isolated plugins live under `<installRoot>/plugins/<id>/`. Plugins that
/// declare [PluginStateStorage.legacySharedRuntime] keep the shipped
/// `<cacheDirectory>/runtime` path.
String pluginStateDirectoryPath({
  required ManagedRuntimePaths paths,
  required String pluginId,
  required PluginStateStorage stateStorage,
}) {
  if (pluginId.isEmpty || pluginId == "." || pluginId == ".." || pluginId.contains("/") || pluginId.contains(r"\")) {
    throw ArgumentError.value(pluginId, "pluginId", "must be a plain directory name");
  }

  switch (stateStorage) {
    case PluginStateStorage.isolated:
      return p.join(paths.installRoot, "plugins", pluginId);
    case PluginStateStorage.legacySharedRuntime:
      return p.join(paths.cacheDirectory, "runtime");
  }
}
