import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "diff_file_list.dart";

/// The session's "+12 −2" beside its Changes button; null while there is
/// nothing to show, so the button stays plain "Changes". That covers totals
/// not loaded yet, a bridge that cannot report them, and no changed lines.
Widget? sessionChangesCounts({required DiffSummaryState state, required TextStyle style}) => switch (state) {
  DiffSummaryCounts(:final additions, :final deletions) when additions > 0 || deletions > 0 => DiffCounts(
    additions: additions,
    deletions: deletions,
    style: style,
  ),
  DiffSummaryCounts() || DiffSummaryUnknown() => null,
};
