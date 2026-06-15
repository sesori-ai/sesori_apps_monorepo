import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

/// Direction of the price change indicator.
enum PregoPriceDirection { up, down }

/// Displays a price change indicator with percentage, balance change,
/// and an optional eye toggle button for balance visibility.
///
/// Matches the Figma `pregoPrice` component on the Main Screens page.
///
/// The component does **not** clip its height to an artificially small
/// container (as the Figma frame does). Instead it uses its natural height,
/// which provides a comfortable tap target for the eye toggle.
///
/// Usage:
/// ```dart
/// PregoPrice(
///   direction: PregoPriceDirection.up,
///   percentageText: '5.2%',
///   balanceChangeText: '+\$1,250.00',
///   isBalanceHidden: false,
///   onToggleBalanceVisibility: () {},
/// )
/// ```
class PregoPrice extends StatelessWidget {
  const PregoPrice({
    super.key,
    required this.direction,
    required this.percentageText,
    required this.balanceChangeText,
    required this.isBalanceHidden,
    this.onToggleBalanceVisibility,
    this.opacity = 1.0,
  });

  /// Whether the price is trending up or down.
  final PregoPriceDirection direction;

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
    final prego = context.prego;
    final colors = prego.colors;
    final textTheme = prego.textTheme;

    final clampedOpacity = opacity.clamp(0.0, 1.0);
    Color applyOpacity(Color c) => c.withValues(alpha: c.a * clampedOpacity);

    final caretColor = applyOpacity(switch (direction) {
      PregoPriceDirection.up => colors.textSuccessPrimary,
      PregoPriceDirection.down => colors.textErrorPrimary,
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
                    PregoPriceDirection.up => TablerRegular.caret_up,
                    PregoPriceDirection.down => TablerRegular.caret_down,
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
            padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
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
    return PregoTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_tapTargetSize / 2),
      containerBuilder: (child) => SizedBox.square(
        dimension: _tapTargetSize,
        child: child,
      ),
      child: Center(
        child: Icon(
          isBalanceHidden ? TablerRegular.eye_off : TablerRegular.eye,
          size: _iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
