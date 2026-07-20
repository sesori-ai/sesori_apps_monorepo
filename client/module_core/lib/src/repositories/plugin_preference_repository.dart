import "package:injectable/injectable.dart";

import "../api/plugin_preference_api.dart";

@lazySingleton
class PluginPreferenceRepository {
  final PluginPreferenceApi _api;

  PluginPreferenceRepository({required PluginPreferenceApi api}) : _api = api;

  Future<String?> readPluginId({required String bridgeId}) {
    return _api.readPluginId(bridgeId: bridgeId);
  }

  Future<void> writePluginId({required String bridgeId, required String pluginId}) {
    return _api.writePluginId(bridgeId: bridgeId, pluginId: pluginId);
  }

  Future<void> deletePluginId({required String bridgeId}) {
    return _api.deletePluginId(bridgeId: bridgeId);
  }
}
