import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

const double _kVerticalPadding = PregoSpacing.md;
const double _kRailX = PregoSpacing.xl + 4;
const double _kFollowUpIndent = PregoSpacing.xl;

/// The fixed height of every [PromptSpineRow] at [textScaler]: one line of
/// its text plus padding. Fixed, so the list can place a row by arithmetic.
double promptRowExtent({required TextScaler textScaler}) =>
    textScaler.scale(_kTextSize) * _kLineHeight / _kTextSize + _kVerticalPadding * 2;

const double _kTextSize = 14;
const double _kLineHeight = 20;

/// One prompt on the Prompts screen: a dot on the spine rail that runs down
/// the list, then its number, its first line and its time. A follow-up's dot
/// sits indented off the rail, smaller and fainter, under the prompt it joined.
class const PromptSpineRow({
  super.key,
  required final TranscriptPromptEntry entry,

  /// Whether to show the time cell at all; false when nothing in the list has
  /// a time.
  required final bool showsTime,

  /// Whether this is the prompt the screen opened on, which keeps a tint.
  required final bool highlighted,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;
    final isFollowUp = entry is TranscriptPromptFollowUp;
    final text = entry.text ?? loc.transcriptStickyPromptAttachment;
    final time = switch (entry.createdAt) {
      final createdAt? when showsTime => context.formatTimeOfDay(createdAt),
      _ => null,
    };
    final number = entry.number;
    final label = [
      ?number?.toString(),
      isFollowUp ? loc.transcriptPromptsFollowUp(text) : text,
      ?time,
    ].join(", ");
    final dotSize = isFollowUp ? 5.0 : 7.0;
    final dotX = isFollowUp ? _kRailX + _kFollowUpIndent : _kRailX;
    return Semantics(
      container: true,
      button: true,
      label: label,
      hint: loc.transcriptStickyPromptJumpHint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: highlighted ? colors.bgSecondary : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              PositionedDirectional(
                start: _kRailX,
                top: 0,
                bottom: 0,
                child: SizedBox(width: 1, child: ColoredBox(color: colors.borderSecondary)),
              ),
              PositionedDirectional(
                start: dotX + 0.5 - dotSize / 2,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFollowUp ? colors.fgQuaternary : colors.fgTertiary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: dotX + PregoSpacing.xl,
                  end: PregoSpacing.xl,
                  top: _kVerticalPadding,
                  bottom: _kVerticalPadding,
                ),
                child: Row(
                  children: [
                    if (number != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: PregoSpacing.md),
                        child: Text(
                          "$number",
                          style: prego.textTheme.textSm.medium.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: prego.textTheme.textSm.regular.copyWith(
                          color: isFollowUp ? colors.textSecondary : colors.textPrimary,
                        ),
                      ),
                    ),
                    if (time != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: PregoSpacing.lg),
                        child: Text(time, style: prego.textTheme.textSm.regular.copyWith(color: colors.textTertiary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
