import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "transcript_live_row.dart";

/// The quiet grey line that ends a turn which did not finish on its own, such
/// as one the user stopped. It is not an error: it looks like a settled step
/// row, as the compaction row does, with the reply's inset around it.
///
/// It stands exactly as tall as [TranscriptWorkingRow] does as the first row,
/// so when it arrives as the working row folds away the transcript holds
/// still.
class const TurnEndLine({
  super.key,
  required final IconData icon,
  required final String label,
}) extends StatelessWidget {
  /// The reply card's inset, which the working row takes as the first row.
  static const EdgeInsets _replyPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  @override
  Widget build(BuildContext context) {
    final color = context.prego.colors.textSecondary;
    return Padding(
      padding: _replyPadding + const EdgeInsets.symmetric(vertical: TranscriptStepRow.stepGap),
      child: TranscriptStepRow(
        leading: Icon(icon, size: PregoIconSize.sm, color: color),
        label: label,
        detail: null,
        live: false,
        color: null,
        trailing: null,
      ),
    );
  }
}
