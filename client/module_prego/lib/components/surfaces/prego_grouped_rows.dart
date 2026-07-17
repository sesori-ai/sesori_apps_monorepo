/// Grouped settings surfaces from the Figma settings redesign.
///
/// Unlike [PregoCard], these surfaces are deliberately flat on every platform:
/// the settings screens specify solid `bg-surface-3` cards on the `bg-surface-1`
/// page background rather than liquid glass.
library;

import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";

/// Minimum height of a row without a subtitle.
const double _rowMinHeight = 52.0;

/// Minimum height of a row with a subtitle (and of the account row).
const double _tallRowMinHeight = 68.0;

/// Width of the leading icon slot.
const double _leadingSlotWidth = 24.0;

/// Size of the leading glyph inside its slot.
const double _leadingIconSize = 20.0;

/// A solid rounded card hosting grouped settings rows (Figma "Grouped Rows").
class PregoGroupedRows extends StatelessWidget {
  const PregoGroupedRows({
    super.key,
    required this.children,
  });

  /// The rows, typically [PregoGroupedRow]s. Mark the final row with
  /// [PregoGroupedRow.isLast] so it drops its bottom divider.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.prego.colors.bgSurface3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.x5l)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A settings row (Figma "Row"): optional 20px leading glyph, `text-md` title,
/// optional `text-xs` subtitle, and a trailing slot (chevron, switch, …).
///
/// Rows compose a hairline divider below themselves aligned with the title
/// column; set [isLast] on the final row of a [PregoGroupedRows] card.
class PregoGroupedRow extends StatelessWidget {
  const PregoGroupedRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  /// Leading glyph rendered at 20px in the tertiary text colour. Ignored when
  /// [leading] is provided.
  final IconData? icon;

  /// Custom leading widget (e.g. an avatar). Takes precedence over [icon].
  final Widget? leading;

  final Widget title;
  final Widget? subtitle;

  /// Trailing slot. Icon descendants default to 20px in the tertiary colour.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Whether this is the last row in its card; suppresses the bottom divider.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final leading =
        this.leading ??
        switch (icon) {
          final glyph? => SizedBox(
            width: _leadingSlotWidth,
            child: Icon(glyph, size: _leadingIconSize, color: prego.colors.textTertiary),
          ),
          null => null,
        };

    final row = Row(
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(width: PregoSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                child: title,
              ),
              if (subtitle != null)
                DefaultTextStyle(
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                  child: subtitle,
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: PregoSpacing.md),
          IconTheme(
            data: IconThemeData(color: prego.colors.textTertiary, size: _leadingIconSize),
            child: trailing,
          ),
        ],
      ],
    );

    Widget tile = Container(
      constraints: BoxConstraints(minHeight: subtitle != null ? _tallRowMinHeight : _rowMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: PregoSpacing.xl,
        vertical: PregoSpacing.md,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: row,
    );
    if (onTap != null) {
      tile = InkWell(onTap: onTap, child: tile);
    }

    if (isLast) return tile;

    // Hairline between rows, aligned with the title column like the Figma
    // rows' top border (which starts after the leading slot).
    final dividerIndent = PregoSpacing.xl + (leading != null ? _leadingSlotWidth + PregoSpacing.md : 0.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        ExcludeSemantics(
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: dividerIndent, end: PregoSpacing.xl),
            child: ColoredBox(
              color: context.prego.colors.borderSecondary,
              child: const SizedBox(height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
