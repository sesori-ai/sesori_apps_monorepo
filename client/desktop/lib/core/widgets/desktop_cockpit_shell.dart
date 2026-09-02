import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

/// Product-shell navigation and supervision chrome around the desktop cockpit.
class const DesktopCockpitShell({
  super.key,
  required final DesktopCockpitDestination destination,
  required final VoidCallback onOpenBridge,
  required final VoidCallback onOpenProjects,
  required final VoidCallback onOpenSettings,
  required final Future<void> Function({required BuildContext context}) onRecoverBridge,
  required final Widget child,
}) extends StatelessWidget {
  static const double _extendedBreakpoint = 1120;
  static const String _bridgeLabel = "Bridge";
  static const String _projectsLabel = "Projects";
  static const String _settingsLabel = "Settings";

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extended = constraints.maxWidth >= _extendedBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                key: const Key("desktop-cockpit-sidebar"),
                extended: extended,
                selectedIndex: destination.index,
                onDestinationSelected: (index) => switch (DesktopCockpitDestination.values[index]) {
                  DesktopCockpitDestination.bridge => onOpenBridge(),
                  DesktopCockpitDestination.projects => onOpenProjects(),
                  DesktopCockpitDestination.settings => onOpenSettings(),
                },
                leading: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
                  child: Semantics(
                    label: "Sesori",
                    child: const Icon(TablerRegular.code, size: 28),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(TablerRegular.server),
                    label: Text(_bridgeLabel),
                  ),
                  NavigationRailDestination(
                    icon: Icon(TablerRegular.folders),
                    label: Text(_projectsLabel),
                  ),
                  NavigationRailDestination(
                    icon: Icon(TablerRegular.settings),
                    label: Text(_settingsLabel),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    DesktopSupervisionNotice(
                      onRecoverBridge: () => onRecoverBridge(context: context),
                    ),
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

/// Stable destinations owned by the desktop shell rather than GoRouter strings.
enum DesktopCockpitDestination() {
  bridge,
  projects,
  settings,
}

/// Exceptional bridge states shown above every cockpit destination.
class const DesktopSupervisionNotice({
  super.key,
  required final Future<void> Function() onRecoverBridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeControlCubit>().state;
    final controls = context.read<BridgeControlCubit>();
    final locked = state.activity.locksCommands;

    final notice = switch (state.processState) {
      BridgeProcessLoginRequired() => _DesktopSupervisionNoticeData(
        icon: TablerRegular.user_exclamation,
        message: "Your Sesori account is required before the local bridge can start.",
        primaryLabel: "Start Bridge",
        onPrimary: locked ? null : () => unawaited(onRecoverBridge()),
        secondaryLabel: null,
        onSecondary: null,
        isError: false,
      ),
      BridgeProcessCrashGiveUp() => _DesktopSupervisionNoticeData(
        icon: TablerRegular.alert_triangle,
        message: "The local bridge stopped after repeated crashes.",
        primaryLabel: "Retry",
        onPrimary: locked ? null : () => unawaited(onRecoverBridge()),
        secondaryLabel: "Open Logs",
        onSecondary: () => unawaited(controls.openLogs()),
        isError: true,
      ),
      BridgeProcessContention() => _DesktopSupervisionNoticeData(
        icon: TablerRegular.arrows_exchange,
        message: "Another bridge currently owns this account connection.",
        primaryLabel: "Take Over",
        onPrimary: locked ? null : () => unawaited(controls.takeOver()),
        secondaryLabel: null,
        onSecondary: null,
        isError: false,
      ),
      BridgeProcessStopped() ||
      BridgeProcessStarting() ||
      BridgeProcessRunning() ||
      BridgeProcessStopping() ||
      BridgeProcessCrashRetryScheduled() =>
        state.canTakeOver
            ? _DesktopSupervisionNoticeData(
                icon: TablerRegular.arrows_exchange,
                message: "Another bridge currently owns this account connection.",
                primaryLabel: "Take Over",
                onPrimary: locked ? null : () => unawaited(controls.takeOver()),
                secondaryLabel: null,
                onSecondary: null,
                isError: false,
              )
            : null,
    };
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
