import 'dart:convert';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart' show jsonDecodeMap;

import '../api/bridge_settings_api.dart';
import '../updater/foundation/release_track.dart';
import 'bridge_settings.dart';

class BridgeSettingsRepository {
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  final BridgeSettingsApi _api;
  BridgeSettings? _currentSettings;

  BridgeSettingsRepository({required BridgeSettingsApi api}) : _api = api;

  String get configFilePath => _api.configFilePath;

  BridgeSettings get currentSettings {
    final settings = _currentSettings;
    if (settings == null) throw StateError('Bridge settings have not been loaded.');
    return settings;
  }

  Future<void> ensureConfigExists() async {
    if (await _api.readConfig() == null) {
      await _api.writeConfig(_jsonEncoder.convert(const BridgeSettings().toJson()));
    }
  }

  Future<BridgeSettings> loadSettings() async {
    final storedConfig = await _api.readConfig();
    if (storedConfig == null) {
      const defaults = BridgeSettings();
      await _api.writeConfig(_jsonEncoder.convert(defaults.toJson()));
      _currentSettings = defaults;
      return defaults;
    }

    final json = jsonDecodeMap(storedConfig);
    final parsed = _parseSettings(json);
    final settings = parsed.settings;
    if (parsed.idleTimeoutErrors.isNotEmpty) {
      for (final error in parsed.idleTimeoutErrors) {
        Log.w('[bridge-settings] invalid config at $configFilePath: $error');
      }
      try {
        await _api.writeConfig(_jsonEncoder.convert(settings.toJson()));
      } on Object catch (error, stackTrace) {
        Log.w('[bridge-settings] failed to repair config at $configFilePath', error, stackTrace);
      }
    }
    _currentSettings = settings;
    return settings;
  }

  Future<void> saveSettings({required BridgeSettings settings}) async {
    await _api.writeConfig(_jsonEncoder.convert(settings.toJson()));
    _currentSettings = settings;
  }

  Future<void> updateReleaseTrack({required ReleaseTrack track}) async {
    final current = await loadSettings();
    await saveSettings(settings: current.copyWith(releaseTrack: track));
  }

  Future<void> updateYolo({required bool enabled}) async {
    final current = await loadSettings();
    await saveSettings(settings: current.copyWith(yolo: enabled));
  }

  Future<BridgeSettings> updatePluginDisabled({required String pluginId, required bool disabled}) async {
    final current = await loadSettings();
    final updated = current.copyWith(
      plugins: current.plugins.withPluginDisabled(pluginId: pluginId, disabled: disabled),
    );
    await saveSettings(settings: updated);
    return updated;
  }

  ({BridgeSettings settings, List<PluginIdleTimeoutFormatException> idleTimeoutErrors}) _parseSettings(
    Map<String, dynamic> json,
  ) {
    final repaired = Map<String, dynamic>.of(json);
    final rawPlugins = repaired['plugins'];
    if (rawPlugins is Map) {
      repaired['plugins'] = <String, dynamic>{
        for (final entry in rawPlugins.entries)
          if (entry.key is String)
            entry.key as String: entry.value is Map
                ? Map<String, dynamic>.from((entry.value as Map).cast<String, dynamic>())
                : entry.value,
      };
    }
    final errors = <PluginIdleTimeoutFormatException>[];
    while (true) {
      try {
        return (settings: BridgeSettings.fromJson(repaired), idleTimeoutErrors: List.unmodifiable(errors));
      } on PluginIdleTimeoutFormatException catch (error) {
        final plugins = repaired['plugins'];
        if (plugins is! Map<String, dynamic>) rethrow;
        final entry = plugins[error.entryName];
        if (entry is! Map<String, dynamic> || !entry.containsKey('idleTimeoutMins')) rethrow;
        entry.remove('idleTimeoutMins');
        if (entry.isEmpty && error.entryName != 'default') plugins.remove(error.entryName);
        errors.add(error);
      }
    }
  }
}
