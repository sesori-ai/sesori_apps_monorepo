import 'dart:async';
import 'dart:convert';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart'
    show BridgeSettingsResponse, PullRequestRefreshSettingsResponse, YoloSettingsResponse, jsonDecodeMap;

import '../api/bridge_settings_api.dart';
import '../updater/foundation/release_track.dart';
import 'bridge_settings.dart';

class BridgeSettingsRepository({required final BridgeSettingsApi _api}) {
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  final StreamController<BridgeSettingsChange> _settingsChanges = StreamController<BridgeSettingsChange>.broadcast(
    sync: true,
  );
  BridgeSettings? _currentSettings;
  Future<void> _mutationTail = Future<void>.value();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  String get configFilePath => _api.configFilePath;

  Stream<BridgeSettingsChange> get settingsChanges => _settingsChanges.stream;

  BridgeSettings get currentSettings {
    final settings = _currentSettings;
    if (settings == null) throw StateError('Bridge settings have not been loaded.');
    return settings;
  }

  Future<BridgeSettings> readCommittedSettings() async {
    await _mutationTail;
    return currentSettings;
  }

  Future<BridgeSettingsResponse> readCommittedResponse() async {
    final settings = await readCommittedSettings();
    return BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(
        intervalSeconds: settings.pullRequestRefreshIntervalSeconds,
      ),
      yolo: YoloSettingsResponse(enabled: settings.yolo),
    );
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
    if (parsed.repairErrors.isNotEmpty || parsed.missingPullRequestRefreshInterval) {
      for (final repairError in parsed.repairErrors) {
        Log.w(
          '[bridge-settings] invalid config at $configFilePath',
          repairError.error,
          repairError.stackTrace,
        );
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

  Future<BridgeSettings> mutateSettings({
    required BridgeSettings Function({required BridgeSettings current}) mutation,
  }) {
    if (_disposed) return Future<BridgeSettings>.error(StateError('Bridge settings repository has been disposed.'));

    final completer = Completer<BridgeSettings>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        final current = _currentSettings ?? await loadSettings();
        final updated = mutation(current: current);
        if (identical(updated, current)) {
          completer.complete(current);
          return;
        }
        if (updated.pullRequestRefreshIntervalSeconds < minimumPullRequestRefreshIntervalSeconds ||
            updated.pullRequestRefreshIntervalSeconds > maximumPullRequestRefreshIntervalSeconds) {
          throw const PullRequestRefreshIntervalFormatException();
        }
        await _api.writeConfig(_jsonEncoder.convert(updated.toJson()));
        _currentSettings = updated;
        _settingsChanges.add(BridgeSettingsChange(previous: current, current: updated));
        completer.complete(updated);
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> updateReleaseTrack({required ReleaseTrack track}) async {
    await mutateSettings(mutation: ({required current}) => current.copyWith(releaseTrack: track));
  }

  Future<void> updateYolo({required bool enabled}) async {
    await mutateSettings(mutation: ({required current}) => current.copyWith(yolo: enabled));
  }

  Future<BridgeSettings> updatePluginDisabled({required String pluginId, required bool disabled}) async {
    return await mutateSettings(
      mutation: ({required current}) => current.copyWith(
        plugins: current.plugins.withPluginDisabled(pluginId: pluginId, disabled: disabled),
      ),
    );
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _mutationTail;
    await _settingsChanges.close();
  }

  ({
    BridgeSettings settings,
    List<({FormatException error, StackTrace stackTrace})> repairErrors,
    bool missingPullRequestRefreshInterval,
  })
  _parseSettings(
    Map<String, dynamic> json,
  ) {
    final repaired = Map<String, dynamic>.of(json);
    final missingPullRequestRefreshInterval = !repaired.containsKey('pullRequestRefreshIntervalSeconds');
    if (missingPullRequestRefreshInterval) {
      repaired['pullRequestRefreshIntervalSeconds'] = defaultPullRequestRefreshIntervalSeconds;
    }
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
    final errors = <({FormatException error, StackTrace stackTrace})>[];
    while (true) {
      try {
        return (
          settings: BridgeSettings.fromJson(repaired),
          repairErrors: List.unmodifiable(errors),
          missingPullRequestRefreshInterval: missingPullRequestRefreshInterval,
        );
      } on PluginIdleTimeoutFormatException catch (error, stackTrace) {
        final plugins = repaired['plugins'];
        if (plugins is! Map<String, dynamic>) rethrow;
        final entry = plugins[error.entryName];
        if (entry is! Map<String, dynamic> || !entry.containsKey('idleTimeoutMins')) rethrow;
        entry.remove('idleTimeoutMins');
        if (entry.isEmpty && error.entryName != 'default') plugins.remove(error.entryName);
        errors.add((error: error, stackTrace: stackTrace));
      } on PullRequestRefreshIntervalFormatException catch (error, stackTrace) {
        repaired['pullRequestRefreshIntervalSeconds'] = defaultPullRequestRefreshIntervalSeconds;
        errors.add((error: error, stackTrace: stackTrace));
      }
    }
  }
}

class const BridgeSettingsChange({required final BridgeSettings previous, required final BridgeSettings current});
