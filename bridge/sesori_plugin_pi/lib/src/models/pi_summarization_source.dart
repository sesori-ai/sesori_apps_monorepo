import "pi_compaction_reason.dart";

/// The operation whose summary Pi is retrying.
sealed class const PiSummarizationSource() {
  static PiSummarizationSource parse({required String? source, required Object? reason}) {
    if (source == "branchSummary" && reason == null) return const PiBranchSummarySource();
    final compactionReason = PiCompactionReason.tryParse(value: reason);
    if (source == "compaction" && compactionReason != null) {
      return PiCompactionSummarizationSource(reason: compactionReason);
    }
    return PiUnknownSummarizationSource(source: source, reason: reason);
  }
}

final class const PiBranchSummarySource() extends PiSummarizationSource;

final class const PiCompactionSummarizationSource({required this.reason}) extends PiSummarizationSource {
  final PiCompactionReason reason;
}

final class const PiUnknownSummarizationSource({required this.source, required this.reason}) extends PiSummarizationSource {
  final String? source;
  final Object? reason;
}
