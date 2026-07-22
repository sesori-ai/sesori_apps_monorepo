import '../updater/foundation/release_track.dart';

const int defaultPluginIdleTimeoutMins = 10;

enum SleepPreventionMode {
  off,
  always,
}

class PluginLifecycleSettings {
  final int? idleTimeoutMins;
  final Map<String, Object?> additionalProperties;

  const PluginLifecycleSettings({
    required this.idleTimeoutMins,
    this.additionalProperties = const {},
  });

  factory PluginLifecycleSettings.fromJson({
    required String entryName,
    required Map<String, dynamic> json,
  }) {
    final rawIdleTimeout = json['idleTimeoutMins'];
    if (json.containsKey('idleTimeoutMins') && rawIdleTimeout is! int) {
      throw PluginIdleTimeoutFormatException(entryName: entryName);
    }
    return PluginLifecycleSettings(
      idleTimeoutMins: rawIdleTimeout as int?,
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

class BridgePluginSettings {
  final Set<String> disabledPluginIds;
  final PluginLifecycleSettings defaults;
  final Map<String, PluginLifecycleSettings> settingsByPluginId;

  const BridgePluginSettings({
    this.disabledPluginIds = const {},
    this.defaults = const PluginLifecycleSettings(idleTimeoutMins: null),
    this.settingsByPluginId = const {},
  });

  factory BridgePluginSettings.fromJson({required Object? rawValue}) {
    if (rawValue is! Map || rawValue.keys.any((key) => key is! String)) {
      throw const PluginSettingsFormatException('"plugins" must be an object');
    }
    final json = rawValue.cast<String, dynamic>();
    final rawDisabled = json['disabled'];
    if (json.containsKey('disabled') &&
        (rawDisabled is! List || rawDisabled.any((value) => value is! String || value.isEmpty))) {
      throw const PluginSettingsFormatException(
        '"plugins.disabled" must be a list containing only non-empty plugin ids',
      );
    }
    final disabledIds = rawDisabled == null
        ? const <String>{}
        : Set<String>.unmodifiable((rawDisabled as List).cast<String>());

    PluginLifecycleSettings parseEntry({required String name, required Object? value}) {
      if (value is! Map || value.keys.any((key) => key is! String)) {
        throw PluginSettingsFormatException('"plugins.$name" must be an object');
      }
      return PluginLifecycleSettings.fromJson(entryName: name, json: value.cast<String, dynamic>());
    }

    final settingsByPluginId = <String, PluginLifecycleSettings>{};
    for (final entry in json.entries) {
      if (entry.key == 'disabled' || entry.key == 'default') continue;
      if (entry.key.isEmpty) {
        throw const PluginSettingsFormatException('"plugins" entry names must be non-empty plugin ids');
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
    final sortedPluginIds = settingsByPluginId.keys.toList()..sort();
    return {
      if (sortedDisabledIds.isNotEmpty) 'disabled': sortedDisabledIds,
      if (!defaults.isEmpty) 'default': defaults.toJson(),
      for (final pluginId in sortedPluginIds) pluginId: settingsByPluginId[pluginId]!.toJson(),
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

class BridgeSettings {
  final SleepPreventionMode sleepPrevention;

  /// Automatically approves permission requests at the bridge without
  /// forwarding them to connected clients.
  final bool yolo;

  /// Plugin eligibility and lifecycle settings.
  final BridgePluginSettings plugins;

  /// Which release channel the auto-updater follows.
  final ReleaseTrack releaseTrack;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
    this.yolo = false,
    this.plugins = const BridgePluginSettings(),
    this.releaseTrack = ReleaseTrack.stable,
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
      yolo: json['yolo'] == true,
      plugins: json.containsKey('plugins')
          ? BridgePluginSettings.fromJson(rawValue: json['plugins'])
          : const BridgePluginSettings(),
      releaseTrack: _parseReleaseTrack(json['releaseTrack']),
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
      if (!plugins.isEmpty) 'plugins': plugins.toJson(),
    };
  }

  BridgeSettings copyWith({
    SleepPreventionMode? sleepPrevention,
    bool? yolo,
    BridgePluginSettings? plugins,
    ReleaseTrack? releaseTrack,
  }) {
    return BridgeSettings(
      sleepPrevention: sleepPrevention ?? this.sleepPrevention,
      yolo: yolo ?? this.yolo,
      plugins: plugins ?? this.plugins,
      releaseTrack: releaseTrack ?? this.releaseTrack,
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
    return ReleaseTrack.fromWire(rawValue is String ? rawValue : null);
  }
}

class PluginSettingsFormatException extends FormatException {
  const PluginSettingsFormatException(super.message);
}

class PluginIdleTimeoutFormatException extends PluginSettingsFormatException {
  final String entryName;

  PluginIdleTimeoutFormatException({required this.entryName})
    : super('"plugins.$entryName.idleTimeoutMins" must be an integer');
}
