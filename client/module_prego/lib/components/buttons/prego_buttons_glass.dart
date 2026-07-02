import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_theme.dart";

/// A liquid-glass pill that opens a menu: leading glyph, one-line [label], and
/// a trailing unfold caret signalling the popup. This is the shared trigger
/// for [PregoAnchorMenu]-style pickers — the composer's agent/model/variant
/// pills all render this pill.
///
/// The pill fills its parent's width (each composer pill sits in an
/// [Expanded] slot) and ellipsizes long labels.
///
/// Usage:
/// ```dart
/// PregoButtonsGlass(
///   leadingIcon: Icons.smart_toy_outlined,
///   label: selectedAgent,
///   onPressed: toggle,
/// )
/// ```
class PregoButtonsGlass extends StatelessWidget {
  const PregoButtonsGlass({
    super.key,
    required this.leadingIcon,
    required this.label,
    required this.onPressed,
  });

  /// The glyph rendered before the label.
  final IconData leadingIcon;

  /// One-line button text; ellipsizes when it doesn't fit.
  final String label;

  /// Called when the pill is tapped. Wire this to the menu's open callback.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final foreground = prego.colors.textSecondary;
    return GlassButton.custom(
      onTap: onPressed,
      width: double.infinity,
      height: 36,
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      useOwnLayer: true,
      settings: LiquidGlassSettings(glassColor: prego.colors.buttonGlassPrimaryBackground),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(leadingIcon, size: 14, color: foreground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: prego.textTheme.textXs.medium.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: foreground),
          ],
        ),
      ),
    );
  }
}
