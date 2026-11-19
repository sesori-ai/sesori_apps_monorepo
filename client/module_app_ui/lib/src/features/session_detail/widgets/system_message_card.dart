import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "assistant_message_card.dart";

/// A neutral inline surface for transcript messages authored by automation,
/// tagged with who wrote it.
class const SystemMessageCard({
  super.key,
  required final IconData tagIcon,
  required final String tagLabel,
  required final String? projectId,
  required final List<TranscriptBlock> blocks,
  required final Map<String, String> streamingText,
  required final int? createdAtMs,

  /// Opens what the message is about, such as the page a Sesori notice
  /// answers; null leaves the card a plain, untappable surface.
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final onTap = this.onTap;
    final borderRadius = BorderRadius.circular(PregoRadius.x2l);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PregoTag(icon: tagIcon, label: tagLabel),
        const SizedBox(height: PregoSpacing.md),
        AssistantMessageCard(
          projectId: projectId,
          blocks: blocks,
          streamingText: streamingText,
          createdAtMs: createdAtMs,
          contentPadding: EdgeInsets.zero,
          selectionArea: null,
          // A background report is usually one sub-agent or task; its
          // row says what ran without a tap.
          showsLoneStep: true,
        ),
      ],
    );

    final card = PregoTappable(
      onTap: onTap,
      borderRadius: borderRadius,
      containerBuilder: (child) => DecoratedBox(
        decoration: BoxDecoration(
          color: prego.colors.bgSecondary,
          border: Border.all(color: prego.colors.borderSecondary),
          borderRadius: borderRadius,
        ),
        child: child,
      ),
      // The padding sits inside the press feedback, so it fills the card.
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.lg),
        child: switch (onTap) {
          null => content,
          // The chevron says the card opens something, as a list row's does.
          _ => Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: PregoSpacing.md),
              Icon(TablerRegular.chevron_right, size: PregoIconSize.md, color: prego.colors.textTertiary),
            ],
          ),
        },
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PregoSpacing.xl,
        vertical: PregoSpacing.xs,
      ),
      child: onTap == null ? card : Semantics(button: true, child: card),
    );
  }
}
