import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "../repositories/plugin_preference_repository.dart";
import "../repositories/plugin_repository.dart";

final class NewSessionPluginDiscovery {
  const NewSessionPluginDiscovery({
    required this.bridgeId,
    required this.plugins,
    required this.selected,
  });

  final String? bridgeId;
  final List<PluginMetadata> plugins;
  final PluginMetadata? selected;
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

  Future<ApiResponse<NewSessionPluginDiscovery>> discover({
    required String? currentSelectedPluginId,
    required String? currentSelectionBridgeId,
  }) async {
    final response = await _pluginRepository.listPlugins();
    switch (response) {
      case ErrorResponse(:final error):
        return ApiResponse.error(error);
      case SuccessResponse(:final data):
        final bridgeId = data.bridgeId;
        final plugins = data.plugins;
        final selected =
            _currentSelection(
              bridgeId: bridgeId,
              plugins: plugins,
              currentSelectedPluginId: currentSelectedPluginId,
              currentSelectionBridgeId: currentSelectionBridgeId,
            ) ??
            await _savedSelection(bridgeId: bridgeId, plugins: plugins) ??
            plugins.where((plugin) => plugin.isDefault).singleOrNull;
        return ApiResponse.success(
          NewSessionPluginDiscovery(bridgeId: bridgeId, plugins: plugins, selected: selected),
        );
    }
  }

  Future<void> recordSelection({required String? bridgeId, required PluginMetadata plugin}) async {
    if (bridgeId == null) return;
    try {
      await _pluginPreferenceRepository.writePluginId(bridgeId: bridgeId, pluginId: plugin.id);
    } on Object catch (error, stackTrace) {
      logw("New session: failed to record plugin preference for bridge $bridgeId", error, stackTrace);
    }
  }

  PluginMetadata? _currentSelection({
    required String? bridgeId,
    required List<PluginMetadata> plugins,
    required String? currentSelectedPluginId,
    required String? currentSelectionBridgeId,
  }) {
    if (bridgeId == null || currentSelectionBridgeId != bridgeId || currentSelectedPluginId == null) {
      return null;
    }
    return plugins.firstWhereOrNull((plugin) => plugin.id == currentSelectedPluginId && plugin.isSelectable);
  }

  Future<PluginMetadata?> _savedSelection({required String? bridgeId, required List<PluginMetadata> plugins}) async {
    if (bridgeId == null) return null;
    final String? savedPluginId;
    try {
      savedPluginId = await _pluginPreferenceRepository.readPluginId(bridgeId: bridgeId);
    } on Object catch (error, stackTrace) {
      logw("New session: failed to read plugin preference for bridge $bridgeId", error, stackTrace);
      return null;
    }
    if (savedPluginId == null) return null;
    return plugins.firstWhereOrNull((plugin) => plugin.id == savedPluginId && plugin.isSelectable);
  }
}

extension on PluginMetadata {
  bool get isSelectable => state == PluginLifecycleState.ready || state == PluginLifecycleState.degraded;
}
