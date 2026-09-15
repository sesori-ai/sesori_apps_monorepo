import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

/// Content of the sidebar's anchored Bridge control, not another routed page.
class const DesktopBridgePopover({
  super.key,
  required final VoidCallback close,
  required final VoidCallback onOpenSettings,
}) extends StatefulWidget {
  @override
  State<DesktopBridgePopover> createState() => _DesktopBridgePopoverState();
}

class _DesktopBridgePopoverState extends State<DesktopBridgePopover> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<BridgeControlCubit>().refreshLaunchAtLogin());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeControlCubit>().state;
    final controls = context.read<BridgeControlCubit>();
    final relay = context.watch<ConnectionOverlayCubit>().state;
    final loc = context.loc;
    final locked = state.activity.locksCommands;
    final relayLabel = switch (relay) {
      ConnectionOverlayHidden(:final connected) =>
        connected ? loc.desktopBridgeClientConnected : loc.desktopBridgeClientDisconnected,
      ConnectionOverlayReconnecting() => loc.connectionReconnectingTitle,
      ConnectionOverlayConnectionLost() => loc.connectionLostTitle,
      ConnectionOverlayBridgeOffline() => loc.bridgeDisconnectedTitle,
    };
    return Padding(
      key: const Key("desktop-bridge-popover"),
      padding: const EdgeInsets.all(PregoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.statusLabel, style: context.prego.textTheme.textSm.bold),
          const SizedBox(height: PregoSpacing.xs),
          Text(
            relayLabel,
            style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.md),
          _BridgeToggle(
            label: loc.desktopBridgeTitle,
            value: state.toggleTarget == BridgeProcessDesiredState.off,
            onChanged: locked ? null : (_) => unawaited(controls.toggleBridge()),
          ),
          if (state.canTakeOver)
            _BridgeAction(
              label: loc.desktopBridgeTakeOver,
              icon: TablerRegular.arrows_exchange,
              onPressed: locked ? null : () => unawaited(controls.takeOver()),
            ),
          _BridgeToggle(
            label: loc.desktopBridgeLaunchAtLogin,
            value: state.launchAtLoginEnabled,
            onChanged: locked ? null : (_) => unawaited(controls.toggleLaunchAtLogin()),
          ),
          Divider(color: context.prego.colors.borderSecondary),
          _BridgeAction(
            label: loc.desktopBridgeOpenLogs,
            icon: TablerRegular.file_text,
            onPressed: () => unawaited(controls.openLogs()),
          ),
          _BridgeAction(
            label: loc.desktopBridgeSettings,
            icon: TablerRegular.settings,
            onPressed: () {
              widget.close();
              widget.onOpenSettings();
            },
          ),
          _BridgeAction(
            label: loc.desktopBridgeQuit,
            icon: TablerRegular.power,
            onPressed: locked
                ? null
                : () {
                    widget.close();
                    unawaited(controls.quit());
                  },
          ),
        ],
      ),
    );
  }
}

class const _BridgeToggle({
  required final String label,
  required final bool value,
  required final ValueChanged<bool>? onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: PregoSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.prego.textTheme.textSm.medium)),
          const SizedBox(width: PregoSpacing.md),
          PregoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

class const _BridgeAction({
  required final String label,
  required final IconData icon,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label, style: context.prego.textTheme.textSm.medium),
    style: TextButton.styleFrom(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.md),
    ),
  );
}
