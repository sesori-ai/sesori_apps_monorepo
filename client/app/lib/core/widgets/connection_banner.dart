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
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  /// Returns the banner for [PregoGlassScaffold.banner], or `null` when
  /// nothing should be shown. Watches [ConnectionOverlayCubit] (provided
  /// app-wide by `ConnectionOverlay` above the router), so the calling build
  /// re-runs on connection changes.
  static Widget? maybeFor(BuildContext context) => switch (context.watch<ConnectionOverlayCubit>().state) {
    ConnectionOverlayBridgeOffline() => const ConnectionBanner(),
    ConnectionOverlayHidden() || ConnectionOverlayReconnecting() || ConnectionOverlayConnectionLost() => null,
  };

  @override
  Widget build(BuildContext context) {
    // No reconnect action: while the bridge is offline the relay connection
    // stays alive and ConnectionService reconnects on its own the moment the
    // relay announces the bridge is back — the banner is purely informational.
    //
    // Deliberately does not read the cubit here: the nav banner slot keeps
    // rendering a retained copy of this widget while animating the banner
    // away, and that copy must keep showing stable content.
    //
    // Wrapped in a live region so VoiceOver/TalkBack announce the offline
    // status when the banner appears, even though focus doesn't move to it —
    // the same treatment (container + liveRegion, keeping the child's own text
    // semantics) Flutter's own SnackBar uses, so the title stays navigable as
    // well as announced. The nav slot excludes the departing retained copy from
    // semantics, so recovery doesn't re-announce.
    return Semantics(
      container: true,
      liveRegion: true,
      child: PregoInlineAlertsNotifications(
        type: PregoInlineAlertsNotificationsType.warning,
        title: context.loc.bridgeDisconnectedTitle,
        icon: TablerRegular.broadcast_off,
      ),
    );
  }
}
