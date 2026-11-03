import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

/// Quick actions for the local bridge; app preferences belong in Settings.
class const DesktopBridgePopover({
  super.key,
  required final VoidCallback close,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  static const double _statusDotSize = 8;
  static const Duration _statusDetailTransition = Duration(milliseconds: 200);

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
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // In line with the rows' icons, here and in the menu around this.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
            // A hint arriving or leaving grows or shrinks the panel smoothly
            // instead of snapping the actions below it.
            child: AnimatedSize(
              duration: context.isReducedMotion ? Duration.zero : _statusDetailTransition,
              curve: Curves.easeOut,
              alignment: AlignmentDirectional.topStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.desktopLocalBridgeTitle, style: context.prego.textTheme.textSm.bold),
                  const SizedBox(height: PregoSpacing.xs),
                  Row(
                    children: [
                      // A status dot, not a glyph: no icon token applies.
                      Icon(
                        TablerSolid.circle,
                        size: _statusDotSize,
                        color: desktopBridgeStatusColor(colors: context.prego.colors, state: state),
                      ),
                      const SizedBox(width: PregoSpacing.sm),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            state.statusLabel,
                            style: context.prego.textTheme.textSm.regular.copyWith(
                              color: context.prego.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: _statusDetailTransition,
                    // The outgoing hint fades in place without being re-read.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.topStart,
                      children: [
                        for (final child in previous) ExcludeSemantics(child: child),
                        ?current,
                      ],
                    ),
                    child: switch (state.statusDetail) {
                      final detail? => Padding(
                        key: ValueKey(detail),
                        // Under the status text, past the dot.
                        padding: const EdgeInsetsDirectional.only(
                          start: _statusDotSize + PregoSpacing.sm,
                          top: PregoSpacing.xs,
                        ),
                        // Announced with the status, so the remediation is read too.
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            detail,
                            style: context.prego.textTheme.textXs.regular.copyWith(
                              color: context.prego.colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
          ),
          // Recovery actions stay a solid button; stopping a healthy bridge is
          // routine, so it joins the quiet rows.
          if (action.hierarchy != PregoButtonsSolidHierarchy.secondary) ...[
            const SizedBox(height: PregoSpacing.lg),
            PregoButtonsSolid(
              label: action.label,
              hierarchy: action.hierarchy,
              size: PregoButtonsSolidSize.md,
              fullWidth: true,
              onPressed: state.activity.locksCommands ? null : () => unawaited(action.command()),
            ),
          ],
          const SizedBox(height: PregoSpacing.sm),
          Divider(color: context.prego.colors.borderSecondary),
          if (action.hierarchy == PregoButtonsSolidHierarchy.secondary ||
              (state.canTakeOver && state.processState is BridgeProcessRunning))
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
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.prego.colors.textSecondary,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs, vertical: PregoSpacing.md),
    ),
    // The menu rows' icon and gap, so the labels line up with theirs.
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: PregoSpacing.lg),
        Expanded(child: Text(label, style: context.prego.textTheme.textSm.medium)),
      ],
    ),
  );
}

/// The local bridge's status colour: green only when fully healthy, amber
/// while it needs attention or is changing, red when it failed.
Color desktopBridgeStatusColor({required PregoColors colors, required BridgeControlState state}) => state.canTakeOver
    ? colors.textWarningPrimary
    : switch (state.processState) {
        BridgeProcessStopped() => colors.textDisabled,
        BridgeProcessStartFailed() || BridgeProcessCrashGiveUp() => colors.textErrorPrimary,
        BridgeProcessRunning()
            when state.controlStatus.helperOnline &&
                state.controlStatus.startup == ControlStartupState.ready &&
                state.controlStatus.relay == ControlRelayConnectionState.connected &&
                state.controlStatus.unhealthyPlugins.isEmpty =>
          colors.textSuccessPrimary,
        BridgeProcessLoginRequired() ||
        BridgeProcessStarting() ||
        BridgeProcessRunning() ||
        BridgeProcessStopping() ||
        BridgeProcessContention() ||
        BridgeProcessCrashRetryScheduled() => colors.textWarningPrimary,
      };
