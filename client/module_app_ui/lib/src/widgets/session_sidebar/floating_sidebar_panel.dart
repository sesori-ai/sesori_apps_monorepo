import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The session sidebar's floating panel on every surface: a rounded surface
/// with a hairline edge and a shadow, so depth rather than a divider sets it
/// apart from the page.
///
/// Its shell keeps [margin] between the panel and the screen's edges, past any
/// safe-area inset, and between the panel and the page beside it.
class const FloatingSidebarPanel({super.key, required final double width, required final Widget child})
    extends StatelessWidget {
  static const double margin = PregoSpacing.md;
  static const double _radius = 14;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final shape = BorderRadius.circular(_radius);
    return Container(
      width: width,
      decoration: BoxDecoration(borderRadius: shape, boxShadow: prego.shadows.lg),
      foregroundDecoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: prego.colors.borderSecondary),
      ),
      child: Material(
        color: prego.colors.bgSecondary,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
