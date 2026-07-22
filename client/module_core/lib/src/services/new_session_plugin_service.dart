import "dart:async";

import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "../repositories/plugin_preference_repository.dart";
import "../repositories/plugin_repository.dart";

class NewSessionPluginDiscovery {
  final String? bridgeId;
  final List<PluginMetadata> plugins;
  final PluginMetadata? selected;

  const NewSessionPluginDiscovery({
    required this.bridgeId,
    required this.plugins,
    required this.selected,
  });
}

@lazySingleton
class NewSessionPluginService {
  final PluginRepository _pluginRepository;
  final PluginPreferenceRepository _pluginPreferenceRepository;

  NewSessionPluginService({
    required PluginRepository pluginRepository,
    required PluginPreferenceRepository pluginPreferenceRepository,
  }) : _pluginRepository = pluginRepository,
       _pluginPreferenceRepository = pluginPreferenceRepository;

  Future<ApiResponse<NewSessionPluginDiscovery>> discover() async {
    final response = await _pluginRepository.listPlugins();
    switch (response) {
      case ErrorResponse(:final error):
        return ApiResponse.error(error);
      case SuccessResponse(:final data):
        final defaultPlugin = data.plugins.where((plugin) => plugin.isDefault).singleOrNull;
        String? savedPluginId;
        final bridgeId = data.bridgeId;
        if (bridgeId != null) {
          try {
            savedPluginId = await _pluginPreferenceRepository.readPluginId(bridgeId: bridgeId);
          } on Object catch (error, stackTrace) {
            logw("New session: failed to read the plugin preference for bridge $bridgeId", error, stackTrace);
          }
        }
        final selected = savedPluginId == null
            ? defaultPlugin
            : data.plugins.firstWhereOrNull(
                    (plugin) => plugin.id == savedPluginId && _isRoutable(plugin),
                  ) ??
                  defaultPlugin;
        return ApiResponse.success(
          NewSessionPluginDiscovery(
            bridgeId: bridgeId,
            plugins: data.plugins,
            selected: selected,
          ),
        );
    }
  }

  void recordSelection({required String? bridgeId, required PluginMetadata plugin}) {
    if (bridgeId == null || !_isRoutable(plugin)) return;
    unawaited(_writeSelection(bridgeId: bridgeId, pluginId: plugin.id));
  }

  bool _isRoutable(PluginMetadata plugin) {
    return plugin.state == PluginLifecycleState.ready || plugin.state == PluginLifecycleState.degraded;
  }

  Future<void> _writeSelection({required String bridgeId, required String pluginId}) async {
    try {
      await _pluginPreferenceRepository.writePluginId(bridgeId: bridgeId, pluginId: pluginId);
    } on Object catch (error, stackTrace) {
      logw("New session: failed to persist the plugin preference for bridge $bridgeId", error, stackTrace);
    }
  }
}
