import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../logging/logging.dart";
import "../../services/registered_bridges_service.dart";
import "bridge_identity_state.dart";

/// Owns the identity of the machine the app is paired with: the name the
/// Projects top navigation carries under its title, and the machine the
/// bridge-offline recovery view says it is trying to reach.
///
/// Deliberately separate from the project list. The identity comes from the
/// account's registered bridges on the auth server — not from anything a bridge
/// serves — and it resolves once per connection rather than per list refresh.
/// Owning it here keeps it steady across the list's own loading → loaded →
/// failed churn, so the bar's subtitle row resolves once and then stays put
/// instead of blinking back to a placeholder on every reload.
class BridgeIdentityCubit extends Cubit<BridgeIdentityState> {
  final RegisteredBridgesService _registeredBridgesService;
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  BridgeIdentityCubit({
    required RegisteredBridgesService registeredBridgesService,
    required ConnectionService connectionService,
  }) : _registeredBridgesService = registeredBridgesService,
       super(const BridgeIdentityState.pending()) {
    // Resolve immediately rather than waiting for a connection: the offline
    // surfaces name the machine they are trying to reach, and they are exactly
    // the ones no connect event ever arrives for.
    _scheduleResolve();
    // Then again whenever the relay becomes reachable. skip(1) drops the
    // replayed current status, which the resolve above covers.
    _statusSubscription = connectionService.status.skip(1).listen((status) {
      switch (status) {
        // Both of these say the relay can be reached — the bridge is up, or it
        // is off with the relay connection alive — which is the precondition a
        // lookup that answered with nothing (the phone was offline) was
        // missing. Retrying on the park matters most: the bridge-offline
        // recovery view is the surface whose whole job is naming the machine to
        // start, and it is reached without any connect event. Connecting also
        // drops the service's cached bridge list, so that case picks up the
        // fresh record.
        case ConnectionConnected():
        case ConnectionBridgeOffline():
          _scheduleResolve();
        // Nothing to ask over: a lookup would fail from these states anyway, and
        // the resolve above already covers a launch that starts in one.
        case ConnectionDisconnected():
        case ConnectionReconnecting():
        case ConnectionLost():
          break;
      }
    });
  }

  /// Runs a resolve after whichever one is already running, so a retry is a
  /// genuinely fresh look at the bridge list.
  ///
  /// The service coalesces concurrent callers onto one in-flight request, so a
  /// resolve started while an older one is still running would be handed the
  /// older answer — and for a retry that follows a lookup which failed while the
  /// phone was offline, that is precisely the answer it was triggered to
  /// replace. Queuing keeps the identity stuck at [BridgeIdentityUnnamed] only
  /// for as long as it really is unknown.
  void _scheduleResolve() {
    _resolving = _resolving
        // A queue that outlives the surface it feeds has nothing to resolve for.
        .then((_) => isClosed ? null : _resolve())
        .catchError((Object error, StackTrace stackTrace) {
          // A throw must not poison the chain — the next reconnect still needs
          // its retry. The service's own failures are fail-soft, so reaching
          // here is unexpected and worth a record of its own.
          loge("Bridge identity lookup failed", error, stackTrace);
          // The placeholder is still released: a lookup that blew up leaves the
          // machine unknown, not loading. An identity resolved earlier stands.
          if (!isClosed && state is BridgeIdentityPending) emit(const BridgeIdentityState.unnamed());
        });
  }

  /// The resolve currently running, or a completed future when none is.
  Future<void> _resolving = Future<void>.value();

  /// Resolves the machine to name, ending in [BridgeIdentityNamed] or
  /// [BridgeIdentityUnnamed] — never back in [BridgeIdentityPending], so a
  /// consumer's placeholder always gets released.
  Future<void> _resolve() async {
    // An account that has never registered a bridge has no machine to name (its
    // Projects onboarding reports what it is waiting for instead), and the
    // service answers that from a latch — so a bridge-less account never spends
    // a bridge-list fetch here.
    final hasRegisteredBridges = await _registeredBridgesService.hasRegisteredBridges();
    if (isClosed) return;
    if (!hasRegisteredBridges) {
      emit(const BridgeIdentityState.unnamed());
      return;
    }
    // Most recently seen first, and the account runs one bridge at a time, so
    // the head is the machine to name.
    final bridge = (await _registeredBridgesService.getRegisteredBridges()).firstOrNull;
    if (isClosed) return;
    emit(bridge == null ? const BridgeIdentityState.unnamed() : BridgeIdentityState.named(bridge: bridge));
  }

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    await super.close();
  }
}
