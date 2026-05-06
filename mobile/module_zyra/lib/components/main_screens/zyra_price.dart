import "package:flutter/material.dart";

import "../../icons/fa6_pro_icons.g.dart";
import "../../interactions/zyra_tappable.dart";
import "../../theme/zyra_theme.dart";

/// Direction of the price change indicator.
enum ZyraPriceDirection { up, down }

/// Displays a price change indicator with percentage, balance change,
/// and an optional eye toggle button for balance visibility.
///
/// Matches the Figma `zyraPrice` component on the Main Screens page.
///
/// The component does **not** clip its height to an artificially small
/// container (as the Figma frame does). Instead it uses its natural height,
/// which provides a comfortable tap target for the eye toggle.
///
/// Usage:
/// ```dart
/// ZyraPrice(
///   direction: ZyraPriceDirection.up,
///   percentageText: '5.2%',
///   balanceChangeText: '+\$1,250.00',
///   isBalanceHidden: false,
///   onToggleBalanceVisibility: () {},
/// )
/// ```
class ZyraPrice extends StatelessWidget {
  const ZyraPrice({
    super.key,
    required this.direction,
    required this.percentageText,
    required this.balanceChangeText,
    required this.isBalanceHidden,
    this.onToggleBalanceVisibility,
    this.opacity = 1.0,
  });

  /// Whether the price is trending up or down.
  final ZyraPriceDirection direction;

  /// Formatted percentage text (e.g. `"5.2%"`).
  final String percentageText;

  /// Formatted absolute balance change text (e.g. `"+$1,250.00"`).
  final String balanceChangeText;

  /// Whether the balance values are currently hidden (discreet mode).
  final bool isBalanceHidden;

  /// Called when the eye toggle is tapped. When `null`, the eye button
  /// is not rendered and the component is non-interactive.
  final VoidCallback? onToggleBalanceVisibility;

  /// Overall opacity applied to all colors in the component.
  /// Clamped to the range 0.0–1.0.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final textTheme = zyra.textTheme;

    final clampedOpacity = opacity.clamp(0.0, 1.0);
    Color applyOpacity(Color c) => c.withValues(alpha: c.a * clampedOpacity);

    final caretColor = applyOpacity(switch (direction) {
      ZyraPriceDirection.up => colors.textSuccessPrimary,
      ZyraPriceDirection.down => colors.textErrorPrimary,
    });

    final valueAndIconColor = applyOpacity(colors.textTertiary);

    final valueStyle = textTheme.textSm.bold.copyWith(color: valueAndIconColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  switch (direction) {
                    ZyraPriceDirection.up => FA6Solid.caret_up,
                    ZyraPriceDirection.down => FA6Solid.caret_down,
                  },
                  size: 14,
                  color: caretColor,
                ),
              ),
              TextSpan(text: " ", style: valueStyle),
              TextSpan(text: percentageText, style: valueStyle),
              TextSpan(text: " / ", style: valueStyle),
              TextSpan(text: balanceChangeText, style: valueStyle),
            ],
          ),
        ),
        if (onToggleBalanceVisibility != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: ZyraSpacing.xs),
            child: _EyeToggleButton(
              isBalanceHidden: isBalanceHidden,
              onTap: onToggleBalanceVisibility,
              iconColor: valueAndIconColor,
            ),
          ),
      ],
    );
  }
}

/// A properly-sized tap target for the balance visibility toggle.
///
/// Renders a 36×36 hit area with the 12px eye icon centred inside,
/// ensuring the button is comfortable to tap without artificially
/// clipping the parent row's height.
class _EyeToggleButton extends StatelessWidget {
  const _EyeToggleButton({
    required this.isBalanceHidden,
    required this.onTap,
    required this.iconColor,
  });

  final bool isBalanceHidden;
  final VoidCallback? onTap;
  final Color iconColor;

  // Minimum dimension for the tap target — ensures a comfortable hit area.
  static const double _tapTargetSize = 36;
  static const double _iconSize = 12;

  @override
  Widget build(BuildContext context) {
    return ZyraTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_tapTargetSize / 2),
      containerBuilder: (child) => SizedBox.square(
        dimension: _tapTargetSize,
        child: child,
      ),
      child: Center(
        child: Icon(
          isBalanceHidden ? FA6Solid.eye_slash : FA6Solid.eye,
          size: _iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
