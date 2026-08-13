/// Grouped surface primitives for the Prego design system.
///
/// Cards and list tiles use one solid Material implementation on every platform.
/// Dividers remain platform-aware by default for standalone glass surfaces, and
/// can be forced flat when composed into a solid card.
///
/// [PregoCard] / [PregoListTile] / [PregoDivider] compose into grouped-list
/// cards such as the background-tasks card.
library;

import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";

/// The two outline treatments used by the composer and its adjacent surfaces.
enum PregoComposerSurfaceStyle() { subtle, emphasized }

/// Builds the shared solid decoration used by the composer, picker pills, and
/// background-task card.
BoxDecoration pregoComposerSurfaceDecoration({
  required PregoDesignSystem prego,
  required PregoComposerSurfaceStyle style,
  required BorderRadius borderRadius,
}) {
  final borderColor = switch (style) {
    PregoComposerSurfaceStyle.subtle => prego.colors.borderSecondary,
    PregoComposerSurfaceStyle.emphasized => prego.colors.borderPrimary,
  };
  return BoxDecoration(
    color: prego.colors.bgSurface2,
    borderRadius: borderRadius,
    border: Border.all(color: borderColor),
    boxShadow: prego.shadows.xs,
  );
}

/// A rounded, elevated surface that hosts grouped content.
///
/// Uses the same fill, border, and elevation as the composer on every platform.
class const PregoCard({
    super.key,
    required final Widget child,
    required final PregoComposerSurfaceStyle surfaceStyle,
    /// Corner radius of the card.
  final double borderRadius = 20,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: pregoComposerSurfaceDecoration(
        prego: prego,
        style: surfaceStyle,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }
}

/// A thin separator between grouped rows.
///
/// Apple: a frosted hairline ([GlassDivider]). Android: a flat [Divider] tinted
/// with the secondary border colour. Decorative on both paths (hidden from
/// screen readers).
class const PregoDivider({
    super.key,
    /// Empty space leading the line on the left.
  final double indent = 0,
    /// Empty space trailing the line on the right.
  final double endIndent = 0,
    /// Total cross-axis space the divider occupies. Defaults to 1.0.
  final double? height,
    /// Forces the solid divider used inside [PregoCard] on every platform.
  final bool flat = false,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!flat && glassEffectsEnabled()) {
      return GlassDivider(indent: indent, endIndent: endIndent, height: height ?? 1.0);
    }

    // Mirror GlassDivider's flat shape: the inset is padding around an
    // un-indented Divider so the coloured line itself starts after [indent].
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
        child: Divider(
          height: height ?? 1.0,
          thickness: 0.5,
          color: context.prego.colors.borderSecondary,
        ),
      ),
    );
  }
}

/// A grouped-list row: leading slot, title (+ optional subtitle), trailing slot,
/// with press feedback and an optional bottom divider.
///
/// Uses one [InkWell] row on every platform: 32px leading box, 12px gap,
/// title/subtitle column, and trailing content. The row composes a flat
/// [PregoDivider] below itself unless it is the last row.
class const PregoListTile({
    super.key,
    final Widget? leading,
    required final Widget title,
    final Widget? subtitle,
    final Widget? trailing,
    final VoidCallback? onTap,
    /// Whether this is the last row in its group; suppresses the bottom divider.
  final bool isLast = false,
    /// Whether to draw a [PregoDivider] below this row. Ignored when [isLast].
  final bool showDivider = true,
    final EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    final Color? leadingIconColor,
    final TextStyle? titleStyle,
    final TextStyle? subtitleStyle,
    /// Leading indent of the bottom divider. Defaults to 56 when a [leading]
  /// widget is present (aligning the line under the title), 16 otherwise.
  final double? dividerIndent,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tile = _buildFlat(context);

    if (showDivider && !isLast) {
      final indent = dividerIndent ?? (leading != null ? 56.0 : 16.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile,
          PregoDivider(indent: indent, flat: true),
        ],
      );
    }

    return tile;
  }

  Widget _buildFlat(BuildContext context) {
    final prego = context.prego;
    final labelColor = prego.colors.textPrimary;
    final effectiveTitleStyle = titleStyle ?? prego.textTheme.textMd.medium.copyWith(color: labelColor);
    final effectiveSubtitleStyle =
        subtitleStyle ?? prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);

    final leading = this.leading;
    final subtitle = this.subtitle;
    final trailing = this.trailing;

    final row = Row(
      children: [
        if (leading != null) ...[
          IconTheme(
            data: IconThemeData(color: leadingIconColor ?? labelColor, size: 22),
            child: SizedBox(width: 32, child: leading),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(style: effectiveTitleStyle, child: title),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle(style: effectiveSubtitleStyle, child: subtitle),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          IconTheme(
            data: IconThemeData(color: prego.colors.textSecondary, size: 20),
            child: trailing,
          ),
        ],
      ],
    );

    Widget tile = Padding(padding: contentPadding, child: row);
    if (onTap != null) {
      tile = InkWell(onTap: onTap, child: tile);
    }

    return tile;
  }
}
