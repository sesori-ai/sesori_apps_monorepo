import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "transcript_live_row.dart";

/// A folded turn's one line, in a step group summary's style: a glyph, then
/// what the turn did and how it ended. Screen readers read the same [label].
class const TranscriptTurnStub({super.key, required final TranscriptTurn turn}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final glyph = switch (turn) {
      TranscriptPromptTurn(summary: TranscriptTurnSummary(outcome: TranscriptTurnRunning())) =>
        const TranscriptLiveSparkle(),
      TranscriptPromptTurn(summary: TranscriptTurnSummary(outcome: TranscriptTurnFailed())) => Icon(
        TablerSolid.alert_circle,
        size: PregoIconSize.sm,
        color: prego.colors.fgErrorPrimary,
      ),
      TranscriptPromptTurn() || TranscriptPartialTurn() || TranscriptPreamble() => Icon(
        TablerRegular.chevron_right,
        size: PregoIconSize.sm,
        color: style.color,
      ),
    };
    // As tall as a step group's summary, which is a button at the theme's
    // density.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 44 + Theme.of(context).visualDensity.baseSizeAdjustment.dy),
        child: Row(
          children: [
            SizedBox.square(
              dimension: TranscriptLiveSparkle.size,
              child: Center(child: glyph),
            ),
            SizedBox(width: prego.spacing.md),
            Expanded(
              child: Text(
                label(loc: context.loc, turn: turn),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The line [turn] shows folded.
  static String label({required AppLocalizations loc, required TranscriptTurn turn}) {
    final summary = turn.summary;
    final steps = loc.transcriptTurnSteps(summary.steps);
    return switch (turn) {
      TranscriptPartialTurn() => "${loc.transcriptTurnPartlyLoaded} · $steps",
      TranscriptPreamble() => "${loc.transcriptTurnBeforeFirstPrompt} · $steps",
      TranscriptPromptTurn(:final duration) => switch (summary.outcome) {
        TranscriptTurnRunning() when summary.steps == 0 => loc.transcriptTurnRunning,
        TranscriptTurnRunning() => loc.transcriptTurnRunningStep(summary.steps),
        TranscriptTurnFailed(:final errorLine) => [loc.transcriptTurnFailed, ?errorLine].join(" · "),
        TranscriptTurnDone(:final answerLine) => [
          [steps, if (duration != null) _duration(loc: loc, duration: duration)].join(" · "),
          ?answerLine,
        ].join(" — "),
      },
    };
  }

  /// Reads like "42s", "1m 02s" or "1h 05m".
  static String _duration({required AppLocalizations loc, required Duration duration}) {
    if (duration.inMinutes < 1) return loc.transcriptTurnSeconds(duration.inSeconds);
    if (duration.inHours < 1) {
      return loc.transcriptTurnMinutes(duration.inMinutes, "${duration.inSeconds % 60}".padLeft(2, "0"));
    }
    return loc.transcriptTurnHours(duration.inHours, "${duration.inMinutes % 60}".padLeft(2, "0"));
  }
}
