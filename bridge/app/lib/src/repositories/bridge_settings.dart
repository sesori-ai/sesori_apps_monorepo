import '../updater/foundation/release_track.dart';

enum SleepPreventionMode {
  off,
  always,
}

class BridgeSettings {
  final SleepPreventionMode sleepPrevention;

  /// Automatically approves permission requests at the bridge without
  /// forwarding them to connected clients.
  final bool yolo;

  /// Plugin ids enabled to run (the `--plugin <id>` namespace). Null means
  /// unset — the bridge then defaults to opencode, so existing installs see
  /// zero change. Order is stable and the first id is the default offered to
  /// new clients.
  final List<String>? enabledPlugins;

  /// Which release channel the auto-updater follows. Defaults to
  /// [ReleaseTrack.stable] so existing installs keep getting only stable
  /// releases unless the user opts in via `config track internal`.
  final ReleaseTrack releaseTrack;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
    this.yolo = false,
    this.enabledPlugins,
    this.releaseTrack = ReleaseTrack.stable,
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
      yolo: json['yolo'] == true,
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
      'yolo': yolo,
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
    bool? yolo,
    List<String>? enabledPlugins,
    ReleaseTrack? releaseTrack,
  }) {
    return BridgeSettings(
      sleepPrevention: sleepPrevention ?? this.sleepPrevention,
      yolo: yolo ?? this.yolo,
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
