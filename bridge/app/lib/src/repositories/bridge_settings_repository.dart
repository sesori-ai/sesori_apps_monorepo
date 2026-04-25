import 'dart:convert';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../api/bridge_settings_api.dart';
import 'bridge_settings.dart';

class BridgeSettingsRepository {
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  final BridgeSettingsApi _api;

  BridgeSettingsRepository({required BridgeSettingsApi api}) : _api = api;

  String get configFilePath => _api.configFilePath;

  Future<BridgeSettings> loadSettings() async {
    final storedConfig = await _api.readConfig();
    if (storedConfig == null) {
      const defaults = BridgeSettings();
      await _api.writeConfig(_serialize(defaults));
      return defaults;
    }

    try {
      return _parseSettings(storedConfig);
    } catch (error) {
      Log.w('[bridge-settings] invalid config at $configFilePath: $error');
      const defaults = BridgeSettings();
      await _api.writeConfig(_serialize(defaults));
      return defaults;
    }
  }

  Future<void> saveSettings({required BridgeSettings settings}) {
    return _api.writeConfig(_serialize(settings));
  }

  BridgeSettings _parseSettings(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map) {
      throw const FormatException('expected top-level JSON object');
    }

    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(decoded['sleepPrevention']),
    );
  }

  SleepPreventionMode _parseSleepPrevention(Object? rawValue) {
    return switch (rawValue) {
      'off' => SleepPreventionMode.off,
      'always' => SleepPreventionMode.always,
      _ => SleepPreventionMode.always,
    };
  }

  String _serialize(BridgeSettings settings) {
    return _jsonEncoder.convert({
      'sleepPrevention': switch (settings.sleepPrevention) {
        SleepPreventionMode.off => 'off',
        SleepPreventionMode.always => 'always',
      },
    });
  }
}
