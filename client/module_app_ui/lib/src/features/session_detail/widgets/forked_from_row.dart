import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_live_row.dart";

/// The quiet centred line above a fork's oldest message: "Forked from"
/// and the origin's title. A tap goes back to the origin; once the origin is deleted the
/// line stays as plain text.
class const ForkedFromRow({
  super.key,
  required final SessionForkOrigin origin,

  /// Returns to the origin, once it is known to still have an id.
  required final void Function({required String sessionId, required String? sessionTitle}) onOpenOrigin,
}) extends StatelessWidget {
  /// The row's height: the minimum tap target, as the handoff line has.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final color = prego.colors.textSecondary;
    final title = origin.title?.trim();
    final label = title == null || title.isEmpty ? loc.transcriptForkedFromUntitled : loc.transcriptForkedFrom(title);
    final sessionId = origin.sessionId;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: TranscriptLiveSparkle.size,
          child: Icon(TablerRegular.git_fork, size: PregoIconSize.sm, color: color),
        ),
        const SizedBox(width: PregoSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.regular.copyWith(color: color),
          ),
        ),
        if (sessionId != null) Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: color),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: SizedBox(
        height: height,
        child: Center(
          // A deleted origin's line is plain text, not a dimmed button.
          child: switch (sessionId) {
            null => Padding(
              key: const ValueKey("forked-from-row"),
              padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
              child: content,
            ),
            final sessionId => TextButton(
              key: const ValueKey("forked-from-row"),
              onPressed: () => onOpenOrigin(sessionId: sessionId, sessionTitle: origin.title),
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
                minimumSize: const Size(44, height),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
              ),
              child: content,
            ),
          },
        ),
      ),
    );
  }
}
