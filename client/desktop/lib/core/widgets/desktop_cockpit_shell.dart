import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_sidebar.dart";

export "desktop_sidebar.dart" show DesktopCockpitDestination;

/// One inventory and one layout owner per signed-in cockpit.
class const DesktopCockpitCubitProvider({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => createProjectListCubit(locator: getIt)),
      BlocProvider(create: (_) => DesktopSidebarCubit(repository: getIt())),
    ],
    child: child,
  );
}

/// Product-shell navigation and supervision chrome around the desktop cockpit.
class const DesktopCockpitShell({
  super.key,
  required final DesktopCockpitDestination destination,
  required final String? selectedProjectId,
  required final ProjectOpenedCallback onOpenProject,
  required final VoidCallback onOpenBridge,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final autoCollapsed = constraints.maxWidth < autoCollapseBreakpoint;
        final collapsed = layout.collapsed || autoCollapsed;
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                key: const Key("desktop-cockpit-sidebar"),
                width: collapsed ? compactWidth : layout.width,
                child: DesktopSidebar(
                  collapsed: collapsed,
                  autoCollapsed: autoCollapsed,
                  destination: destination,
                  selectedProjectId: selectedProjectId,
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
                  onOpenBridge: onOpenBridge,
                  onOpenSettings: onOpenSettings,
                ),
              ),
              if (!collapsed)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Tooltip(
                    message: context.loc.desktopSidebarResize,
                    child: GestureDetector(
                      key: const Key("desktop-sidebar-resize"),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) =>
                          sidebar.resize(width: sidebar.state.width + details.delta.dx),
                      onHorizontalDragEnd: (_) => unawaited(sidebar.saveLayout()),
                      onHorizontalDragCancel: () => unawaited(sidebar.saveLayout()),
                      onDoubleTap: () => unawaited(sidebar.resetWidth()),
                      child: const SizedBox(width: 6, child: VerticalDivider(width: 1)),
                    ),
                  ),
                )
              else
                const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    const DesktopSupervisionNotice(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Exceptional bridge states shown above every cockpit destination.
class const DesktopSupervisionNotice({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeControlCubit>().state;
    final controls = context.read<BridgeControlCubit>();
    final locked = state.activity.locksCommands;

    final _DesktopSupervisionNoticeData? notice;
    if (state.canTakeOver) {
      notice = _DesktopSupervisionNoticeData(
        icon: TablerRegular.arrows_exchange,
        message: "Another bridge currently owns this account connection.",
        primaryLabel: "Take Over",
        onPrimary: locked ? null : () => unawaited(controls.takeOver()),
        secondaryLabel: null,
        onSecondary: null,
        isError: false,
      );
    } else {
      notice = switch (state.processState) {
        BridgeProcessLoginRequired() => _DesktopSupervisionNoticeData(
          icon: TablerRegular.user_exclamation,
          message: "Your Sesori account is required before the local bridge can start.",
          primaryLabel: "Start Bridge",
          onPrimary: locked ? null : () => unawaited(controls.recoverConnection()),
          secondaryLabel: null,
          onSecondary: null,
          isError: false,
        ),
        BridgeProcessCrashGiveUp() => _DesktopSupervisionNoticeData(
          icon: TablerRegular.alert_triangle,
          message: "The local bridge stopped after repeated crashes.",
          primaryLabel: "Retry",
          onPrimary: locked ? null : () => unawaited(controls.recoverConnection()),
          secondaryLabel: "Open Logs",
          onSecondary: () => unawaited(controls.openLogs()),
          isError: true,
        ),
        BridgeProcessContention() => null,
        BridgeProcessStopped() ||
        BridgeProcessStarting() ||
        BridgeProcessRunning() ||
        BridgeProcessStopping() ||
        BridgeProcessCrashRetryScheduled() => null,
      };
    }
    if (notice == null) {
      return const SizedBox.shrink();
    }

    final background = notice.isError ? context.prego.colors.bgErrorSecondary : context.prego.colors.bgWarningSecondary;
    final foreground = notice.isError ? context.prego.colors.textErrorPrimary : context.prego.colors.textWarningPrimary;
    return ColoredBox(
      key: const Key("desktop-supervision-notice"),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.sm),
        child: Row(
          children: [
            Icon(notice.icon, color: foreground, size: 20),
            const SizedBox(width: PregoSpacing.sm),
            Expanded(
              child: Text(
                notice.message,
                style: context.prego.textTheme.textSm.medium.copyWith(color: foreground),
              ),
            ),
            if (notice.secondaryLabel case final label?)
              TextButton(
                onPressed: notice.onSecondary,
                child: Text(label),
              ),
            TextButton(
              onPressed: notice.onPrimary,
              child: Text(notice.primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class const _DesktopSupervisionNoticeData({
  required final IconData icon,
  required final String message,
  required final String primaryLabel,
  required final VoidCallback? onPrimary,
  required final String? secondaryLabel,
  required final VoidCallback? onSecondary,
  required final bool isError,
});
