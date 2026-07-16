import "package:flutter/material.dart";

import "../../module_prego.dart";

/// The left-aligned title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component's "Back Leading" type as instantiated
/// on the sessions list (node 2386:11558): a muted [title] line over an
/// optional caller-composed [subtitle] widget (typically a
/// [PregoNavSubtitle]).
///
/// Both lines are start-aligned; the title is clipped to a single ellipsised
/// line. The whole block is deliberately muted (`text-secondary`): in this
/// bar type the page content carries the visual emphasis and the bar only
/// identifies context.
///
/// Rendered by [PregoTopNavigation] in its
/// [PregoTopNavigationTitleMode.backLeading] mode, sitting beside the back
/// button and bounded by the remaining bar width.
class PregoNavLeadingTitle extends StatelessWidget {
  const PregoNavLeadingTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  /// First line, in `text-sm / medium / text-secondary`.
  final String title;

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
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ?subtitle,
      ],
    );
  }
}
