import '../repositories/bridge_settings_repository.dart';
import '../repositories/default_editor_repository.dart';

typedef PluginConfigEntry = ({String pluginId, bool enabled});

typedef PluginConfigSnapshot = ({
  List<PluginConfigEntry> plugins,
  List<String> unknownDisabledPluginIds,
});

class BridgeConfigService({
  required final BridgeSettingsRepository _bridgeSettingsRepository,
  required final DefaultEditorRepository _defaultEditorRepository,
}) {
  Future<String> openConfigFile() async {
    await _bridgeSettingsRepository.ensureConfigExists();
    final configFilePath = _bridgeSettingsRepository.configFilePath;
    await _defaultEditorRepository.openFile(configFilePath);
    return configFilePath;
  }

  Future<PluginConfigSnapshot> listPlugins({required List<String> knownPluginIds}) async {
    final settings = await _bridgeSettingsRepository.loadSettings();
    final knownIds = knownPluginIds.toSet();
    return (
      plugins: List<PluginConfigEntry>.unmodifiable([
        for (final pluginId in knownPluginIds)
          (pluginId: pluginId, enabled: !settings.plugins.isDisabled(pluginId: pluginId)),
      ]),
      unknownDisabledPluginIds: (settings.plugins.disabledPluginIds.difference(knownIds).toList()..sort()),
    );
  }

  Future<void> setPluginEnabled({
    required String pluginId,
    required bool enabled,
    required Set<String> knownPluginIds,
  }) async {
    if (!knownPluginIds.contains(pluginId)) {
      throw UnknownPluginConfigException(pluginId: pluginId);
    }
    await _bridgeSettingsRepository.updatePluginDisabled(pluginId: pluginId, disabled: !enabled);
  }
}

class const UnknownPluginConfigException({required final String pluginId}) implements Exception {
  @override
  String toString() => 'Unknown plugin "$pluginId".';
}
