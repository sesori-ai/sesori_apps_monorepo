import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Root-level desktop presentation for relay/bridge connection interruptions.
///
/// The shared mobile banner will move to `module_app_ui` in Step 14. Until the
/// desktop router and shared screens exist, the shell owns this equivalent
/// host so connection state is visible above the auth-gated window.
class DesktopConnectionBanner extends StatelessWidget {
  const new({super.key}) : _onRetry = null;

  const new connectionLost({super.key, required VoidCallback onRetry}) : _onRetry = onRetry;

  final VoidCallback? _onRetry;

  /// Returns the root banner for the states that need one.
  static Widget? maybeFor(BuildContext context) {
    final ConnectionOverlayCubit cubit = context.watch<ConnectionOverlayCubit>();
    return switch (cubit.state) {
      ConnectionOverlayBridgeOffline() => const DesktopConnectionBanner(),
      ConnectionOverlayConnectionLost() => DesktopConnectionBanner.connectionLost(onRetry: cubit.reconnect),
      ConnectionOverlayHidden() || ConnectionOverlayReconnecting() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRetry = _onRetry;
    return Semantics(
      container: true,
      liveRegion: true,
      child: onRetry == null
          ? const PregoInlineAlertsNotifications(
              type: PregoInlineAlertsNotificationsType.warning,
              title: "Bridge disconnected",
              icon: TablerRegular.broadcast_off,
            )
          : PregoInlineAlertsNotifications(
              type: PregoInlineAlertsNotificationsType.error,
              title: "Connection lost",
              icon: TablerRegular.cloud_off,
              primaryAction: PregoInlineAlertsNotificationsAction(
                label: "Reconnect",
                icon: TablerRegular.rotate_clockwise,
                onPressed: onRetry,
              ),
            ),
    );
  }
}
