import 'dart:convert';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart' show jsonDecodeMap;

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
      await _api.writeConfig(_jsonEncoder.convert(defaults.toJson()));
      return defaults;
    }

    try {
      final json = jsonDecodeMap(storedConfig);
      return BridgeSettings.fromJson(json);
    } catch (error) {
      Log.w('[bridge-settings] invalid config at $configFilePath: $error');
      const defaults = BridgeSettings();
      await _api.writeConfig(_jsonEncoder.convert(defaults.toJson()));
      return defaults;
    }
  }

  Future<void> saveSettings({required BridgeSettings settings}) {
    return _api.writeConfig(_jsonEncoder.convert(settings.toJson()));
  }
}
