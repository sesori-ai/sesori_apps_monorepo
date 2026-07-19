import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";

/// A small bordered label chip matching the Figma `pregoTags` component.
///
/// Renders an optional 14px leading glyph and a tertiary `text-xs` caption
/// inside a hairline-bordered rounded rectangle, e.g. the auth-provider badge
/// beside the account name in settings.
class PregoTag extends StatelessWidget {
  const PregoTag({
    super.key,
    this.icon,
    required this.label,
  });

  /// Optional leading glyph, rendered at 14px in the tertiary text colour.
  final IconData? icon;

  /// The tag caption.
  final String label;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: prego.colors.borderPrimary),
        borderRadius: BorderRadius.circular(PregoRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PregoSpacing.xs,
          vertical: PregoSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: prego.colors.textTertiary),
              const SizedBox(width: PregoSpacing.xs),
            ],
            Text(
              label,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
