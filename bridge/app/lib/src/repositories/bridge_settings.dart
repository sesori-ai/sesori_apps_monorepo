enum SleepPreventionMode {
  off,
  always,
}

class BridgeSettings {
  final SleepPreventionMode sleepPrevention;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      sleepPrevention: _parseSleepPrevention(json['sleepPrevention']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleepPrevention': switch (sleepPrevention) {
        SleepPreventionMode.off => 'off',
        SleepPreventionMode.always => 'always',
      },
    };
  }

  static SleepPreventionMode _parseSleepPrevention(Object? rawValue) {
    return switch (rawValue) {
      'off' => SleepPreventionMode.off,
      'always' => SleepPreventionMode.always,
      _ => SleepPreventionMode.always,
    };
  }
}
