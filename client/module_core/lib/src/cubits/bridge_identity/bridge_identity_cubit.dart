import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
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
    unawaited(_resolve());
    // Then again on every reconnect. The service drops its cached bridge list
    // when a bridge connects, so this picks the fresh record up — and retries a
    // lookup that answered with nothing because the phone itself was offline.
    // skip(1) drops the replayed current status, which the resolve above covers.
    _statusSubscription = connectionService.status.skip(1).listen((status) {
      if (status is! ConnectionConnected) return;
      unawaited(_resolve());
    });
  }

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
