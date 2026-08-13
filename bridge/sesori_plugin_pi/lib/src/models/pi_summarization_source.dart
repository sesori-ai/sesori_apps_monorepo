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

final class const PiCompactionSummarizationSource({required final PiCompactionReason reason})
    extends PiSummarizationSource;

final class const PiUnknownSummarizationSource({required final String? source, required final Object? reason})
    extends PiSummarizationSource;
