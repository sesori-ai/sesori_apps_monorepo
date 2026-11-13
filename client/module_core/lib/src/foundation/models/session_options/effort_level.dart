/// The shared effort ladder harnesses report as model variants, weakest first.
enum EffortLevel({
  /// The variant id a harness reports for this level.
  required final String wireId,
}) {
  minimal(wireId: "minimal"),
  low(wireId: "low"),
  medium(wireId: "medium"),
  high(wireId: "high"),
  xhigh(wireId: "xhigh"),
  max(wireId: "max"),
  ultra(wireId: "ultra");

  /// The level a variant id names, or `null` when it is not on the ladder.
  static EffortLevel? tryParse({required String value}) {
    for (final level in EffortLevel.values) {
      if (level.wireId == value) return level;
    }
    return null;
  }
}
