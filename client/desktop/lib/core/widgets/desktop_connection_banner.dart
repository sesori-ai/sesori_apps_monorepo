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
  const new({super.key}) : _onRetry = null, _isReconnecting = false;

  const new reconnecting({super.key}) : _onRetry = null, _isReconnecting = true;

  const new connectionLost({super.key, required VoidCallback onRetry})
    : _onRetry = onRetry,
      _isReconnecting = false;

  final VoidCallback? _onRetry;

  /// Selects the reconnecting variant among the action-less banners.
  final bool _isReconnecting;

  /// Returns the root banner for the states that need one.
  static Widget? maybeFor(BuildContext context) {
    final ConnectionOverlayCubit cubit = context.watch<ConnectionOverlayCubit>();
    return switch (cubit.state) {
      ConnectionOverlayBridgeOffline() => const DesktopConnectionBanner(),
      ConnectionOverlayReconnecting() => const DesktopConnectionBanner.reconnecting(),
      ConnectionOverlayConnectionLost() => DesktopConnectionBanner.connectionLost(onRetry: cubit.reconnect),
      ConnectionOverlayHidden() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRetry = _onRetry;
    return Semantics(
      container: true,
      liveRegion: true,
      child: onRetry == null
          ? PregoInlineAlertsNotifications(
              type: PregoInlineAlertsNotificationsType.warning,
              title: _isReconnecting ? "Reconnecting…" : "Bridge disconnected",
              icon: _isReconnecting ? TablerRegular.cloud_off : TablerRegular.broadcast_off,
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
