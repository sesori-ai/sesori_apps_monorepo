import "pi_compaction_reason.dart";

/// The operation whose summary Pi is retrying.
sealed class PiSummarizationSource {
  const PiSummarizationSource();

  static PiSummarizationSource parse({required String? source, required Object? reason}) {
    if (source == "branchSummary" && reason == null) return const PiBranchSummarySource();
    final compactionReason = PiCompactionReason.tryParse(value: reason);
    if (source == "compaction" && compactionReason != null) {
      return PiCompactionSummarizationSource(reason: compactionReason);
    }
    return PiUnknownSummarizationSource(source: source, reason: reason);
  }
}

final class PiBranchSummarySource extends PiSummarizationSource {
  const PiBranchSummarySource();
}

final class PiCompactionSummarizationSource extends PiSummarizationSource {
  const PiCompactionSummarizationSource({required this.reason});

  final PiCompactionReason reason;
}

final class PiUnknownSummarizationSource extends PiSummarizationSource {
  const PiUnknownSummarizationSource({required this.source, required this.reason});

  final String? source;
  final Object? reason;
}
