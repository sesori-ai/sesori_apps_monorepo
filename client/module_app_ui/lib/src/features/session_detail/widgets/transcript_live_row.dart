import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "transcript_duration_formatter.dart";
import "transcript_elapsed_time.dart";

/// The turning sparkle that leads every live row of the transcript. Reduced
/// motion keeps it still.
class const TranscriptLiveSparkle({super.key}) extends StatelessWidget {
  static const double size = 20;

  @override
  Widget build(BuildContext context) =>
      PregoAiLoader(size: size, fillMode: .outline, color: context.prego.colors.textSecondary);
}

/// A live row's label. A primary-text band sweeps across the label in the
/// tertiary text colour, so it reads in both themes. Reduced motion keeps the
/// label still in its own colour.
class const TranscriptLiveLabel({super.key, required final Widget label, required final String? semanticLabel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: PregoShimmer(
      appearDelay: Duration.zero,
      baseColor: context.prego.colors.textTertiary,
      highlightColor: context.prego.colors.textPrimary,
      semanticLabel: semanticLabel,
      child: label,
    ),
  );
}

/// The one line every step kind shows, so all of them line up: the status
/// icon, or the live sparkle, centred in a sparkle-sized slot, then the step's
/// bold label and its detail. A one-line row stands as tall as a button at the
/// theme's density, so tappable and inert rows match.
class const TranscriptStepRow({
  super.key,
  required final Widget leading,
  required final String label,
  required final TextSpan? detail,

  /// Shimmers the text; a live row leads with [TranscriptLiveSparkle].
  required final bool live,

  /// Replaces the secondary text colour, such as a failed shell's red line.
  required final Color? color,

  /// Under the label, such as a streaming thought's latest words.
  required final Widget? below,
}) extends StatelessWidget {
  /// Every label starts with a capital, a raw tool name too. Only the label:
  /// the detail keeps its own case.
  static String capitalize({required String label}) =>
      label.characters.take(1).toUpperCase().string + label.characters.skip(1).string;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = this.color ?? prego.colors.textSecondary;
    final detail = this.detail;
    final below = this.below;
    final span = TextSpan(
      children: [
        TextSpan(
          text: capitalize(label: label),
          style: prego.textTheme.textSm.bold.copyWith(color: color),
        ),
        if (detail != null) ...[const TextSpan(text: " "), detail],
      ],
    );
    final text = Text.rich(
      span,
      style: prego.textTheme.textSm.regular.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // A button's 44 px minimum, adjusted for density as the button adjusts it.
    final height = 44 + Theme.of(context).visualDensity.baseSizeAdjustment.dy;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (height - TranscriptLiveSparkle.size) / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: TranscriptLiveSparkle.size,
                child: Center(child: leading),
              ),
              SizedBox(width: prego.spacing.md),
              Expanded(
                // The text reads in place, as a settled row's does, so a row
                // that merges its semantics announces the label first.
                child: live
                    ? Semantics(
                        label: span.toPlainText(),
                        child: TranscriptLiveLabel(label: text, semanticLabel: null),
                      )
                    : text,
              ),
            ],
          ),
          if (below != null)
            Padding(
              padding: EdgeInsetsDirectional.only(start: TranscriptLiveSparkle.size + prego.spacing.md),
              child: below,
            ),
        ],
      ),
    );
  }
}

/// The live row at the newest end of the transcript while the session works
/// and no step is live: before the first token and between steps. With a
/// known [sinceMs], the prompt's sent time, it ticks the time since.
class const TranscriptWorkingRow({super.key, required final int? sinceMs}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final working = loc.sessionDetailWorking;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final sinceMs = this.sinceMs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const TranscriptLiveSparkle(),
          SizedBox(width: prego.spacing.md),
          Expanded(
            // The label replaces the ticking text for screen readers, so the
            // time is read as of this build instead of every second.
            child: sinceMs == null
                ? TranscriptLiveLabel(
                    label: Text(working, style: style),
                    semanticLabel: working,
                  )
                : TranscriptLiveLabel(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      // In a narrow row "Working…" gives way and the time stays whole.
                      children: [
                        Flexible(
                          child: Text("$working · ", style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        TranscriptElapsedTime(sinceMs: sinceMs, style: style),
                      ],
                    ),
                    semanticLabel: "$working · ${_elapsed(loc: loc, sinceMs: sinceMs)}",
                  ),
          ),
        ],
      ),
    );
  }

  static String _elapsed({required AppLocalizations loc, required int sinceMs}) => TranscriptDurationFormatter.format(
    loc: loc,
    duration: Duration(milliseconds: clock.now().millisecondsSinceEpoch - sinceMs),
  );
}

/// The live row while only sub-agents work: a spinner, as on the composer's
/// sub-agent pill, never the sparkle, since the main agent is not working.
/// With a known [sinceMs], when the earliest running sub-agent started, the
/// first line ticks the time since. The second line always shows, so the row
/// keeps its height as the count or the time changes.
class const TranscriptSubAgentsRow({super.key, required final int count, required final int? sinceMs})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final running = loc.transcriptSubAgentsRunning(count);
    final keepChatting = loc.transcriptSubAgentsKeepChatting;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final sinceMs = this.sinceMs;
    final firstLine = sinceMs == null
        ? running
        : "$running · ${TranscriptWorkingRow._elapsed(loc: loc, sinceMs: sinceMs)}";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // The label replaces the ticking text for screen readers, so the time is
      // read as of this build instead of every second.
      child: Semantics(
        label: "$firstLine\n$keepChatting",
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox.square(
              dimension: TranscriptLiveSparkle.size,
              child: PregoActivityIndicator(color: null),
            ),
            SizedBox(width: prego.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sinceMs == null)
                    Text(running, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)
                  else
                    Row(
                      // In a narrow row the count gives way and the time stays whole.
                      children: [
                        Flexible(
                          child: Text("$running · ", style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        TranscriptElapsedTime(sinceMs: sinceMs, style: style),
                      ],
                    ),
                  Text(
                    keepChatting,
                    style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
