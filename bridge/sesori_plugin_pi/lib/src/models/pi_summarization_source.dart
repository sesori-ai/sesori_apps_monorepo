/// The operation whose summary Pi is retrying.
enum PiSummarizationSource {
  branchSummary("branchSummary"),
  compaction("compaction");

  const PiSummarizationSource(this.wireValue);

  final String wireValue;

  static PiSummarizationSource? tryParse({required String? value}) {
    for (final source in values) {
      if (source.wireValue == value) return source;
    }
    return null;
  }
}
