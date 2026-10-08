import "package:clock/clock.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/defer_until_route_open.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "text_part_widget.dart";
import "transcript_duration_formatter.dart";
import "transcript_elapsed_time.dart";
import "transcript_latest_words.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";
import "transcript_token_count_formatter.dart";

/// The transcript row of one context compaction. While it runs it is a live
/// "Compacting context" row ticking the time since [sinceMs], with the newest
/// streamed summary words fading in after it on the same line. It then
/// settles in place, keyed by its part, into the quiet "Context compacted" row
/// with any reported details, or a quiet "Compaction failed" note with any
/// known reason. Only the icon cross-fades and the words fade out, so the row
/// keeps its one-line height and nothing around it moves.
///
/// Tapping a compacted row opens its carried-forward summary; without one,
/// and while running or failed, the row is inert.
class const CompactionPartWidget({
  super.key,
  required final CompactionState state,

  /// When the compaction started, its message's creation in epoch ms; null
  /// when the harness reports no time, so the row shows no timer.
  required final int? sinceMs,

  /// The summary streamed so far, ahead of the part's own, or null.
  required final String? streamingText,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final color = prego.colors.textSecondary;
    final style = prego.textTheme.textSm.regular.copyWith(color: color);
    final sinceMs = this.sinceMs;
    final (:label, :detail, :spokenDetail, :icon) = switch (state) {
      CompactionStateRunning() => (
        label: loc.sessionDetailCompactingContext,
        detail: sinceMs == null
            ? null
            : TextSpan(
                children: [
                  const TextSpan(text: "· "),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    // The time ends the line, so its width moves nothing as it
                    // ticks. Satoshi's tabular figures are another glyph style.
                    child: TranscriptElapsedTime(sinceMs: sinceMs, style: style),
                  ),
                ],
              ),
        // Read as of this build instead of every second.
        spokenDetail: sinceMs == null
            ? null
            : TranscriptDurationFormatter.format(
                loc: loc,
                duration: Duration(milliseconds: clock.now().millisecondsSinceEpoch - sinceMs),
              ),
        icon: null,
      ),
      CompactionStateCompleted(:final freedTokens, :final trigger) => _settled(
        label: loc.sessionDetailContextCompacted,
        details: [
          if (freedTokens != null)
            loc.sessionDetailCompactionFreedTokens(TranscriptTokenCountFormatter.format(tokens: freedTokens)),
          // A manual compaction follows the user's own request, so only auto is named.
          if (trigger == CompactionTrigger.auto) loc.sessionDetailCompactionAuto,
        ],
        icon: TablerRegular.fold,
      ),
      CompactionStateFailed(:final reason) => _settled(
        label: loc.sessionDetailCompactionFailed,
        details: [
          ?switch (reason) {
            CompactionFailureReason.nothingToCompact => loc.sessionDetailCompactionNothingToCompact,
            CompactionFailureReason.alreadyCompacted => loc.sessionDetailCompactionAlreadyCompacted,
            CompactionFailureReason.cancelled => loc.sessionDetailCompactionCancelled,
            CompactionFailureReason.turnEnded => loc.sessionDetailCompactionTurnEnded,
            null => null,
          },
        ],
        icon: TablerRegular.alert_circle,
      ),
    };
    final summary = switch (state) {
      CompactionStateCompleted(:final summary) => summary,
      CompactionStateRunning() || CompactionStateFailed() => null,
    };
    final words = switch (state) {
      CompactionStateRunning(:final summary) => streamingText ?? summary,
      CompactionStateCompleted() || CompactionStateFailed() => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // One button in every state, so the row keeps its place and the icon
      // its switcher as the state changes.
      child: TextButton(
        onPressed: summary == null ? null : () => _showSummary(context: context, summary: summary),
        style: TextButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: AlignmentDirectional.centerStart,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
        ),
        child: Semantics(
          // The whole detail, which the line may ellipsize.
          label: [label, ?spokenDetail].join(" · "),
          excludeSemantics: true,
          child: TranscriptStepRow(
            leading: AnimatedSwitcher(
              duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
              child: icon == null
                  ? const TranscriptLiveSparkle(key: ValueKey("compaction.live"))
                  : Icon(icon, key: ValueKey(icon), size: PregoIconSize.sm, color: color),
            ),
            label: label,
            detail: detail,
            live: icon == null,
            color: null,
            trailing: TranscriptTrailingLatestWords(text: words, style: style),
          ),
        ),
      ),
    );
  }

  static ({String label, TextSpan? detail, String? spokenDetail, IconData? icon}) _settled({
    required String label,
    required List<String> details,
    required IconData icon,
  }) {
    final spokenDetail = details.isEmpty ? null : details.join(" · ");
    return (
      label: label,
      detail: spokenDetail == null ? null : TextSpan(text: "· $spokenDetail"),
      spokenDetail: spokenDetail,
      icon: icon,
    );
  }

  static Future<void> _showSummary({required BuildContext context, required String summary}) {
    final openExternalLink = SessionDetailPresentationScope.read(context).openExternalLink;
    return showPregoModal<void>(
      context: context,
      title: context.loc.sessionDetailCompactionSummaryTitle,
      width: PregoModalWidth.reading,
      builder: (modalContext) {
        final prego = modalContext.prego;
        return DeferUntilRouteOpen(
          contentLength: summary.length,
          child: PregoReadableSelectionArea(
            child: MarkdownBody(
              data: summary,
              selectable: false,
              blockSyntaxes: sessionMarkdownBlockSyntaxes,
              imageBuilder: (uri, title, alt) => MarkdownMessageImage(uri: uri, semanticLabel: alt),
              onTapLink: buildMarkdownLinkTapHandler(openExternalLink: openExternalLink),
              styleSheet: buildSessionMarkdownStyleSheet(
                prego: prego,
                paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ),
          ),
        );
      },
    );
  }
}
