import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_theme.dart";

/// Size variants for [PregoButtonsIconGlass].
enum PregoButtonsIconGlassSize {
  /// 32×32 circle — default icon 20px. Matches the Figma app-bar / badge size.
  xs,

  /// 36×36 circle — default icon 20px. Matches the Figma app-bar / badge size.
  sm,

  /// 40×40 circle — default icon 20px. Matches the Figma app-bar / badge size.
  md,

  /// 44×44 circle — default icon 20px. Matches the larger Figma action size.
  lg,

  /// 52×52 circle — default icon 20px. Matches the larger Figma action size.
  xl,
}

/// Pixel diameter of the circular glass button for each size variant. Exposed
/// so callers that must reserve layout space for the button (e.g. an app-bar
/// leading slot) can size that space without duplicating the magic numbers.
extension PregoButtonsIconGlassSizeDiameter on PregoButtonsIconGlassSize {
  double get diameter => switch (this) {
    PregoButtonsIconGlassSize.xs => 32.0,
    PregoButtonsIconGlassSize.sm => 36.0,
    PregoButtonsIconGlassSize.md => 40.0,
    PregoButtonsIconGlassSize.lg => 44.0,
    PregoButtonsIconGlassSize.xl => 52.0,
  };
}

/// Usage:
/// ```dart
/// PregoButtonsIconGlass(
///   icon: VESPRSolid.gear,
///   onPressed: () => openSettings(),
/// )
/// ```
class PregoButtonsIconGlass extends StatelessWidget {
  const PregoButtonsIconGlass({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = PregoButtonsIconGlassSize.lg,
    this.iconSize,
    this.iconColor,
    this.semanticLabel,
  });

  /// The glyph rendered at the centre of the button.
  final IconData icon;

  /// Called when the button is tapped. Pass `null` to render in disabled state.
  final VoidCallback? onPressed;

  /// Governs the button diameter (and the default icon size).
  final PregoButtonsIconGlassSize size;

  /// Overrides the default icon size for the chosen [size].
  final double? iconSize;

  /// Overrides the icon colour. Defaults to `text-primary` when enabled and
  /// `text-disabled` when [onPressed] is `null`.
  final Color? iconColor;

  /// Optional semantics label describing the action for screen readers.
  final String? semanticLabel;

  double get _defaultIconSize => switch (size) {
    PregoButtonsIconGlassSize.xs => 20.0,
    PregoButtonsIconGlassSize.sm => 20.0,
    PregoButtonsIconGlassSize.md => 20.0,
    PregoButtonsIconGlassSize.lg => 20.0,
    PregoButtonsIconGlassSize.xl => 20.0,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final isDisabled = onPressed == null;
    final resolvedIconColor = iconColor ?? (isDisabled ? colors.textDisabled : colors.textPrimary);
    final resolvedIconSize = iconSize ?? _defaultIconSize;

    return GlassIconButton(
      onPressed: onPressed,
      size: size.diameter,
      iconSize: resolvedIconSize,
      settings: LiquidGlassSettings(
        glassColor: colors.buttonGlassPrimaryBackground,
      ),
      icon: Icon(
        icon,
        size: resolvedIconSize,
        color: resolvedIconColor,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
