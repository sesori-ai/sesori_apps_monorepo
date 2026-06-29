/// Platform-aware surface primitives for the Prego design system.
///
/// On Apple platforms these render as `liquid_glass_widgets` surfaces (the
/// iOS-26 frosted-glass language the app uses elsewhere). On Android — where the
/// glass shader + backdrop blur jank — they degrade to flat Material surfaces
/// tinted from the same prego tokens. The "glass" is a platform affordance, not
/// part of the contract: the same call site renders either path without knowing
/// which is active. See [glassEffectsEnabled] for the switch.
///
/// [PregoCard] / [PregoListTile] / [PregoDivider] compose into grouped-list
/// cards (e.g. the background-tasks card) exactly as their glass counterparts
/// [GlassContainer] / [GlassListTile] / [GlassDivider] do.
library;

import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";

/// A rounded, elevated surface that hosts grouped content.
///
/// Apple: a standalone liquid-glass layer ([GlassContainer]). Android: a flat
/// [Material] card filled with [flatColor] (a secondary surface by default),
/// hairline-bordered and shadowed to read as a floating card without a shader.
class PregoCard extends StatelessWidget {
  const PregoCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.glassColor,
    this.flatColor,
  });

  final Widget child;

  /// Corner radius of the card.
  final double borderRadius;

  /// Apple glass tint. Defaults to the primary glass background.
  final Color? glassColor;

  /// Android flat fill. Defaults to the secondary surface colour.
  final Color? flatColor;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    if (glassEffectsEnabled()) {
      return GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        settings: LiquidGlassSettings(glassColor: glassColor ?? prego.colors.buttonGlassPrimaryBackground),
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: prego.shadows.xl,
      ),
      child: Material(
        color: flatColor ?? prego.colors.bgSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: prego.colors.borderSecondary, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}

/// A thin separator between grouped rows.
///
/// Apple: a frosted hairline ([GlassDivider]). Android: a flat [Divider] tinted
/// with the secondary border colour. Decorative on both paths (hidden from
/// screen readers).
class PregoDivider extends StatelessWidget {
  const PregoDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.height,
  });

  /// Empty space leading the line on the left.
  final double indent;

  /// Empty space trailing the line on the right.
  final double endIndent;

  /// Total cross-axis space the divider occupies. Defaults to 1.0.
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (glassEffectsEnabled()) {
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
/// Apple: delegates to [GlassListTile] (identical to the existing glass rows).
/// Android: a flat [InkWell] row with the same metrics — 32px leading box, 12px
/// gap, title/subtitle column, trailing — and a [PregoDivider] below unless it
/// is the last row.
class PregoListTile extends StatelessWidget {
  const PregoListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.showDivider = true,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.leadingIconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.dividerIndent,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Whether this is the last row in its group; suppresses the bottom divider.
  final bool isLast;

  /// Whether to draw a [PregoDivider] below this row. Ignored when [isLast].
  final bool showDivider;

  final EdgeInsetsGeometry contentPadding;
  final Color? leadingIconColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Leading indent of the bottom divider. Defaults to 56 when a [leading]
  /// widget is present (aligning the line under the title), 16 otherwise.
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    if (glassEffectsEnabled()) {
      return GlassListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        isLast: isLast,
        showDivider: showDivider,
        contentPadding: contentPadding,
        leadingIconColor: leadingIconColor,
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
        dividerIndent: dividerIndent,
      );
    }

    return _buildFlat(context);
  }

  Widget _buildFlat(BuildContext context) {
    final prego = context.prego;
    final labelColor = prego.colors.textPrimary;
    final effectiveTitleStyle =
        titleStyle ?? prego.textTheme.textMd.medium.copyWith(color: labelColor);
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

    if (showDivider && !isLast) {
      final indent = dividerIndent ?? (leading != null ? 56.0 : 16.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [tile, PregoDivider(indent: indent)],
      );
    }

    return tile;
  }
}
