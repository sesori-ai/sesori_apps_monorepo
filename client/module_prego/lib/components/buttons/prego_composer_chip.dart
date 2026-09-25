import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";
import "../surfaces/prego_surfaces.dart";

/// Quiet pill in the composer's model row: a glyph and a short label on the
/// composer surface, for session states the user may want to inspect. Without
/// [showLabel] it is a square glyph button that keeps [label] as its tooltip
/// and accessible name, for rows too narrow to spare the text. [isWarning]
/// tints the glyph and label for a state that trades safety for speed.
class const PregoComposerChip({
  super.key,
  required final IconData icon,
  required final String label,
  required final bool showLabel,
  required final bool isWarning,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final foreground = isWarning ? prego.colors.textWarningPrimary : prego.colors.textSecondary;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    final glyph = Icon(
      icon,
      size: PregoIconSize.sm,
      color: isWarning ? prego.colors.fgWarningPrimary : prego.colors.textSecondary,
    );
    final pill = DecoratedBox(
      decoration: pregoComposerSurfaceDecoration(prego: prego, style: surfaceStyle, borderRadius: borderRadius),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: onPressed,
            borderRadius: borderRadius,
            child: showLabel
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        glyph,
                        Text(label, style: prego.textTheme.textXs.medium.copyWith(color: foreground)),
                      ],
                    ),
                  )
                : Center(child: glyph),
          ),
        ),
      ),
    );
    if (showLabel) return Semantics(button: true, child: SizedBox(height: 36, child: pill));
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox.square(dimension: 36, child: pill),
      ),
    );
  }
}
