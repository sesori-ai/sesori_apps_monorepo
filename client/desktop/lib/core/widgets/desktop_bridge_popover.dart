import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

/// Quick actions for the local bridge; app preferences belong in Settings.
class const DesktopBridgePopover({
  super.key,
  required final VoidCallback close,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeControlCubit>().state;
    final controls = context.read<BridgeControlCubit>();
    final loc = context.loc;
    final takeOverAction = (
      label: loc.desktopBridgeTakeOver,
      command: controls.takeOver,
      hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
    );
    final ({String label, Future<void> Function() command, PregoButtonsSolidHierarchy hierarchy}) action =
        state.canTakeOver
        ? takeOverAction
        : switch (state.processState) {
            BridgeProcessContention() => takeOverAction,
            BridgeProcessStopped() => (
              label: loc.desktopBridgeStart,
              command: controls.startBridge,
              hierarchy: .primary,
            ),
            BridgeProcessStartFailed() => (
              label: loc.projectListRetry,
              command: controls.startBridge,
              hierarchy: .primary,
            ),
            BridgeProcessLoginRequired() || BridgeProcessCrashGiveUp() => (
              label: loc.projectListRetry,
              command: controls.recoverConnection,
              hierarchy: .primary,
            ),
            BridgeProcessStarting() ||
            BridgeProcessRunning() ||
            BridgeProcessStopping() ||
            BridgeProcessCrashRetryScheduled() => (
              label: loc.desktopBridgeStop,
              command: controls.stopBridge,
              hierarchy: .secondary,
            ),
          };
    return Padding(
      key: const Key("desktop-bridge-popover"),
      padding: const EdgeInsets.all(PregoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.desktopLocalBridgeTitle, style: context.prego.textTheme.textSm.bold),
          const SizedBox(height: PregoSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              state.statusLabel,
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ),
          const SizedBox(height: PregoSpacing.lg),
          PregoButtonsSolid(
            label: action.label,
            hierarchy: action.hierarchy,
            size: PregoButtonsSolidSize.md,
            fullWidth: true,
            onPressed: state.activity.locksCommands ? null : () => unawaited(action.command()),
          ),
          const SizedBox(height: PregoSpacing.sm),
          Divider(color: context.prego.colors.borderSecondary),
          if (state.canTakeOver && state.processState is BridgeProcessRunning)
            _BridgeAction(
              label: loc.desktopBridgeStop,
              icon: TablerRegular.player_stop,
              onPressed: state.activity.locksCommands ? null : () => unawaited(controls.stopBridge()),
            ),
          _BridgeAction(
            label: loc.desktopBridgeOpenLogs,
            icon: TablerRegular.file_text,
            onPressed: () => unawaited(controls.openLogs()),
          ),
          _BridgeAction(
            label: loc.desktopBridgeSettings,
            icon: TablerRegular.settings,
            onPressed: () {
              close();
              onOpenSettings();
            },
          ),
        ],
      ),
    );
  }
}

class const _BridgeAction({
  required final String label,
  required final IconData icon,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: PregoIconSize.md),
    label: Text(label, style: context.prego.textTheme.textSm.medium),
    style: TextButton.styleFrom(
      foregroundColor: context.prego.colors.textSecondary,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.md),
    ),
  );
}
