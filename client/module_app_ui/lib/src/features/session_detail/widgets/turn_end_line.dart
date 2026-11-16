import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";

/// The quiet grey line that ends a turn which did not finish on its own, such
/// as one the user stopped. It is not an error: it looks like a settled step
/// row, as the compaction row does, with the reply's inset around it.
///
/// It stands exactly as tall as the [TranscriptWorkingRow] it replaces: under
/// a shown reply it joins the reply's inset, as the working row does there, so
/// when it grows in as the working row folds away the transcript holds still.
class const TurnEndLine({
  super.key,
  required final IconData icon,
  required final String label,

  /// Why the turn ended, after the label, or null when the label says it.
  /// It may take a second line on a narrow screen.
  required final String? detail,

  /// Whether a reply shows above it, whose inset it then shares.
  required final bool followsReply,
}) extends StatelessWidget {
  /// The reply card's inset, which the working row takes as the first row.
  static const EdgeInsets _replyPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  /// Where the line's words start, past the reply's inset and the icon.
  static double labelStart({required BuildContext context}) =>
      _replyPadding.left + TranscriptLiveSparkle.size + context.prego.spacing.md;

  @override
  Widget build(BuildContext context) {
    final color = context.prego.colors.textSecondary;
    final detail = this.detail;
    return Padding(
      padding:
          (followsReply ? _replyPadding.copyWith(top: 0, bottom: 0) : _replyPadding) +
          const EdgeInsets.symmetric(vertical: TranscriptStepRow.stepGap),
      child: TranscriptStepRow(
        maxLines: detail == null ? 1 : 2,
        leading: Icon(icon, size: PregoIconSize.sm, color: color),
        label: label,
        detail: detail == null ? null : TextSpan(text: "· $detail"),
        live: false,
        color: null,
        trailing: null,
      ),
    );
  }
}

/// The line that ends a turn a bridge stop cut off, with Continue under it
/// while the turn can still be picked up. Continue folds away under the line
/// once it can no longer be, such as when its prompt's bubble appears.
class const InterruptedTurnLine({
  super.key,

  /// Whether a reply shows above it, whose inset it then shares.
  required final bool followsReply,

  /// Sends the prompt that continues the turn; null hides Continue.
  required final VoidCallback? onContinue,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final onContinue = this.onContinue;
    return TranscriptPresenceColumn(
      children: [
        TurnEndLine(
          key: const ValueKey("line"),
          // The Stopped line's icon, since the stop cut the turn off.
          icon: TablerSolid.circle_x,
          label: loc.sessionDetailTurnInterrupted,
          detail: loc.sessionDetailTurnInterruptedReason,
          followsReply: followsReply,
        ),
        if (onContinue != null)
          Padding(
            key: const ValueKey("continue"),
            padding: EdgeInsetsDirectional.only(
              start: TurnEndLine.labelStart(context: context),
              bottom: TranscriptStepRow.stepGap,
            ),
            child: PregoButtonsSolid(
              label: loc.sessionDetailContinueInterruptedTurn,
              hierarchy: PregoButtonsSolidHierarchy.link,
              size: PregoButtonsSolidSize.sm,
              onPressed: onContinue,
            ),
          ),
      ],
    );
  }
}
