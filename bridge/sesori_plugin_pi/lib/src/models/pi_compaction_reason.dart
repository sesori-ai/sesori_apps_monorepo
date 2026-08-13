/// Why Pi started a compaction, from Pi v0.84.1's closed reason set.
enum PiCompactionReason(final String wireValue) {
  manual("manual"),
  threshold("threshold"),
  overflow("overflow");

  static PiCompactionReason? tryParse({required Object? value}) {
    for (final reason in values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}
