import "package:injectable/injectable.dart";

import "../api/plugin_preference_api.dart";

@lazySingleton
class PluginPreferenceRepository({required final PluginPreferenceApi _api}) {
  Future<String?> readPluginId({required String bridgeId}) {
    return _api.readPluginId(bridgeId: bridgeId);
  }

  Future<void> writePluginId({required String bridgeId, required String pluginId}) {
    return _api.writePluginId(bridgeId: bridgeId, pluginId: pluginId);
  }
}
