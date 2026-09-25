import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
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
        icon: Icon(notice.icon, color: foreground, size: PregoIconSize.md),
      );
    }
    final messageStyle = context.prego.textTheme.textSm.regular.copyWith(color: colors.textPrimary);
    final firstLineHeight = switch (messageStyle) {
      TextStyle(:final fontSize?, :final height?) => fontSize * height,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.md),
      child: DecoratedBox(
        key: const Key("desktop-bridge-recovery"),
        // Neutral surface: only the icon and border carry the status colour, so
        // the message and actions stay legible in both themes.
        decoration: BoxDecoration(
          color: colors.bgSecondary,
          border: Border.all(color: notice.isError ? colors.borderErrorSubtle : colors.borderSecondary),
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
                    // Centred on the first line, the 13px glyph's ink spans the
                    // message's cap top to its baseline; a larger icon towers
                    // over the text.
                    SizedBox(
                      height: firstLineHeight,
                      child: Icon(notice.icon, size: 13, color: foreground),
                    ),
                    const SizedBox(width: PregoSpacing.sm),
                    Expanded(child: Text(notice.message, style: messageStyle)),
                  ],
                ),
                const SizedBox(height: PregoSpacing.lg),
                Wrap(
                  spacing: PregoSpacing.xs,
                  runSpacing: PregoSpacing.sm,
                  children: [
                    PregoButtonsSolid(
                      label: notice.primary.label,
                      hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                      size: PregoButtonsSolidSize.xs,
                      onPressed: onPrimary,
                    ),
                    if (notice.secondary case final action?)
                      PregoButtonsSolid(
                        label: action.label,
                        hierarchy: PregoButtonsSolidHierarchy.tertiary,
                        size: PregoButtonsSolidSize.xs,
                        onPressed: action.onPressed,
                      ),
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
