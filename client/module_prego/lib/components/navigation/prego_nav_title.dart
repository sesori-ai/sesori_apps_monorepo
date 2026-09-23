import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// The centred title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component (node 338:3274, style "Glass", type
/// "Middle Title").
///
/// Renders [title] in `text-lg / bold / text-primary` with an optional
/// [subtitle] in `text-xs / medium / text-tertiary` on a centred second line.
/// Both lines are centred and clipped to a single ellipsised line.
///
/// This is the top bar's centred title; the sheet header uses its own bolder,
/// leading-or-centred title block (see [PregoTopNavigationSheets]).
///
/// Used by [PregoTopNavigation] to render its fixed inline title, so the bar
/// title looks identical wherever the bar appears (including inside
/// [PregoGlassScaffold], which builds its bar from [PregoTopNavigation]).
class const PregoNavTitle({
  super.key,

  /// Primary title text.
  required final String title,

  /// Optional muted second line. A `null` or empty value renders the title on
  /// its own.
  final String? subtitle,
}) extends StatelessWidget {
  /// Line-height multiplier for a two-line title/subtitle block, overriding the
  /// design tokens' body-text leading (`text-lg` 1.56×, `text-xs` 1.5×).
  ///
  /// Those tokens are tuned for paragraph spacing; in this fixed-height bar they
  /// are pure dead space. With them, a title + subtitle stack measures
  /// 28 + 18 = 46pt of the 54pt bar (`PregoTopNavigation.barHeight`), so
  /// Android's slightly taller text metrics or a larger text scale tip the
  /// [Column] into a bottom overflow. These are centred single lines, so a
  /// normal single-line leading (≈ the font's natural height) looks identical
  /// glyph-wise while bringing the stack to ~(18 + 12) ×1.25 = 37.5pt, clearing
  /// the bar with margin on every platform.
  static const double _lineHeight = 1.25;

  /// Fits the 18pt title at 250% text scale into the 54pt inline toolbar.
  static const double _singleLineHeight = 1.2;

  /// The largest text scale at which the two-line block still fits the 54pt
  /// bar: (18 + 12) × 1.25 × 1.4 = 52.5pt. The title on its own keeps the
  /// user's full text scale.
  static const double _twoLineMaxTextScale = 1.4;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    final titleText = Text(
      title,
      style: prego.textTheme.textLg.bold.copyWith(
        color: prego.colors.textPrimary,
        height: subtitle == null || subtitle.isEmpty ? _singleLineHeight : _lineHeight,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    // A single line should receive the toolbar's bounds directly, rather than
    // an unbounded vertical constraint from a Column at large text scales.
    if (subtitle == null || subtitle.isEmpty) return titleText;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _twoLineMaxTextScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          titleText,
          Text(
            subtitle,
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary, height: _lineHeight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
