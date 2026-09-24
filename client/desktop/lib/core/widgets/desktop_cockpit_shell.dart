import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_command_palette.dart";
import "desktop_connection_pill.dart";
import "desktop_sidebar.dart";
import "desktop_sidebar_expansion.dart";
import "desktop_window_drag_area.dart";

/// Shared project/recent inventories and one layout owner per signed-in cockpit.
class const DesktopCockpitCubitProvider({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RepositoryProvider<RecentSessionInventoryService>(
    lazy: false,
    create: (_) => getIt<RecentSessionInventoryService>(),
    dispose: (inventory) => unawaited(inventory.dispose()),
    child: RepositoryProvider<ProjectInventoryService>(
      create: (_) => getIt<ProjectInventoryService>(),
      dispose: (inventory) => unawaited(inventory.dispose()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ProjectListCubit(inventoryService: context.read<ProjectInventoryService>()),
          ),
          BlocProvider(
            lazy: false,
            create: (context) => RecentSessionsCubit(inventoryService: context.read<RecentSessionInventoryService>()),
          ),
          BlocProvider(create: (_) => DesktopSidebarCubit(repository: getIt())),
          // Outlives every page and the sidebar, so an Undo window survives navigation.
          BlocProvider(create: (_) => PendingSessionArchiveCubit(repository: getIt())),
          BlocProvider(
            create: (context) => DesktopSidebarRefreshCubit(
              service: getIt<DesktopSidebarRefreshService>(
                param1: context.read<ProjectInventoryService>(),
                param2: context.read<RecentSessionInventoryService>(),
              ),
            ),
          ),
        ],
        child: PendingArchiveAlerts(navigatorKey: null, child: child),
      ),
    ),
  );
}

/// A session the user marks unread stays out of Activity until the agent moves
/// on. [context] must sit under [DesktopCockpitCubitProvider].
void deferMarkedUnreadSession({required BuildContext context, required Session session}) {
  final updatedAt = session.time?.updated;
  if (updatedAt == null) return;
  unawaited(context.read<DesktopSidebarCubit>().deferSession(sessionId: session.id, updatedAt: updatedAt));
}

/// Product-shell navigation and supervision chrome around the desktop cockpit.
class const DesktopCockpitShell({
  super.key,
  required final String? selectedProjectId,
  required final String? selectedSessionId,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final ProjectOpenedCallback onNewSession,
  required final SessionListActionDispatcher sessionActions,
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenBridgeSettings,
  required final VoidCallback onOpenProjects,
  required final VoidCallback onOpenSettings,

  /// Leaves a pushed page; a page reached from the sidebar has nowhere to go.
  required final VoidCallback onGoBack,
  required final Widget child,
}) extends StatelessWidget {
  static const double compactWidth = 56;
  static const double autoCollapseBreakpoint = 760;
  static const double _panelRadius = 14;

  /// Where the panel starts as a rail on macOS: below the traffic lights, which
  /// are wider than it. Expanded, the panel runs to the top and carries them.
  static const double railTopUnderTrafficLights = 42;

  @override
  Widget build(BuildContext context) {
    final sidebar = context.read<DesktopSidebarCubit>();
    // macOS only: the window has no title bar of its own (see `FlutterWindowHost`).
    final windowHost = defaultTargetPlatform == TargetPlatform.macOS ? getIt<WindowHost>() : null;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        child,
        const PositionedDirectional(
          top: PregoSpacing.lg,
          start: PregoSpacing.lg,
          end: PregoSpacing.lg,
          child: Align(alignment: Alignment.topCenter, child: DesktopConnectionPill()),
        ),
      ],
    );
    void addProject() => unawaited(
      showAddProjectDialog(
        context: context,
        cubit: context.read<ProjectListCubit>(),
        connectionService: getIt<ConnectionService>(),
      ),
    );
    // The open project, else the most recently active one (the inventory's
    // order); with no project yet, adding one is the only useful next step.
    // An open project missing from the inventory (hidden meanwhile) is never
    // swapped for another one.
    void startNewSession() {
      final projects = context.read<ProjectListCubit>().state;
      if (projects is! ProjectListLoaded) return;
      final project = selectedProjectId == null
          ? projects.projects.firstOrNull
          : projects.projects.where((project) => project.id == selectedProjectId).firstOrNull;
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
        // Page-only commands, such as Mark as unread, stay with their page.
        final commands = [
          DesktopCommand(
            label: loc.sessionListNewSession,
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
            onOpenProject: onOpenProject,
          ),
        );
        bool collapsed(BuildContext context) =>
            context.select((DesktopSidebarCubit cubit) => cubit.state.collapsed) || autoCollapsed;
        // Depth delimits: the sidebar floats as a panel over the base surface
        // the pages paint, so no divider separates them.
        final row = Row(
          children: [
            _SidebarPanel(
              windowHost: windowHost,
              child: DesktopSidebar(
                windowHost: windowHost,
                autoCollapsed: autoCollapsed,
                selectedProjectId: selectedProjectId,
                selectedSessionId: selectedSessionId,
                onOpenSession: onOpenSession,
                onNewSession: onNewSession,
                onStartNewSession: startNewSession,
                onOpenSearch: openPalette,
                sessionActions: sessionActions,
                onToggleCollapsed: () => unawaited(sidebar.toggleCollapsed()),
                onOpenProjects: onOpenProjects,
                onAddProject: addProject,
                onOpenProject: onOpenProject,
                onOpenBridgeSettings: onOpenBridgeSettings,
                onOpenSettings: onOpenSettings,
              ),
            ),
            // The gap beside the panel is the resize handle.
            Builder(
              builder: (context) => SizedBox(
                width: DesktopSidebar.panelMargin,
                child: collapsed(context) ? null : _SidebarResizeHandle(sidebar: sidebar),
              ),
            ),
            Expanded(child: content),
          ],
        );
        // Only the animation follows a toggle: the sidebar reads its expansion
        // from it, so the panel's rows are not rebuilt to start one.
        final scaffold = Scaffold(
          body: Builder(
            builder: (context) => _SidebarExpansionAnimator(
              target: collapsed(context) ? 0 : 1,
              duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: row,
            ),
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

/// The floating panel, as wide as the sidebar's width and expansion make it.
class const _SidebarPanel({required final WindowHost? windowHost, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = context.select((DesktopSidebarCubit cubit) => cubit.state.width);
    const compactWidth = DesktopCockpitShell.compactWidth;
    const radius = DesktopCockpitShell._panelRadius;
    return DesktopSidebarExpansionBuilder(
      expansion: DesktopSidebarExpansion.of(context),
      builder: (expansion, panel) => _TitleBarStrip(
        windowHost: windowHost,
        expansion: expansion,
        // The width bounds and the rail measure the panel itself.
        child: Container(
          key: const Key("desktop-cockpit-sidebar"),
          width: compactWidth + (width - compactWidth) * expansion,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: context.prego.shadows.lg,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.prego.colors.borderSecondary),
          ),
          child: panel,
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }
}

/// The panel's margins. On macOS the rail makes room for the traffic lights
/// above it, and whatever is left above the panel drags and zooms the window.
class const _TitleBarStrip({
  required final WindowHost? windowHost,
  required final double expansion,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final windowHost = this.windowHost;
    const margin = DesktopSidebar.panelMargin;
    final top = windowHost == null
        ? margin
        : DesktopCockpitShell.railTopUnderTrafficLights +
              (margin - DesktopCockpitShell.railTopUnderTrafficLights) * expansion;
    final panel = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(margin, top, 0, margin),
      child: child,
    );
    if (windowHost == null) return panel;
    return DesktopWindowDragArea(windowHost: windowHost, height: top, zoomOnDoubleClick: true, child: panel);
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
