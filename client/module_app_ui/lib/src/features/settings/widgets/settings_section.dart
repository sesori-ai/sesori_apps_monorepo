import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Gap between a section header and its card, from the Figma settings layout.
const double _headerGap = 10.0;

/// A titled settings section: a tertiary `text-sm` header above its card.
class const SettingsSection({
  super.key,
  required final String title,

  /// The section body, typically a [PregoGroupedRows] card.
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textTertiary),
        ),
        const SizedBox(height: _headerGap),
        child,
      ],
    );
  }
}
