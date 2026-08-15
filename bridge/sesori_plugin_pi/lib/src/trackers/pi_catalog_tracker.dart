import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSessionOptions;

class PiCatalogTracker() {
  final Map<String, PluginSessionOptions> _snapshots = {};

  PluginSessionOptions? snapshotFor({required String projectId}) =>
      _snapshots[normalizeProjectDirectory(directory: projectId)];

  void replace({required String projectId, required PluginSessionOptions snapshot}) {
    _snapshots[normalizeProjectDirectory(directory: projectId)] = snapshot;
  }
}
