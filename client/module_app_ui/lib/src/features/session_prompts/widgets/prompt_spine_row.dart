import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../prompt_search.dart";

const double _kVerticalPadding = PregoSpacing.md;
const double _kRailX = PregoSpacing.xl + 4;
const double _kFollowUpIndent = PregoSpacing.xl;
const double _kExcerptGap = PregoSpacing.xxs;

double _lineExtent({required TextScaler textScaler}) => textScaler.scale(_kTextSize) * _kLineHeight / _kTextSize;

/// The fixed height of every [PromptSpineRow] at [textScaler]: one line of
/// its text plus padding. Fixed, so the list can place a row by arithmetic.
double promptRowExtent({required TextScaler textScaler}) => _lineExtent(textScaler: textScaler) + _kVerticalPadding * 2;

/// What a row grown to show its search excerpt adds to [promptRowExtent].
double promptExcerptExtent({required TextScaler textScaler}) =>
    textScaler.scale(_kExcerptSize) * _kExcerptLineHeight / _kExcerptSize + _kExcerptGap;

const double _kTextSize = 14;
const double _kLineHeight = 20;
const double _kExcerptSize = 12;
const double _kExcerptLineHeight = 18;

/// One prompt on the Prompts screen: a dot on the spine rail that runs down
/// the list, then its number, its first line and its time. A follow-up's dot
/// sits indented off the rail, smaller and fainter, under the prompt it joined.
/// A search match adds a second line: the words around it, highlighted.
class const PromptSpineRow({
  super.key,
  required final TranscriptPromptEntry entry,

  /// Whether to show the time cell at all; false when nothing in the list has
  /// a time.
  required final bool showsTime,

  /// Whether this is the prompt the screen opened on, which keeps a tint.
  required final bool highlighted,

  /// Where the search found this prompt; null while not searching.
  required final PromptExcerpt? excerpt,

  /// How far [excerpt] has faded in, from 0 to 1, while the row grows to
  /// show it. The list sets the row's height; whatever does not fit is cut.
  required final double grown,
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
    final excerpt = this.excerpt;
    final label = [
      ?number?.toString(),
      isFollowUp ? loc.transcriptPromptsFollowUp(text) : text,
      if (excerpt != null) "${excerpt.before}${excerpt.match}${excerpt.after}",
      ?time,
    ].join(", ");
    final dotSize = isFollowUp ? 5.0 : 7.0;
    final dotX = isFollowUp ? _kRailX + _kFollowUpIndent : _kRailX;
    final excerptStyle = prego.textTheme.textXs.regular.copyWith(color: colors.textTertiary);
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
                top: _kVerticalPadding,
                height: _lineExtent(textScaler: MediaQuery.textScalerOf(context)),
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
              // Laid out at full height from the top, so a row the list is
              // still growing or folding away cuts its bottom rather than
              // squeezing its lines.
              PositionedDirectional(
                start: dotX + PregoSpacing.xl,
                end: PregoSpacing.xl,
                top: _kVerticalPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                            child: Text(
                              time,
                              style: prego.textTheme.textSm.regular.copyWith(color: colors.textTertiary),
                            ),
                          ),
                      ],
                    ),
                    if (excerpt != null && grown > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: _kExcerptGap),
                        child: Opacity(
                          opacity: grown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: excerpt.before),
                                TextSpan(
                                  text: excerpt.match,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    backgroundColor: colors.bgBrandSecondary,
                                  ),
                                ),
                                TextSpan(text: excerpt.after),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: excerptStyle,
                          ),
                        ),
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
