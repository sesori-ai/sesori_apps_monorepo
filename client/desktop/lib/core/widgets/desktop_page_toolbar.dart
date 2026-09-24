import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_session_signals.dart";

/// The page a toolbar's title sits under, such as the project that holds a
/// session. Pressing it opens that page.
typedef DesktopBreadcrumb = ({String label, VoidCallback onPressed});

/// The one toolbar anatomy of a desktop page: what the page is on the left,
/// what it can do on the right, over a hairline. Every page starts its content
/// at the same left edge; a pushed page goes back with Cmd/Ctrl+[, not a
/// toolbar arrow.
///
/// At its resting height it is as tall as the band the app root lets drag the macOS window, so its
/// empty background moves the window and its controls keep their clicks.
class const DesktopPageToolbar({
  super.key,

  /// Null on a page with nothing above it.
  required final DesktopBreadcrumb? breadcrumb,

  /// Leads the title in the sidebar's status slot, such as a running
  /// session's sparkle; null leaves the title at the left edge.
  required final Widget? status,
  required final String title,

  /// A second, quieter line under the title; null leaves the title alone.
  required final Widget? subtitle,
  required final List<Widget> actions,
}) extends StatelessWidget {
  static const double height = PregoTopNavigation.barHeight;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final breadcrumb = this.breadcrumb;
    final status = this.status;
    final subtitle = this.subtitle;
    final tertiary = prego.colors.textTertiary;
    return Container(
      // A floor, not a fixed slot: scaled-up text grows the bar instead of spilling out of it.
      constraints: const BoxConstraints(minHeight: height),
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
                Row(
                  children: [
                    if (breadcrumb != null) ...[
                      // A long project name gives way to the title rather than sharing the row with it.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          key: const Key("desktop-page-breadcrumb"),
                          onTap: breadcrumb.onPressed,
                          borderRadius: BorderRadius.circular(PregoRadius.sm),
                          child: Text(
                            breadcrumb.label,
                            style: prego.textTheme.textSm.regular.copyWith(color: tertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
                        child: Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: tertiary),
                      ),
                    ],
                    if (status != null)
                      SizedBox(
                        width: DesktopSessionSignals.width,
                        child: Center(child: status),
                      ),
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
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
