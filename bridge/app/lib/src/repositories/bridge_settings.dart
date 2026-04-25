enum SleepPreventionMode {
  off,
  always,
}

class BridgeSettings {
  final SleepPreventionMode sleepPrevention;

  const BridgeSettings({
    this.sleepPrevention = SleepPreventionMode.always,
  });
}
