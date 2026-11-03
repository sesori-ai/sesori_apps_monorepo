import '../updater/foundation/release_track.dart';

const int defaultPluginIdleTimeoutMins = 45;
const int defaultPullRequestRefreshIntervalSeconds = 30;
const int minimumPullRequestRefreshIntervalSeconds = 15;
const int maximumPullRequestRefreshIntervalSeconds = 3600;
const bool defaultWarmUpPluginsOnSessionOpen = true;

enum SleepPreventionMode() {
  off,
  always,
}

class const PluginLifecycleSettings({
    required final int? idleTimeoutMins,
    final Map<String, Object?> additionalProperties = const {},
  }) {
  factory fromJson({
    required String entryName,
    required Map<String, dynamic> json,
  }) {
    final int? idleTimeoutMins;
    switch (json['idleTimeoutMins']) {
      case final int value:
        idleTimeoutMins = value;
      case null when !json.containsKey('idleTimeoutMins'):
        idleTimeoutMins = null;
      case _:
        throw PluginIdleTimeoutFormatException(entryName: entryName);
    }
    return PluginLifecycleSettings(
      idleTimeoutMins: idleTimeoutMins,
      additionalProperties: Map<String, Object?>.unmodifiable({
        for (final entry in json.entries)
          if (entry.key != 'idleTimeoutMins') entry.key: entry.value,
      }),
    );
  }

  bool get isEmpty => idleTimeoutMins == null && additionalProperties.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      ...additionalProperties,
      if (idleTimeoutMins != null) 'idleTimeoutMins': idleTimeoutMins,
    };
  }

  PluginLifecycleSettings copyWithIdleTimeout({required int? idleTimeoutMins}) {
    return PluginLifecycleSettings(
      idleTimeoutMins: idleTimeoutMins,
      additionalProperties: additionalProperties,
    );
  }
}

class const BridgePluginSettings({
    final Set<String> disabledPluginIds = const {},
    final PluginLifecycleSettings defaults = const PluginLifecycleSettings(idleTimeoutMins: null),
    final Map<String, PluginLifecycleSettings> settingsByPluginId = const {},
  }) {
  factory fromJson({required Object? rawValue}) {
    if (rawValue is! Map || rawValue.keys.any((key) => key is! String)) {
      throw const PluginSettingsFormatException(message: '"plugins" must be an object');
    }
    final json = rawValue.cast<String, dynamic>();
    final Set<String> disabledIds;
    switch (json['disabled']) {
      case null when !json.containsKey('disabled'):
        disabledIds = const <String>{};
      case final List<Object?> values when values.every((value) => value is String && value.isNotEmpty):
        disabledIds = Set<String>.unmodifiable(values.whereType<String>());
      case _:
        throw const PluginSettingsFormatException(
          message: '"plugins.disabled" must be a list containing only non-empty plugin ids',
        );
    }

    PluginLifecycleSettings parseEntry({required String name, required Object? value}) {
      if (value is! Map || value.keys.any((key) => key is! String)) {
        throw PluginSettingsFormatException(message: '"plugins.$name" must be an object');
      }
      return PluginLifecycleSettings.fromJson(entryName: name, json: value.cast<String, dynamic>());
    }

    final settingsByPluginId = <String, PluginLifecycleSettings>{};
    for (final entry in json.entries) {
      if (entry.key == 'disabled' || entry.key == 'default') continue;
      if (entry.key.isEmpty) {
        throw const PluginSettingsFormatException(message: '"plugins" entry names must be non-empty plugin ids');
      }
      settingsByPluginId[entry.key] = parseEntry(name: entry.key, value: entry.value);
    }

    return BridgePluginSettings(
      disabledPluginIds: disabledIds,
      defaults: json.containsKey('default')
          ? parseEntry(name: 'default', value: json['default'])
          : const PluginLifecycleSettings(idleTimeoutMins: null),
      settingsByPluginId: Map<String, PluginLifecycleSettings>.unmodifiable(settingsByPluginId),
    );
  }

  bool get isEmpty => disabledPluginIds.isEmpty && defaults.isEmpty && settingsByPluginId.isEmpty;

  bool isDisabled({required String pluginId}) => disabledPluginIds.contains(pluginId);

  int idleTimeoutMinsFor({required String pluginId}) {
    return settingsByPluginId[pluginId]?.idleTimeoutMins ?? defaults.idleTimeoutMins ?? defaultPluginIdleTimeoutMins;
  }

  Map<String, dynamic> toJson() {
    final sortedDisabledIds = disabledPluginIds.toList()..sort();
    final sortedPluginSettings = settingsByPluginId.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {
      if (sortedDisabledIds.isNotEmpty) 'disabled': sortedDisabledIds,
      if (!defaults.isEmpty) 'default': defaults.toJson(),
      for (final MapEntry(key: pluginId, value: settings) in sortedPluginSettings) pluginId: settings.toJson(),
    };
  }

  BridgePluginSettings withPluginDisabled({required String pluginId, required bool disabled}) {
    final updated = Set<String>.of(disabledPluginIds);
    if (disabled) {
      updated.add(pluginId);
    } else {
      updated.remove(pluginId);
    }
    return BridgePluginSettings(
      disabledPluginIds: Set<String>.unmodifiable(updated),
      defaults: defaults,
      settingsByPluginId: settingsByPluginId,
    );
  }

  BridgePluginSettings withDefaultIdleTimeout({
    required int idleTimeoutMins,
    required Set<String> clearOverridePluginIds,
  }) {
    final entries = <String, PluginLifecycleSettings>{};
    for (final entry in settingsByPluginId.entries) {
      final updated = clearOverridePluginIds.contains(entry.key)
          ? entry.value.copyWithIdleTimeout(idleTimeoutMins: null)
          : entry.value;
      if (!updated.isEmpty) entries[entry.key] = updated;
    }
    return BridgePluginSettings(
      disabledPluginIds: disabledPluginIds,
      defaults: defaults.copyWithIdleTimeout(idleTimeoutMins: idleTimeoutMins),
      settingsByPluginId: Map<String, PluginLifecycleSettings>.unmodifiable(entries),
    );
  }

  BridgePluginSettings withPluginIdleTimeout({required String pluginId, required int? idleTimeoutMins}) {
    final entries = Map<String, PluginLifecycleSettings>.of(settingsByPluginId);
    final updated = (entries[pluginId] ?? const PluginLifecycleSettings(idleTimeoutMins: null)).copyWithIdleTimeout(
      idleTimeoutMins: idleTimeoutMins,
    );
    if (updated.isEmpty) {
      entries.remove(pluginId);
    } else {
      entries[pluginId] = updated;
    }
    return BridgePluginSettings(
      disabledPluginIds: disabledPluginIds,
      defaults: defaults,
      settingsByPluginId: Map<String, PluginLifecycleSettings>.unmodifiable(entries),
    );
  }
}

class const BridgeSettings({
    final SleepPreventionMode sleepPrevention = SleepPreventionMode.always,
    /// Automatically approves permission requests at the bridge without
  /// forwarding them to connected clients.
  final bool yolo = false,
    /// Plugin eligibility and lifecycle settings.
  final BridgePluginSettings plugins = const BridgePluginSettings(),
    /// Which release channel the auto-updater follows.
  final ReleaseTrack releaseTrack = ReleaseTrack.stable,
    /// Pull request refresh interval that released apps read and save; it has no effect.
  // COMPATIBILITY 2026-10-25 (v1.10.0): Released apps read and save this interval through the settings routes, so
  // it is still persisted. Remove once public apps older than v1.10.1 are unsupported.
  final int pullRequestRefreshIntervalSeconds = defaultPullRequestRefreshIntervalSeconds,
    /// Whether opening a session should start its plugin before the first operation needs it.
  final bool warmUpPluginsOnSessionOpen = defaultWarmUpPluginsOnSessionOpen,
  }) {
  factory fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
      yolo: json['yolo'] == true,
      plugins: json.containsKey('plugins')
          ? BridgePluginSettings.fromJson(rawValue: json['plugins'])
          : const BridgePluginSettings(),
      releaseTrack: _parseReleaseTrack(json['releaseTrack']),
      pullRequestRefreshIntervalSeconds: _parsePullRequestRefreshInterval(
        isPresent: json.containsKey('pullRequestRefreshIntervalSeconds'),
        rawValue: json['pullRequestRefreshIntervalSeconds'],
      ),
      warmUpPluginsOnSessionOpen: _parseWarmUpPluginsOnSessionOpen(
        isPresent: json.containsKey('warmUpPluginsOnSessionOpen'),
        rawValue: json['warmUpPluginsOnSessionOpen'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleepPrevention': switch (sleepPrevention) {
        SleepPreventionMode.off => 'off',
        SleepPreventionMode.always => 'always',
      },
      'yolo': yolo,
      'releaseTrack': releaseTrack.wireValue,
      'pullRequestRefreshIntervalSeconds': pullRequestRefreshIntervalSeconds,
      'warmUpPluginsOnSessionOpen': warmUpPluginsOnSessionOpen,
      if (!plugins.isEmpty) 'plugins': plugins.toJson(),
    };
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, copyWith replaces only the fields a caller passes
  BridgeSettings copyWith({
    SleepPreventionMode? sleepPrevention,
    bool? yolo,
    BridgePluginSettings? plugins,
    ReleaseTrack? releaseTrack,
    int? pullRequestRefreshIntervalSeconds,
    bool? warmUpPluginsOnSessionOpen,
  }) {
    return BridgeSettings(
      sleepPrevention: sleepPrevention ?? this.sleepPrevention,
      yolo: yolo ?? this.yolo,
      plugins: plugins ?? this.plugins,
      releaseTrack: releaseTrack ?? this.releaseTrack,
      pullRequestRefreshIntervalSeconds: pullRequestRefreshIntervalSeconds ?? this.pullRequestRefreshIntervalSeconds,
      warmUpPluginsOnSessionOpen: warmUpPluginsOnSessionOpen ?? this.warmUpPluginsOnSessionOpen,
    );
  }

  static SleepPreventionMode _parseSleepPrevention(Object? rawValue) {
    return switch (rawValue) {
      'off' => SleepPreventionMode.off,
      'always' => SleepPreventionMode.always,
      _ => SleepPreventionMode.always,
    };
  }

  static ReleaseTrack _parseReleaseTrack(Object? rawValue) {
    return ReleaseTrack.fromWire(value: rawValue is String ? rawValue : null);
  }

  static int _parsePullRequestRefreshInterval({required bool isPresent, required Object? rawValue}) {
    if (!isPresent) return defaultPullRequestRefreshIntervalSeconds;
    if (rawValue is! int ||
        rawValue < minimumPullRequestRefreshIntervalSeconds ||
        rawValue > maximumPullRequestRefreshIntervalSeconds) {
      throw const PullRequestRefreshIntervalFormatException();
    }
    return rawValue;
  }

  static bool _parseWarmUpPluginsOnSessionOpen({required bool isPresent, required Object? rawValue}) {
    if (!isPresent) return defaultWarmUpPluginsOnSessionOpen;
    if (rawValue is! bool) throw const WarmUpPluginsOnSessionOpenFormatException();
    return rawValue;
  }
}

class const PluginSettingsFormatException({required String message}) extends FormatException {
  this : super(message);
}

class PluginIdleTimeoutFormatException({required final String entryName}) extends PluginSettingsFormatException {
  this
    : super(message: '"plugins.$entryName.idleTimeoutMins" must be an integer');
}

class const PullRequestRefreshIntervalFormatException() extends FormatException {
  this
    : super(
        '"pullRequestRefreshIntervalSeconds" must be an integer between '
        '$minimumPullRequestRefreshIntervalSeconds and $maximumPullRequestRefreshIntervalSeconds',
      );
}

class const WarmUpPluginsOnSessionOpenFormatException() extends FormatException {
  this
    : super('"warmUpPluginsOnSessionOpen" must be a boolean');
}
