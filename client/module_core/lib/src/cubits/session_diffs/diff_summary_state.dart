import "package:freezed_annotation/freezed_annotation.dart";

part "diff_summary_state.freezed.dart";

@Freezed(fromJson: false, toJson: false)
sealed class DiffSummaryState with _$DiffSummaryState {
  /// No totals to show: not loaded yet, or the bridge cannot report them.
  const factory unknown() = DiffSummaryUnknown;

  const factory counts({
    required int additions,
    required int deletions,
  }) = DiffSummaryCounts;
}
