import '../updater/foundation/release_track.dart';

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

  /// Which release channel the auto-updater follows. Defaults to
  /// [ReleaseTrack.stable] so existing installs keep getting only stable
  /// releases unless the user opts in via `config track internal`.
  final ReleaseTrack releaseTrack;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
    this.enabledPlugins,
    this.releaseTrack = ReleaseTrack.stable,
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
      enabledPlugins: _parseEnabledPlugins(json['enabledPlugins']),
      releaseTrack: _parseReleaseTrack(json['releaseTrack']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleepPrevention': switch (sleepPrevention) {
        SleepPreventionMode.off => 'off',
        SleepPreventionMode.always => 'always',
      },
      // Always written (like sleepPrevention) so the option is discoverable
      // via `config edit`. Existing valid configs are only rewritten on
      // create/repair, so untouched installs do not churn.
      'releaseTrack': releaseTrack.wireValue,
      // Only written when set: the defaults file must keep its exact
      // pre-existing shape for installs that never touched the key.
      if (enabledPlugins != null) 'enabledPlugins': enabledPlugins,
    };
  }

  BridgeSettings copyWith({
    SleepPreventionMode? sleepPrevention,
    List<String>? enabledPlugins,
    ReleaseTrack? releaseTrack,
  }) {
    return BridgeSettings(
      sleepPrevention: sleepPrevention ?? this.sleepPrevention,
      enabledPlugins: enabledPlugins ?? this.enabledPlugins,
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

  static List<String>? _parseEnabledPlugins(Object? rawValue) {
    if (rawValue is! List) {
      return null;
    }
    return rawValue.whereType<String>().toList();
  }

  static ReleaseTrack _parseReleaseTrack(Object? rawValue) {
    return ReleaseTrack.fromWire(rawValue is String ? rawValue : null);
  }
}
