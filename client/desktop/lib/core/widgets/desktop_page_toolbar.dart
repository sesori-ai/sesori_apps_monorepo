import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The one toolbar anatomy of a desktop page: what the page is on the left,
/// what it can do on the right, over a hairline.
///
/// It is as tall as the band the app root lets drag the macOS window, so its
/// empty background moves the window and its controls keep their clicks.
class const DesktopPageToolbar({
  super.key,
  required final String title,

  /// A second, quieter line under the title; null leaves the title alone.
  required final Widget? subtitle,
  required final List<Widget> actions,
}) extends StatelessWidget {
  static const double height = PregoTopNavigation.barHeight;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface1,
        border: Border(bottom: BorderSide(color: prego.colors.borderSecondary)),
      ),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?subtitle,
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
