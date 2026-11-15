import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, ModelOrbits;
import "package:theme_prego/module_prego.dart";

/// The touch composer's model and effort control: the same pill as the
/// composer's other pickers, reading `Opus 5.5 · High`, with a small bolt while
/// fast mode is on and the pickers' selector caret.
///
/// A new model, level or speed cross-fades in while the pill eases to its new
/// width, so nothing snaps.
class const ModelEffortChip({
  super.key,
  required final ModelOrbits orbits,
  required final bool fast,

  /// Whether the selector caret shows. A read-only chip keeps the caret's
  /// room, so the pill never changes width as the composer turns live.
  required final bool showsCaret,

  /// The composer's outline treatment, which the chip shares with the pills.
  required final PregoComposerSurfaceStyle surfaceStyle,
}) extends StatelessWidget {
  /// The height of the composer's touch pills, so the row never jumps.
  static const double height = 36;

  static const _change = Duration(milliseconds: 220);
  static const double _boltGap = 4;
  static const double _boltWidth = _boltGap + PregoIconSize.sm;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final style = prego.textTheme.textXs.medium;
    final level = orbits.currentLevel;
    final name = orbits.current.name;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: pregoComposerSurfaceDecoration(prego: prego, style: surfaceStyle, borderRadius: borderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 1, 13, 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedSize(
                  duration: _change,
                  curve: Curves.easeInOut,
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedSwitcher(
                    duration: _change,
                    layoutBuilder: _layOutFaces,
                    // Text sized to its content, so the chip hugs it. When
                    // large text leaves too little room, the level takes at
                    // most half of what the bolt leaves and the name the rest,
                    // so neither hides the other. The name keeps its end, which
                    // tells models apart, behind a leading ellipsis, as the
                    // pills' labels do.
                    child: LayoutBuilder(
                      key: ValueKey((name, level, fast)),
                      builder: (context, constraints) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: IntrinsicWidth(
                              child: PregoEllipsisText(
                                text: name,
                                ellipsis: PregoEllipsis.start,
                                style: style.copyWith(color: colors.textPrimary),
                              ),
                            ),
                          ),
                          if (level != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(0, constraints.maxWidth - (fast ? _boltWidth : 0)) / 2,
                              ),
                              child: Text(
                                " · ${_levelWord(level: level)}",
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: style.copyWith(color: colors.textTertiary),
                              ),
                            ),
                          if (fast) ...[
                            const SizedBox(width: _boltGap),
                            Icon(TablerRegular.bolt, size: PregoIconSize.sm, color: colors.textPrimary),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedOpacity(
                opacity: showsCaret ? 1 : 0,
                duration: _change,
                child: Icon(TablerRegular.selector, size: PregoIconSize.sm, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sizes the switcher to the incoming face only, so the pill eases straight
  /// to its new width.
  static Widget _layOutFaces(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: [
      // The outgoing face fades out within the incoming one's width, cutting
      // its text again, so it never paints over the caret or the next pill.
      for (final face in previous) PositionedDirectional(start: 0, end: 0, top: 0, bottom: 0, child: face),
      ?current,
    ],
  );
}

/// The level as the chip names it: the ladder word with a capital, `High`.
String _levelWord({required EffortLevel level}) {
  final word = level.wireId;
  return word.substring(0, 1).toUpperCase() + word.substring(1);
}
