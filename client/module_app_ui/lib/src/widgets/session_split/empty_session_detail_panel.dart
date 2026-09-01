import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// Placeholder panel shown in the right pane when no session is selected
/// in wide split mode.
///
/// Product shells inject their background and connection presentation so this
/// shared panel never assumes a product asset bundle or duplicate banner owner.
class const EmptySessionDetailPanel({
  super.key,
  required final Widget? background,
  required final Widget? connectionBanner,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final brightness = Theme.of(context).brightness;
    final scrimColor = brightness == Brightness.light ? Colors.white : Colors.black;

    final background = this.background;
    final connectionBanner = this.connectionBanner;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background),
          Positioned.fill(
            child: ColoredBox(color: scrimColor.withValues(alpha: 0.85)),
          ),
          Center(
            key: const Key("empty-session-detail-panel"),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: prego.colors.textTertiary,
                ),
                SizedBox(height: prego.spacing.md),
                Text(
                  context.loc.emptySessionDetailTitle,
                  style: prego.textTheme.textMd.bold.copyWith(
                    color: prego.colors.textSecondary,
                  ),
                ),
                SizedBox(height: prego.spacing.xs),
                Text(
                  context.loc.emptySessionDetailSubtitle,
                  style: prego.textTheme.textSm.regular.copyWith(
                    color: prego.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (connectionBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: connectionBanner),
            ),
        ],
      ),
    );
  }
}
