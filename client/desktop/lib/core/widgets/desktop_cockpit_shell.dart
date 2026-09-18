import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_connection_pill.dart";
import "desktop_sidebar.dart";

/// Shared project/recent inventories and one layout owner per signed-in cockpit.
class const DesktopCockpitCubitProvider({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => createProjectListCubit(locator: getIt)),
      BlocProvider(
        create: (_) => RecentSessionsCubit(
          sessionListService: getIt<SessionListService>(),
          connectionService: getIt<ConnectionService>(),
          sseEventTracker: getIt<SseEventTracker>(),
          sessionUnseenTracker: getIt<SessionUnseenTracker>(),
          catalogRescanService: getIt<CatalogRescanService>(),
        ),
      ),
      BlocProvider(create: (_) => DesktopSidebarCubit(repository: getIt())),
    ],
    child: child,
  );
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
  required final Widget child,
}) extends StatelessWidget {
  static const double compactWidth = 56;
  static const double autoCollapseBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    final layout = context.watch<DesktopSidebarCubit>().state;
    final sidebar = context.read<DesktopSidebarCubit>();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final autoCollapsed = constraints.maxWidth < autoCollapseBreakpoint;
        final collapsed = layout.collapsed || autoCollapsed;
        return Scaffold(
          body: TweenAnimationBuilder<double>(
            tween: Tween(begin: collapsed ? 0 : 1, end: collapsed ? 0 : 1),
            duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, expansion, _) => Row(
              children: [
                SizedBox(
                  key: const Key("desktop-cockpit-sidebar"),
                  width: compactWidth + (layout.width - compactWidth) * expansion,
                  child: DesktopSidebar(
                    expansion: expansion,
                    autoCollapsed: autoCollapsed,
                    selectedProjectId: selectedProjectId,
                    selectedSessionId: selectedSessionId,
                    onOpenSession: onOpenSession,
                    onNewSession: onNewSession,
                    sessionActions: sessionActions,
                    onToggleCollapsed: () => unawaited(sidebar.toggleCollapsed()),
                    onOpenProjects: onOpenProjects,
                    onAddProject: () => unawaited(
                      showAddProjectDialog(
                        context: context,
                        cubit: context.read<ProjectListCubit>(),
                        connectionService: getIt<ConnectionService>(),
                      ),
                    ),
                    onOpenProject: onOpenProject,
                    onOpenBridgeSettings: onOpenBridgeSettings,
                    onOpenSettings: onOpenSettings,
                  ),
                ),
                SizedBox(
                  width: 1 + 5 * expansion,
                  child: collapsed
                      ? VerticalDivider(width: 1, color: context.prego.colors.borderSecondary)
                      : _SidebarResizeHandle(sidebar: sidebar),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
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
        child: VerticalDivider(width: 1, color: context.prego.colors.borderSecondary),
      ),
    ),
  );
}
