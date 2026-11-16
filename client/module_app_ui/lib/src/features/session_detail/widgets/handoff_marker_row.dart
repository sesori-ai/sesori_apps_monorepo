import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "handoff_session_link.dart";
import "transcript_live_row.dart";
import "transcript_markdown_sheet.dart";
import "transcript_motion.dart";

/// The centred line a summary request's turn folds into in the source
/// session: "Writing a summary for `<target>`…" while the agent writes it, then
/// "Summary sent to `<target>` · Open", or "Couldn't send to `<target>`".
///
/// It keeps one height in every state, and only its words and icon cross-fade,
/// so nothing around it moves when the turn ends. Tapping the line opens the
/// agent's reply in a sheet once the turn has ended; Open opens the target.
class const HandoffMarkerRow({super.key, required final TranscriptHandoffMarker marker}) extends StatelessWidget {
  /// The row's one height: the minimum tap target, so Open is easy to hit.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final color = prego.colors.textSecondary;
    final style = prego.textTheme.textSm.regular.copyWith(color: color);
    final target = handoffSessionName(context: context, title: marker.targetTitle);
    final status = marker.status;
    final label = switch (status) {
      TranscriptHandoffMarkerStatus.writing => loc.transcriptHandoffWriting(target),
      TranscriptHandoffMarkerStatus.sent => loc.transcriptHandoffSent(target),
      TranscriptHandoffMarkerStatus.notSent => loc.transcriptHandoffNotSent(target),
    };
    final summary = marker.summary;
    final duration = context.isReducedMotion ? Duration.zero : transcriptMotionDuration;
    final showsOpen = status == TranscriptHandoffMarkerStatus.sent;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: TranscriptLiveSparkle.size,
          child: AnimatedSwitcher(
            duration: duration,
            child: switch (status) {
              TranscriptHandoffMarkerStatus.writing => const TranscriptLiveSparkle(key: ValueKey("handoff.live")),
              TranscriptHandoffMarkerStatus.sent => Icon(
                TablerRegular.send,
                key: const ValueKey("handoff.sent"),
                size: PregoIconSize.sm,
                color: color,
              ),
              TranscriptHandoffMarkerStatus.notSent => Icon(
                TablerRegular.alert_circle,
                key: const ValueKey("handoff.notSent"),
                size: PregoIconSize.sm,
                color: color,
              ),
            },
          ),
        ),
        const SizedBox(width: PregoSpacing.sm),
        Flexible(
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(status),
              child: switch (status) {
                // Not the live row's label, which fills its line: this one stays centred.
                TranscriptHandoffMarkerStatus.writing => PregoShimmer(
                  appearDelay: Duration.zero,
                  baseColor: color,
                  highlightColor: prego.colors.textPrimary,
                  semanticLabel: label,
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                ),
                TranscriptHandoffMarkerStatus.sent || TranscriptHandoffMarkerStatus.notSent => Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              },
            ),
          ),
        ),
      ],
    );
    final canShowSummary = summary != null && status != TranscriptHandoffMarkerStatus.writing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: SizedBox(
        height: height,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: TextButton(
                  key: const ValueKey("handoff-marker.summary"),
                  onPressed: canShowSummary ? () => _showSummary(context: context, summary: summary) : null,
                  style: _lineStyle(color: color),
                  child: line,
                ),
              ),
              // Eases its width in, so the centred line slides over instead of jumping.
              AnimatedSize(
                duration: duration,
                curve: transcriptMotionCurve,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: showsOpen ? 1 : 0,
                  child: showsOpen
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(" · ", style: style),
                            TextButton(
                              key: const ValueKey("handoff-marker.open"),
                              onPressed: () => openHandoffSession(context: context, sessionId: marker.targetSessionId),
                              style: _lineStyle(color: prego.colors.textBrandPrimary),
                              child: Text(
                                loc.transcriptHandoffOpen,
                                style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textBrandPrimary),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ButtonStyle _lineStyle({required Color color}) => TextButton.styleFrom(
    foregroundColor: color,
    disabledForegroundColor: color,
    padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
    minimumSize: const Size(44, height),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
  );

  static Future<void> _showSummary({required BuildContext context, required String summary}) =>
      showTranscriptMarkdownSheet(
        context: context,
        title: context.loc.transcriptHandoffSummaryTitle,
        markdown: summary,
      );
}
