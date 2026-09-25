import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

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

/// The live row at the newest end of the transcript while the session works
/// and no step is live: before the first token and between steps.
class const TranscriptWorkingRow({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final label = context.loc.sessionDetailWorking;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const TranscriptLiveSparkle(),
          SizedBox(width: prego.spacing.md),
          Expanded(
            child: TranscriptLiveLabel(
              label: Text(label, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
              semanticLabel: label,
            ),
          ),
        ],
      ),
    );
  }
}
