import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// The width from which the session shell shows its sidebar beside the
/// content pane (D7).
const double wideLayoutBreakpoint = 700;

/// How the session shell presents its pages.
enum SessionShellLayout() {
  /// Below [wideLayoutBreakpoint]: each page fills the screen and pushes over
  /// the home.
  pages,

  /// From [wideLayoutBreakpoint]: pages show in the content pane beside the
  /// sidebar, which the user may have collapsed.
  pane,
}

typedef SessionSidebarFooterBuilder = Widget Function({required VoidCallback onCollapse});

/// The session routes' shell: from [wideLayoutBreakpoint], a fixed-width
/// sidebar beside the content pane; below it, the content alone.
///
/// Collapsing hides the sidebar completely: it slides out while the content
/// pane widens, and a restore button grows in before the leading of every page
/// in the pane (D9). The collapsed flag lives only as long as the shell.
///
/// It reports whether the sidebar shows to the scope's [AllSessionsCubit],
/// which owns the wide-pane claim.
class const SessionSidebarShell({
  super.key,

  /// The sidebar's scrolling body.
  required final Widget sidebar,

  /// Pinned under [sidebar].
  required final SessionSidebarFooterBuilder footer,

  /// The content pane, and below the breakpoint the whole screen.
  required final Widget child,
}) extends StatefulWidget {
  /// How the nearest session shell presents [context]'s page:
  /// [SessionShellLayout.pages] outside one.
  static SessionShellLayout layoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SessionShellLayoutScope>()?.layout ?? SessionShellLayout.pages;

  @override
  State<SessionSidebarShell> createState() => _SessionSidebarShellState();
}

class _SessionSidebarShellState() extends State<SessionSidebarShell> with SingleTickerProviderStateMixin {
  /// The touch sidebar's fixed width (D9).
  static const double _sidebarWidth = 320;
  static const Duration _motion = Duration(milliseconds: 260);

  late final AllSessionsCubit _sessions;

  /// 1 while the sidebar shows, 0 once it is collapsed.
  late final AnimationController _sidebar = AnimationController(vsync: this, duration: _motion, value: 1)
    ..addStatusListener((_) => setState(() {}));
  late final Animation<double> _sidebarCurve = CurvedAnimation(parent: _sidebar, curve: Curves.easeInOut);
  late final Widget _restoreButton = _RestoreButton(
    sidebar: _sidebarCurve,
    onPressed: () => _setCollapsed(collapsed: false),
  );
  bool _collapsed = false;
  bool _paneVisible = false;

  @override
  void initState() {
    super.initState();
    _sessions = context.read<AllSessionsCubit>();
  }

  void _setCollapsed({required bool collapsed}) {
    setState(() => _collapsed = collapsed);
    _sidebar.duration = context.isReducedMotion ? Duration.zero : _motion;
    collapsed ? _sidebar.reverse() : _sidebar.forward();
  }

  void _reportPaneVisibility({required bool isVisible}) {
    if (_paneVisible == isVisible) return;
    _paneVisible = isVisible;
    _sessions.setPaneVisible(isVisible: isVisible);
  }

  @override
  void dispose() {
    _reportPaneVisibility(isVisible: false);
    _sidebar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= wideLayoutBreakpoint;
        _reportPaneVisibility(isVisible: isWide && !_collapsed);
        if (!isWide) {
          return _SessionShellLayoutScope(layout: SessionShellLayout.pages, child: widget.child);
        }
        final prego = context.prego;
        // The shell-level Scaffold is the single root Scaffold beside the
        // sidebar, so snackbars span the sidebar and the content pane instead of
        // attaching to a pane page's transient Scaffold.
        return _SessionShellLayoutScope(
          layout: SessionShellLayout.pane,
          child: Scaffold(
            key: const Key("session-sidebar-scaffold"),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fully collapsed, the sidebar keeps its state but leaves focus
                // and the screen reader.
                Offstage(
                  offstage: _sidebar.isDismissed,
                  child: SizeTransition(
                    // Aligned to its end, the sidebar slides out rather than
                    // narrowing.
                    axis: Axis.horizontal,
                    alignment: AlignmentDirectional.centerEnd,
                    sizeFactor: _sidebarCurve,
                    child: SizedBox(
                      key: const Key("session-sidebar"),
                      // A landscape notch's inset widens the sidebar rather
                      // than narrowing its content.
                      width: _sidebarWidth + MediaQuery.paddingOf(context).left,
                      child: Material(
                        color: prego.colors.bgSecondary,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SafeArea(
                                right: false,
                                child: Column(
                                  children: [
                                    Expanded(child: widget.sidebar),
                                    Divider(height: 1, color: prego.colors.borderPrimary),
                                    widget.footer(onCollapse: () => _setCollapsed(collapsed: true)),
                                  ],
                                ),
                              ),
                            ),
                            VerticalDivider(width: 1, color: prego.colors.borderPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  key: const Key("session-sidebar-content"),
                  child: PregoTopNavigationShellLeading(leading: _restoreButton, child: widget.child),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class const _SessionShellLayoutScope({required final SessionShellLayout layout, required super.child})
    extends InheritedWidget {
  @override
  bool updateShouldNotify(_SessionShellLayoutScope oldWidget) => layout != oldWidget.layout;
}

/// The content pane's way back to a collapsed sidebar. It grows in as the
/// sidebar slides out, so the bar's title moves with the motion instead of
/// jumping once it ends.
class const _RestoreButton({required final Animation<double> sidebar, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sidebar,
      builder: (context, button) {
        final shown = 1 - sidebar.value;
        if (shown == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: shown,
            child: Opacity(opacity: shown, child: button),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: PregoSpacing.lg),
        child: PregoButtonsIconGlass(
          key: const Key("session-sidebar-restore"),
          icon: TablerRegular.layout_sidebar_left_expand,
          semanticLabel: context.loc.sessionSidebarExpand,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
