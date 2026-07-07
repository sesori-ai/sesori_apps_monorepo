import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// The inline connection-status alert hosted in the top navigation.
///
/// [maybeFor] is the single decision point mapping [ConnectionOverlayCubit]
/// state to a screen's [PregoGlassScaffold.banner] slot; screens that own a
/// dedicated offline design (the project list's full-screen flows) simply
/// don't pass it while that design is showing.
///
/// Two variants:
/// - the default [ConnectionBanner] is the *bridge-offline* alert — purely
///   informational, because the relay connection stays alive and reconnects on
///   its own the moment the bridge is back;
/// - [ConnectionBanner.connectionLost] is the *relay-unreachable* alert, whose
///   auto-reconnect has stopped, so it carries a Retry action.
class ConnectionBanner extends StatelessWidget {
  /// The bridge-offline banner: informational only. The relay connection stays
  /// alive and `ConnectionService` reconnects the moment the bridge is back, so
  /// there is no action to offer.
  const ConnectionBanner({super.key}) : _onRetry = null;

  /// The connection-lost banner: the relay itself is unreachable and
  /// auto-reconnect has given up, so this variant carries a Retry action that
  /// re-triggers a relay reconnect via [onRetry].
  const ConnectionBanner.connectionLost({super.key, required VoidCallback onRetry}) : _onRetry = onRetry;

  /// Reconnect callback for the connection-lost variant; `null` for the
  /// bridge-offline variant, which self-heals and offers no action. Its
  /// nullness selects the variant at [build] time.
  final VoidCallback? _onRetry;

  /// Returns the banner for [PregoGlassScaffold.banner], or `null` when nothing
  /// should be shown. Watches [ConnectionOverlayCubit] (provided app-wide above
  /// the router), so the calling build re-runs on connection changes.
  ///
  /// The connection-lost variant captures the cubit's `reconnect` tear-off here
  /// rather than reading the cubit from the banner itself (see [build]).
  static Widget? maybeFor(BuildContext context) {
    final cubit = context.watch<ConnectionOverlayCubit>();
    return switch (cubit.state) {
      ConnectionOverlayBridgeOffline() => const ConnectionBanner(),
      ConnectionOverlayConnectionLost() => ConnectionBanner.connectionLost(onRetry: cubit.reconnect),
      ConnectionOverlayHidden() || ConnectionOverlayReconnecting() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately does not read the cubit here: the nav banner slot keeps
    // rendering a retained copy of this widget while animating the banner away,
    // and that copy must keep showing stable content. State is resolved once in
    // [maybeFor]; the retry action arrives as a pre-captured callback, never a
    // live cubit read.
    //
    // Wrapped in a live region so VoiceOver/TalkBack announce the status when
    // the banner appears, even though focus doesn't move to it — the same
    // treatment (container + liveRegion, keeping the child's own text semantics)
    // Flutter's own SnackBar uses, so the title stays navigable as well as
    // announced. The nav slot excludes the departing retained copy from
    // semantics, so recovery doesn't re-announce.
    final onRetry = _onRetry;
    return Semantics(
      container: true,
      liveRegion: true,
      child: onRetry == null
          ? PregoInlineAlertsNotifications(
              type: PregoInlineAlertsNotificationsType.warning,
              title: context.loc.bridgeDisconnectedTitle,
              icon: TablerRegular.broadcast_off,
            )
          : PregoInlineAlertsNotifications(
              type: PregoInlineAlertsNotificationsType.error,
              title: context.loc.connectionLostTitle,
              icon: TablerRegular.cloud_off,
              primaryAction: PregoInlineAlertsNotificationsAction(
                label: context.loc.connectionLostReconnect,
                icon: TablerRegular.rotate_clockwise,
                onPressed: onRetry,
              ),
            ),
    );
  }
}
