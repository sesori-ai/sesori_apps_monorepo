import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_session_signals.dart";
import "desktop_sidebar_expansion.dart";

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

  /// Leads the title in the sidebar's status slot, such as a session waiting
  /// for an answer; null leaves the title at the left edge.
  required final Widget? status,
  required final String title,

  /// Quiet context on the title's line, such as a session's project and harness.
  /// It takes only the room the title leaves.
  required final String? titleDetail,

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
    final titleDetail = this.titleDetail;
    final titleText = Text(
      title,
      style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final tertiary = prego.colors.textTertiary;
    return Container(
      // A floor, not a fixed slot: scaled-up text grows the bar instead of spilling out of it.
      constraints: const BoxConstraints(minHeight: height),
      // Its content's middle is the title line, one point above the bar's.
      padding: const EdgeInsets.fromLTRB(PregoSpacing.xl, 0, PregoSpacing.xl, 2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: prego.colors.borderSecondary)),
      ),
      child: DesktopSidebarRestoreInset(
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
                        // A long project name gives way to the title rather than sharing the row with it,
                        // and shrinks with it when the actions leave the row little room.
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: InkWell(
                              mouseCursor: WidgetStateMouseCursor.clickable,
                              key: const Key("desktop-page-breadcrumb"),
                              onTap: breadcrumb.onPressed,
                              borderRadius: BorderRadius.circular(PregoRadius.sm),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(TablerRegular.chevron_left, size: 16, color: prego.colors.textSecondary),
                                  Flexible(
                                    child: Text(
                                      breadcrumb.label,
                                      style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // One size and baseline with the title, so a text slash lines up where an icon would not.
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm),
                            child: Text("/", style: prego.textTheme.textMd.regular.copyWith(color: tertiary)),
                          ),
                        ),
                      ],
                      if (status != null)
                        SizedBox(
                          width: DesktopSessionSignals.width,
                          child: Center(child: status),
                        ),
                      if (titleDetail == null)
                        Flexible(
                          child: Semantics(header: true, label: title, excludeSemantics: true, child: titleText),
                        )
                      else
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final titleWidth = (TextPainter(
                                text: TextSpan(text: title, style: titleText.style),
                                maxLines: 1,
                                textDirection: Directionality.of(context),
                                textScaler: MediaQuery.textScalerOf(context),
                              )..layout()).width.ceilToDouble();
                              final room = constraints.maxWidth - titleWidth - PregoSpacing.md;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  SizedBox(
                                    width: titleWidth.clamp(0, constraints.maxWidth),
                                    child: Semantics(
                                      header: true,
                                      label: title,
                                      excludeSemantics: true,
                                      child: titleText,
                                    ),
                                  ),
                                  // Under a name's worth of room, a clipped fragment would say nothing.
                                  if (room >= 80) ...[
                                    const SizedBox(width: PregoSpacing.md),
                                    Flexible(
                                      child: Text(
                                        titleDetail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: prego.textTheme.textXs.regular.copyWith(color: tertiary),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
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
      ),
    );
  }
}
