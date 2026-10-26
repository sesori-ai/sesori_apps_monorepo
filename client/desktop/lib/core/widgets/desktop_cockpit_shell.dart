import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_command_palette.dart";
import "desktop_connection_pill.dart";
import "desktop_page_toolbar.dart";
import "desktop_sidebar.dart";
import "desktop_sidebar_expansion.dart";
import "desktop_window_drag_area.dart";

/// The signed-in [SessionScope] plus the cockpit's own layout owners.
class const DesktopCockpitCubitProvider({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SessionScope(
    createRecentSessionInventory: getIt.call<RecentSessionInventoryService>,
    createProjectInventory: getIt.call<ProjectInventoryService>,
    createRefreshService: ({required projectInventory, required recentSessionInventory}) =>
        getIt<SessionListRefreshService>(param1: projectInventory, param2: recentSessionInventory),
    sessionCleanupService: getIt<SessionCleanupService>(),
    sessionLaunchService: getIt<SessionLaunchService>(),
    connectionService: getIt<ConnectionService>(),
    filterTracker: getIt<SessionListFilterTracker>(),
    sessionListService: getIt<SessionListService>(),
    projectViewingService: getIt<ProjectViewingService>(),
    alertNavigatorKey: null,
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DesktopSidebarCubit(repository: getIt())),
        BlocProvider(
          create: (_) => LinkedComputerAlertCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      child: LinkedComputerAlerts(
        navigatorKey: null,
        onSwitchComputer: ({required bridgeId, required source}) =>
            unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source)),
        child: child,
      ),
    ),
  );
}

/// Product-shell navigation and supervision chrome around the desktop cockpit.
class const DesktopCockpitShell({
  super.key,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,

  /// Opens a new session in a project, including one just added.
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenSettings,

  /// Closes what the page has open, such as its Prompts screen, else leaves a
  /// pushed page; a page reached from the sidebar has nowhere to go.
  required final VoidCallback onGoBack,
  required final Widget child,
}) extends StatelessWidget {
  static const double autoCollapseBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    final sidebar = context.read<DesktopSidebarCubit>();
    final sessions = context.read<AllSessionsCubit>();
    // macOS only: the window has no title bar of its own (see `FlutterWindowHost`).
    final windowHost = defaultTargetPlatform == TargetPlatform.macOS ? getIt<WindowHost>() : null;
    // A first project's next step is its first session.
    void addProject() => unawaited(
      showAddProjectDialog(context: context, onProjectAdded: onNewSession),
    );
    // The open project, else the list's new-session default (the filter, else
    // "No project", else the newest session's project), else the first listed
    // one; with no project yet, adding one is the only useful next step. A
    // chosen project missing from the inventory (hidden meanwhile) is never
    // swapped for another one.
    void startNewSession() {
      final projects = context.read<ProjectListCubit>().state;
      if (projects is! ProjectListLoaded) return;
      final projectId = selectedProjectId ?? sessions.state.defaultProjectId;
      final project = projectId == null
          ? projects.projects.firstOrNull
          : projects.projects.where((project) => project.id == projectId).firstOrNull;
      if (project == null) {
        if (projects.projects.isEmpty) addProject();
        return;
      }
      onNewSession(
        context: context,
        project: project,
        displayName: desktopProjectDisplayName(context: context, project: project),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoCollapsed = constraints.maxWidth < autoCollapseBreakpoint;
        final loc = context.loc;
        // As the sidebar's row: absent until projects load, Add project while there are none.
        final hasProjects = context.select(
          (ProjectListCubit cubit) => switch (cubit.state) {
            ProjectListLoaded(:final projects) => projects.isNotEmpty,
            ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
          },
        );
        // Page-only commands, such as Mark as unread, stay with their page.
        final commands = [
          if (hasProjects != null)
            DesktopCommand(
              label: hasProjects ? loc.sessionListNewSession : loc.addProject,
              icon: TablerRegular.plus,
              shortcut: desktopShortcut(key: LogicalKeyboardKey.keyN),
              run: startNewSession,
            ),
          // An auto-collapsed sidebar cannot open, so it has no toggle.
          if (!autoCollapsed)
            DesktopCommand(
              label: loc.desktopToggleSidebar,
              icon: TablerRegular.layout_sidebar_left_collapse,
              shortcut: desktopShortcut(key: LogicalKeyboardKey.keyB),
              run: () => unawaited(sidebar.toggleCollapsed()),
            ),
          DesktopCommand(
            label: loc.settingsTitle,
            icon: TablerRegular.settings,
            shortcut: desktopShortcut(key: LogicalKeyboardKey.comma),
            run: onOpenSettings,
          ),
          DesktopCommand(
            label: loc.desktopGoBack,
            icon: TablerRegular.arrow_left,
            shortcut: desktopShortcut(key: LogicalKeyboardKey.bracketLeft),
            run: onGoBack,
          ),
        ];
        void openPalette() => unawaited(
          showDesktopCommandPalette(
            context: context,
            commands: commands,
            onOpenSession: onOpenSession,
            // The sidebar opens to show the list it filtered.
            onSelectProject: ({required projectId}) {
              sessions.selectProject(projectId: projectId);
              if (sidebar.state.collapsed) unawaited(sidebar.toggleCollapsed());
            },
          ),
        );
        bool collapsed(BuildContext context) =>
            context.select((DesktopSidebarCubit cubit) => cubit.state.collapsed) || autoCollapsed;
        final content = Stack(
          fit: StackFit.expand,
          children: [
            child,
            _SidebarRestoreButton(autoCollapsed: autoCollapsed, onPressed: () => unawaited(sidebar.toggleCollapsed())),
            const PositionedDirectional(
              top: PregoSpacing.lg,
              start: PregoSpacing.lg,
              end: PregoSpacing.lg,
              child: Align(alignment: Alignment.topCenter, child: DesktopConnectionPill()),
            ),
          ],
        );
        // Depth delimits: the sidebar floats as a panel over the base surface
        // the pages paint, so no divider separates them.
        final row = Row(
          children: [
            _SidebarPanel(
              windowHost: windowHost,
              // The gap beside the panel is the resize handle.
              resizeHandle: Builder(
                builder: (context) =>
                    collapsed(context) ? const SizedBox.expand() : _SidebarResizeHandle(sidebar: sidebar),
              ),
              child: DesktopSidebar(
                windowHost: windowHost,
                selectedSessionId: selectedSessionId,
                onOpenSession: onOpenSession,
                onStartNewSession: startNewSession,
                onOpenSearch: openPalette,
                sessionActions: sessionActions,
                onToggleCollapsed: () => unawaited(sidebar.toggleCollapsed()),
                onOpenBridgeSettings: onOpenBridgeSettings,
                onOpenSettings: onOpenSettings,
              ),
            ),
            Expanded(child: content),
          ],
        );
        // Only the animation follows a toggle: the sidebar reads its expansion
        // from it, so the panel's rows are not rebuilt to start one.
        final scaffold = Scaffold(
          body: Builder(
            builder: (context) {
              final isCollapsed = collapsed(context);
              return _ListPaneReporter(
                visible: !isCollapsed,
                child: _SidebarExpansionAnimator(
                  target: isCollapsed ? 0 : 1,
                  duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: row,
                ),
              );
            },
          ),
        );
        return CallbackShortcuts(
          bindings: {
            for (final command in commands) command.shortcut: command.run,
            desktopShortcut(key: LogicalKeyboardKey.keyK): openPalette,
          },
          child: Focus(autofocus: true, child: scaffold),
        );
      },
    );
  }
}

/// Tells the shared list whether the open sidebar shows it beside the page.
class const _ListPaneReporter({required final bool visible, required final Widget child}) extends StatefulWidget {
  @override
  State<_ListPaneReporter> createState() => _ListPaneReporterState();
}

class _ListPaneReporterState() extends State<_ListPaneReporter> {
  @override
  void initState() {
    super.initState();
    context.read<AllSessionsCubit>().setPaneVisible(isVisible: widget.visible);
  }

  @override
  void didUpdateWidget(_ListPaneReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) context.read<AllSessionsCubit>().setPaneVisible(isVisible: widget.visible);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Animates the sidebar's expansion like a [TweenAnimationBuilder], but hands
/// [child] the animation through [DesktopSidebarExpansion] instead of
/// rebuilding it with every value: only the parts that read the animation
/// update during a frame.
class const _SidebarExpansionAnimator({
  required final double target,
  required super.duration,
  required super.curve,
  required final Widget child,
}) extends ImplicitlyAnimatedWidget {
  @override
  ImplicitlyAnimatedWidgetState<_SidebarExpansionAnimator> createState() => _SidebarExpansionAnimatorState();
}

class _SidebarExpansionAnimatorState() extends ImplicitlyAnimatedWidgetState<_SidebarExpansionAnimator> {
  // One tween, retargeted in place by every change of [target].
  Tween<double>? _tween;
  Animation<double>? _expansion;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    // The visitor only constructs a tween for the target it was handed.
    _tween = switch (visitor(_tween, widget.target, (_) => Tween<double>(begin: widget.target))) {
      final Tween<double> tween => tween,
      _ => null,
    };
  }

  @override
  void didUpdateTweens() {
    if (_tween case final tween? when _expansion == null) _expansion = animation.drive(tween);
  }

  @override
  Widget build(BuildContext context) => DesktopSidebarExpansion(
    expansion: _expansion ?? kAlwaysCompleteAnimation,
    child: widget.child,
  );
}

/// The floating panel and the resize gap beside it. Collapsing slides both out
/// past the window's edge (D9) while the page widens into their room.
class const _SidebarPanel({
  required final WindowHost? windowHost,
  required final Widget resizeHandle,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = context.select((DesktopSidebarCubit cubit) => cubit.state.width);
    final expansion = DesktopSidebarExpansion.of(context);
    final panel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TitleBarStrip(
          windowHost: windowHost,
          child: FloatingSidebarPanel(key: const Key("desktop-cockpit-sidebar"), width: width, child: child),
        ),
        SizedBox(width: FloatingSidebarPanel.margin, child: resizeHandle),
      ],
    );
    return DesktopSidebarExpansionSelector<bool>(
      expansion: expansion,
      select: (expansion) => expansion > 0,
      // Hidden, it keeps its list and scroll offset but leaves the focus order
      // and the screen reader.
      builder: (context, shown) => Visibility(
        visible: shown,
        maintainState: true,
        child: DesktopSidebarExpansionBuilder(
          expansion: expansion,
          builder: (expansion, panel) => Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: expansion,
            child: panel,
          ),
          child: panel,
        ),
      ),
    );
  }
}

/// The panel's margins. On macOS the strip above the panel drags and zooms
/// the window.
class const _TitleBarStrip({required final WindowHost? windowHost, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final windowHost = this.windowHost;
    const margin = FloatingSidebarPanel.margin;
    final panel = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(margin, margin, 0, margin),
      child: child,
    );
    if (windowHost == null) return panel;
    return DesktopWindowDragArea(windowHost: windowHost, height: margin, zoomOnDoubleClick: true, child: panel);
  }
}

/// Brings a hidden sidebar back (D9) from the page's top-left corner, past
/// the traffic lights on macOS. It fades in as the sidebar slides away, riding
/// just ahead of the title that [DesktopSidebarRestoreInset] moves, so the two
/// never overlap.
class const _SidebarRestoreButton({required final bool autoCollapsed, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final expansion = DesktopSidebarExpansion.of(context);
    final loc = context.loc;
    const size = DesktopSidebarRestoreInset.buttonSize;
    final travel = DesktopSidebarRestoreInset.buttonStart + size;
    final towardStart = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    return PositionedDirectional(
      top: (DesktopPageToolbar.height - size) / 2,
      start: DesktopSidebarRestoreInset.buttonStart,
      child: DesktopSidebarExpansionSelector<bool>(
        expansion: expansion,
        select: (expansion) => expansion >= 1,
        builder: (context, open) => open
            ? const SizedBox.shrink()
            : DesktopSidebarExpansionBuilder(
                expansion: expansion,
                builder: (expansion, child) => Transform.translate(
                  offset: Offset(towardStart * travel * expansion, 0),
                  child: child,
                ),
                child: FadeTransition(
                  opacity: ReverseAnimation(expansion),
                  child: SizedBox.square(
                    dimension: size,
                    child: IconButton(
                      key: const Key("desktop-sidebar-restore"),
                      // A window too narrow for the sidebar keeps it hidden.
                      tooltip: autoCollapsed
                          ? loc.desktopSidebarExpand
                          : loc.desktopShortcutHint(
                              loc.desktopSidebarExpand,
                              defaultTargetPlatform == TargetPlatform.macOS ? "⌘B" : "Ctrl+B",
                            ),
                      padding: const EdgeInsets.all(PregoSpacing.sm),
                      onPressed: autoCollapsed ? null : onPressed,
                      icon: Icon(
                        TablerRegular.layout_sidebar_left_expand,
                        size: PregoIconSize.md,
                        color: autoCollapsed ? context.prego.colors.textDisabled : null,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class const _SidebarResizeHandle({required final DesktopSidebarCubit sidebar}) extends StatefulWidget {
  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState() extends State<_SidebarResizeHandle> {
  ({double width, double pointerX})? _dragOrigin;

  void _finishDrag() {
    // A tap or double-click also cancels the drag recognizer, without starting a drag.
    if (_dragOrigin == null) return;
    _dragOrigin = null;
    unawaited(widget.sidebar.saveLayout());
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    child: Tooltip(
      message: context.loc.desktopSidebarResize,
      child: GestureDetector(
        key: const Key("desktop-sidebar-resize"),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (details) =>
            _dragOrigin = (width: widget.sidebar.state.width, pointerX: details.globalPosition.dx),
        onHorizontalDragUpdate: (details) {
          if (_dragOrigin case final origin?) {
            widget.sidebar.resize(width: origin.width + details.globalPosition.dx - origin.pointerX);
          }
        },
        onHorizontalDragEnd: (_) => _finishDrag(),
        onHorizontalDragCancel: _finishDrag,
        onDoubleTap: () => unawaited(widget.sidebar.resetWidth()),
        child: const SizedBox.expand(),
      ),
    ),
  );
}
