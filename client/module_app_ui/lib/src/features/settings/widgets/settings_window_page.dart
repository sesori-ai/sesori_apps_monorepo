import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Who draws a settings page's title and close button.
sealed class SettingsPageChrome();

/// The page draws its own glass bar with a title and a close button.
final class SettingsPageOwnBar({
  required final String title,
  required final bool automaticallyImplyLeading,
  required final Widget? connectionBanner,
  required final VoidCallback onClose,
}) implements SettingsPageChrome;

/// The desktop settings window hosts the page: its sidebar names the page and
/// it owns the close button, so the page draws no bar.
final class SettingsPageInWindow() implements SettingsPageChrome;

/// Renders [slivers] under [chrome]: a glass-bar page of its own, or a bare
/// scrolling page inside the desktop settings window.
class const SettingsChromePage({
  super.key,
  required final SettingsPageChrome chrome,
  required final List<Widget> slivers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (chrome) {
    SettingsPageOwnBar(:final title, :final automaticallyImplyLeading, :final connectionBanner, :final onClose) =>
      PregoGlassScaffold(
        title: title,
        titleMode: PregoTopNavigationTitleMode.inline,
        automaticallyImplyLeading: automaticallyImplyLeading,
        banner: connectionBanner,
        actions: [
          PregoButtonsIconGlass(icon: TablerRegular.x, semanticLabel: context.loc.settingsClose, onPressed: onClose),
        ],
        slivers: slivers,
      ),
    SettingsPageInWindow() => SettingsWindowPage(slivers: slivers),
  };
}

/// A page inside the desktop settings window. It has no bar: the window's
/// sidebar names the page and its close button floats top-right, so content
/// starts clear of that button.
class const SettingsWindowPage({super.key, required final List<Widget> slivers}) extends StatelessWidget {
  /// Top inset that clears the window's close button.
  static const double topInset = 44;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    primary: false,
    slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: topInset)),
      ...slivers,
    ],
  );
}
