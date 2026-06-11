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

  /// Reads settings without [loadSettings]'s create-with-defaults side
  /// effect: a missing or invalid config yields in-memory defaults and the
  /// file is left untouched.
  ///
  /// For parse-time reads — plugin selection runs before the CLI parser is
  /// even built, where `--help` or `logout` must not create the config file.
  /// Deliberately silent for the same reason: a corruption warning here
  /// would land on stdout of `--version`/`--help` before any `--log-level`
  /// is parsed; the run path reports corruption through [loadSettings].
  ///
  /// Only *content* problems are absorbed here. An I/O failure from the
  /// read itself propagates, like it does from [loadSettings]: whether that
  /// is fatal is the caller's policy (the parse-time caller maps it to
  /// "unset" with a stderr diagnostic).
  Future<BridgeSettings> peekSettings() async {
    final storedConfig = await _api.readConfig();
    if (storedConfig == null) {
      return const BridgeSettings();
    }

    try {
      return BridgeSettings.fromJson(jsonDecodeMap(storedConfig));
    } catch (_) {
      return const BridgeSettings();
    }
  }

  Future<void> saveSettings({required BridgeSettings settings}) {
    return _api.writeConfig(_jsonEncoder.convert(settings.toJson()));
  }
}
