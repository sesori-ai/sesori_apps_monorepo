import "package:flutter/material.dart";

import "../../module_prego.dart";

/// The centred title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component (node 338:3274, style "Glass", type
/// "Middle Title").
///
/// Renders [title] in `text-lg / medium / text-primary` with an optional
/// [subtitle] in `text-md / medium / text-secondary` on a centred second line.
/// Both lines are centred and clipped to a single ellipsised line.
///
/// This is the top bar's centred title; the sheet header uses its own bolder,
/// leading-or-centred title block (see [PregoTopNavigationSheets]).
///
/// Used by [PregoTopNavigation] to render its fixed inline title, so the bar
/// title looks identical wherever the bar appears (including inside
/// [PregoGlassScaffold], which builds its bar from [PregoTopNavigation]).
class PregoNavTitle extends StatelessWidget {
  const PregoNavTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  /// Primary title text.
  final String title;

  /// Optional muted second line. A `null` or empty value renders the title on
  /// its own.
  final String? subtitle;

  /// Line-height multiplier for the bar's title and subtitle, overriding the
  /// design tokens' body-text leading (`text-lg` 1.56×, `text-md` 1.5×).
  ///
  /// Those tokens are tuned for paragraph spacing; in this fixed-height bar they
  /// are pure dead space. With them, a title + subtitle stack measures
  /// 28 + 24 = 52pt — only 2pt under the 54pt bar (`PregoTopNavigation.barHeight`),
  /// so Android's slightly taller text metrics tip the
  /// [Column] into a bottom overflow. These are centred single lines, so a
  /// normal single-line leading (≈ the font's natural height) looks identical
  /// glyph-wise while bringing the stack to ~18 + 16 ×1.25 = 42.5pt, clearing
  /// the bar with margin on every platform.
  static const double _lineHeight = 1.25;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: prego.textTheme.textLg.medium.copyWith(color: prego.colors.textPrimary, height: _lineHeight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
            style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textSecondary, height: _lineHeight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
