import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// The left-aligned title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component's "Back Leading" type: a [title] line
/// in `text-lg / bold / text-primary` over an optional caller-composed
/// [subtitle] widget (typically a [PregoNavSubtitle]).
///
/// Both lines are start-aligned; the title is clipped to a single ellipsised
/// line.
///
/// Rendered by [PregoTopNavigation] in its
/// [PregoTopNavigationTitleMode.backLeading] mode, sitting beside the back
/// button (when there is one) and bounded by the remaining bar width.
class const PregoNavLeadingTitle({
  super.key,

  /// First line.
  required final String title,

  /// Second line — a self-contained row widget such as [PregoNavSubtitle].
  /// Null renders the title on its own.
  required final Widget? subtitle,
}) extends StatelessWidget {
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
          // A tight single-line leading keeps the two-line block inside the
          // 54pt bar up to 250% text scale; the token's 28pt paragraph leading
          // is dead space here.
          style: prego.textTheme.textLg.bold.copyWith(color: prego.colors.textPrimary, height: 1.15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ?subtitle,
      ],
    );
  }
}
