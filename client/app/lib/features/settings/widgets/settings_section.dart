import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

/// Gap between a section header and its card, from the Figma settings layout.
const double _headerGap = 10.0;

/// A titled settings section: a secondary `text-md` header above its card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;

  /// The section body, typically a [PregoGroupedRows] card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: _headerGap),
        child,
      ],
    );
  }
}
