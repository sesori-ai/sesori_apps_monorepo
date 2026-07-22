import "package:flutter/material.dart";

import "../../module_prego.dart";

/// How much visual weight a [PregoNavLeadingTitle] gives its title line.
enum PregoNavLeadingTitleEmphasis {
  /// `text-sm / medium / text-secondary` — the sessions-list instantiation
  /// (Figma node 2386:11558), where a back button leads the block and the
  /// page content carries the emphasis.
  muted,

  /// `text-md / medium / text-primary` — the Projects-page instantiation
  /// (Figma node 2459:26970), where the block leads the bar with no back
  /// button and is the page's own title.
  prominent,
}

/// The left-aligned title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component's "Back Leading" type: a [title] line
/// over an optional caller-composed [subtitle] widget (typically a
/// [PregoNavSubtitle]).
///
/// Both lines are start-aligned; the title is clipped to a single ellipsised
/// line. [emphasis] selects between the design's two instantiations of the
/// title line — see [PregoNavLeadingTitleEmphasis].
///
/// Rendered by [PregoTopNavigation] in its
/// [PregoTopNavigationTitleMode.backLeading] mode, sitting beside the back
/// button (when there is one) and bounded by the remaining bar width.
class PregoNavLeadingTitle extends StatelessWidget {
  const PregoNavLeadingTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.emphasis = PregoNavLeadingTitleEmphasis.muted,
  });

  /// First line; styled per [emphasis].
  final String title;

  /// How much weight the title line carries. Defaults to
  /// [PregoNavLeadingTitleEmphasis.muted].
  final PregoNavLeadingTitleEmphasis emphasis;

  /// Second line — a self-contained row widget such as [PregoNavSubtitle].
  /// Null renders the title on its own.
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PregoSpacing.xs,
      children: [
        Text(
          title,
          style: switch (emphasis) {
            PregoNavLeadingTitleEmphasis.muted => prego.textTheme.textSm.medium.copyWith(
              color: prego.colors.textSecondary,
            ),
            PregoNavLeadingTitleEmphasis.prominent => prego.textTheme.textMd.medium.copyWith(
              color: prego.colors.textPrimary,
            ),
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ?subtitle,
      ],
    );
  }
}
