import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

/// Who draws a settings page's title and its way out.
sealed class SettingsPageChrome();

/// The page draws its own glass bar with a title and a back button, its one
/// way back.
final class SettingsPageOwnBar({
  required final String title,
  required final Widget? connectionBanner,
}) implements SettingsPageChrome;

/// The desktop settings window hosts the page: its sidebar names the page and
/// it owns the close button, so the page draws no bar.
final class SettingsPageInWindow() implements SettingsPageChrome;

/// A page the desktop settings window pushed over a tab's own page. The
/// sidebar still names the tab, so the page names itself under its way back.
final class SettingsPageInWindowSubpage({
  required final String title,
  required final VoidCallback onBack,
}) implements SettingsPageChrome;

/// Renders [slivers] under [chrome]: a glass-bar page of its own, or a bare
/// scrolling page inside the desktop settings window.
class const SettingsChromePage({
  super.key,
  required final SettingsPageChrome chrome,
  required final List<Widget> slivers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (chrome) {
    SettingsPageOwnBar(:final title, :final connectionBanner) => PregoGlassScaffold(
      title: title,
      titleMode: PregoTopNavigationTitleMode.inline,
      banner: connectionBanner,
      slivers: slivers,
    ),
    SettingsPageInWindow() => SettingsWindowPage(onRefresh: null, slivers: slivers),
    SettingsPageInWindowSubpage(:final title, :final onBack) => SettingsWindowPage(
      onRefresh: null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.md, 0, PregoSpacing.xl, PregoSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PregoSpacing.sm,
              children: [
                PregoButtonsSolid(
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  leadingIcon: TablerRegular.chevron_left,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: onBack,
                ),
                Padding(
                  // Lines the title up with the page content below it.
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xl - PregoSpacing.md),
                  child: Semantics(
                    header: true,
                    child: Text(title, style: context.prego.textTheme.textLg.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...slivers,
      ],
    ),
  };
}

/// A page inside the desktop settings window. It has no bar: the window's
/// sidebar names the page and its close button floats top-right, so content
/// starts clear of that button.
class const SettingsWindowPage({
  super.key,

  /// Pull-to-refresh, as on the page's own glass bar; `null` for none.
  required final Future<void> Function()? onRefresh,
  required final List<Widget> slivers,
}) extends StatelessWidget {
  /// Top inset that clears the window's close button.
  static const double topInset = 44;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    primary: false,
    // The refresh control needs overscroll, as on PregoGlassScaffold.
    physics: onRefresh == null ? null : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    slivers: [
      if (onRefresh case final onRefresh?)
        PregoSliverRefreshControl(onRefresh: onRefresh, decorate: null, onPulledExtentChanged: null),
      const SliverToBoxAdapter(child: SizedBox(height: topInset)),
      ...slivers,
    ],
  );
}
