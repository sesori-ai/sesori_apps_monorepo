import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

typedef _RecoveryAction = ({String label, VoidCallback onPressed});

/// Exceptional supervision stays beside navigation, never above routed content.
class const DesktopBridgeRecoveryCard({
  super.key,

  /// Shown as one icon button, while the sidebar is not fully open.
  required final bool compact,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeControlCubit>().state;
    final controls = context.read<BridgeControlCubit>();
    final loc = context.loc;
    final ({IconData icon, String message, _RecoveryAction primary, _RecoveryAction? secondary, bool isError})? notice;
    if (state.canTakeOver) {
      notice = (
        icon: TablerRegular.arrows_exchange,
        message: loc.desktopBridgeTakenOver,
        primary: (label: loc.desktopBridgeTakeOver, onPressed: () => unawaited(controls.takeOver())),
        secondary: null,
        isError: false,
      );
    } else {
      notice = switch (state.processState) {
        BridgeProcessLoginRequired() => (
          icon: TablerRegular.user_exclamation,
          message: loc.desktopBridgeLoginRequired,
          primary: (label: loc.desktopBridgeStart, onPressed: () => unawaited(controls.recoverConnection())),
          secondary: null,
          isError: false,
        ),
        BridgeProcessStartFailed(:final message) => (
          icon: TablerRegular.alert_triangle,
          message: message,
          primary: (label: loc.projectListRetry, onPressed: () => unawaited(controls.startBridge())),
          secondary: null,
          isError: true,
        ),
        BridgeProcessCrashGiveUp() => (
          icon: TablerRegular.alert_triangle,
          message: loc.desktopBridgeCrashGiveUp,
          primary: (label: loc.projectListRetry, onPressed: () => unawaited(controls.recoverConnection())),
          secondary: (label: loc.desktopBridgeOpenLogs, onPressed: () => unawaited(controls.openLogs())),
          isError: true,
        ),
        BridgeProcessContention() ||
        BridgeProcessStopped() ||
        BridgeProcessStarting() ||
        BridgeProcessRunning() ||
        BridgeProcessStopping() ||
        BridgeProcessCrashRetryScheduled() => null,
      };
    }
    if (notice == null) return const SizedBox.shrink();
    final colors = context.prego.colors;
    final foreground = notice.isError ? colors.textErrorPrimary : colors.textWarningPrimary;
    final onPrimary = state.activity.locksCommands ? null : notice.primary.onPressed;
    if (compact) {
      return IconButton(
        key: const Key("desktop-bridge-recovery"),
        tooltip: "${notice.message} ${notice.primary.label}",
        onPressed: onPrimary,
        icon: Icon(notice.icon, color: foreground, size: 20),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.md),
      child: DecoratedBox(
        key: const Key("desktop-bridge-recovery"),
        decoration: BoxDecoration(
          color: notice.isError ? colors.bgErrorSecondary : colors.bgWarningSecondary,
          borderRadius: BorderRadius.circular(PregoRadius.lg),
        ),
        // Long bundle-repair guidance stays usable at the 480px window minimum.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PregoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(notice.icon, size: 18, color: foreground),
                    const SizedBox(width: PregoSpacing.sm),
                    Expanded(
                      child: Text(
                        notice.message,
                        style: context.prego.textTheme.textXs.medium.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: PregoSpacing.sm,
                  children: [
                    TextButton(onPressed: onPrimary, child: Text(notice.primary.label)),
                    if (notice.secondary case final action?)
                      TextButton(onPressed: action.onPressed, child: Text(action.label)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
