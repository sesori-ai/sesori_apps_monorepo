enum SleepPreventionMode {
  off,
  always,
}

class BridgeSettings {
  final SleepPreventionMode sleepPrevention;

  /// Plugin ids enabled to run (the `--plugin <id>` namespace). Null means
  /// unset — the bridge then defaults to opencode, so existing installs see
  /// zero change. Until the orchestrator supports multiple concurrently
  /// active plugins, more than one entry is rejected at startup.
  final List<String>? enabledPlugins;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
    this.enabledPlugins,
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
      enabledPlugins: _parseEnabledPlugins(json['enabledPlugins']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleepPrevention': switch (sleepPrevention) {
        SleepPreventionMode.off => 'off',
        SleepPreventionMode.always => 'always',
      },
      // Only written when set: the defaults file must keep its exact
      // pre-existing shape for installs that never touched the key.
      if (enabledPlugins != null) 'enabledPlugins': enabledPlugins,
    };
  }

  static SleepPreventionMode _parseSleepPrevention(Object? rawValue) {
    return switch (rawValue) {
      'off' => SleepPreventionMode.off,
      'always' => SleepPreventionMode.always,
      _ => SleepPreventionMode.always,
    };
  }

  static List<String>? _parseEnabledPlugins(Object? rawValue) {
    if (rawValue is! List) {
      return null;
    }
    return rawValue.whereType<String>().toList();
  }
}
