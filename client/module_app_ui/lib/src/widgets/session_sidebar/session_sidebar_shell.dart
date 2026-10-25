import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "floating_sidebar_panel.dart";

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

/// The session routes' shell: from [wideLayoutBreakpoint], the sidebar floats
/// as a fixed-width [FloatingSidebarPanel] beside the content pane, as on
/// desktop; below it, the content alone.
///
/// Collapsing hides the sidebar completely: the panel and its margins slide
/// out while the content pane widens, and a restore button grows in before the
/// leading of every page in the pane (D9). The collapsed flag lives only as
/// long as the shell.
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
  /// The touch panel's fixed width (D9).
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
        const margin = FloatingSidebarPanel.margin;
        // The panel floats clear of a landscape notch, the status bar and the
        // home indicator, with its gap to the pane after it.
        final sidebar = SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.all(margin),
            child: FloatingSidebarPanel(
              key: const Key("session-sidebar"),
              width: _sidebarWidth,
              // Clear of the screen's edges, the panel's rows need no inset.
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeTop: true,
                removeRight: true,
                removeBottom: true,
                child: Column(
                  children: [
                    Expanded(
                      // Ink paints on the nearest Material, outside the list's
                      // own clip: this one keeps a row's highlight above the
                      // footer, as on desktop.
                      child: Material(
                        type: MaterialType.transparency,
                        clipBehavior: Clip.hardEdge,
                        child: widget.sidebar,
                      ),
                    ),
                    Divider(height: 1, color: context.prego.colors.borderPrimary),
                    widget.footer(onCollapse: () => _setCollapsed(collapsed: true)),
                  ],
                ),
              ),
            ),
          ),
        );
        // What the collapse slides out: the panel with its margins.
        final sidebarExtent = MediaQuery.paddingOf(context).left + margin + _sidebarWidth + margin;
        final pane = PregoTopNavigationShellLeading(leading: _restoreButton, child: widget.child);
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
                  child: ListenableBuilder(
                    listenable: _sidebarCurve,
                    // Aligned to its end, the panel slides out at its full
                    // width rather than squeezing its rows.
                    builder: (context, panel) => Align(
                      alignment: AlignmentDirectional.centerEnd,
                      widthFactor: _sidebarCurve.value,
                      child: panel,
                    ),
                    child: sidebar,
                  ),
                ),
                Expanded(
                  key: const Key("session-sidebar-content"),
                  child: ListenableBuilder(
                    listenable: _sidebarCurve,
                    builder: (context, _) {
                      // Beside the panel the pane is clear of the screen's
                      // edge, so it takes back that edge's inset only as the
                      // collapse brings it there.
                      final data = MediaQuery.of(context);
                      final edgeInset = math.max(0.0, data.padding.left - sidebarExtent * _sidebarCurve.value);
                      return MediaQuery(
                        data: data.copyWith(padding: data.padding.copyWith(left: edgeInset)),
                        child: pane,
                      );
                    },
                  ),
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
