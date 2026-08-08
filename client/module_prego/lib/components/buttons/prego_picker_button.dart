import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";
import "../surfaces/prego_surfaces.dart";

/// A solid pill that opens a picker: leading glyph, one-line [label], and a
/// trailing unfold caret signalling the popup.
///
/// Its surface matches the composer's background, border, and elevation on
/// every platform, while its press feedback uses the same Material ripple.
/// The pill fills its parent's width and ellipsizes long labels.
///
/// Usage:
/// ```dart
/// PregoPickerButton(
///   leadingIcon: Icons.smart_toy_outlined,
///   label: selectedAgent,
///   surfaceStyle: PregoComposerSurfaceStyle.subtle,
///   onPressed: toggle,
/// )
/// ```
class PregoPickerButton extends StatelessWidget {
  const PregoPickerButton({
    super.key,
    required this.leadingIcon,
    required this.label,
    required this.surfaceStyle,
    required this.onPressed,
  });

  /// The glyph rendered before the label.
  final IconData leadingIcon;

  /// One-line button text; ellipsizes when it doesn't fit.
  final String label;

  /// Outline emphasis shared with the current composer state.
  final PregoComposerSurfaceStyle surfaceStyle;

  /// Called when the pill is tapped. Wire this to the menu's open callback.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final foreground = prego.colors.textSecondary;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: DecoratedBox(
        decoration: pregoComposerSurfaceDecoration(
          prego: prego,
          style: surfaceStyle,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: borderRadius,
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
            ),
          ),
        ),
      ),
    );
  }
}
