/// A thinking level accepted by Pi v0.84.1.
enum PiThinkingLevel(final String wireValue) {
  off("off"),
  minimal("minimal"),
  low("low"),
  medium("medium"),
  high("high"),
  xhigh("xhigh"),
  max("max");

  static PiThinkingLevel? tryParse({required String? value}) {
    if (value == null) return null;
    final normalized = value.trim();
    for (final level in values) {
      if (level.wireValue == normalized) return level;
    }
    return null;
  }
}
