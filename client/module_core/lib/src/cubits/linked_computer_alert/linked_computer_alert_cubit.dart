import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/platform/active_bridge_locality.dart";
import "../../services/registered_bridges_service.dart";
import "linked_computer_alert.dart";

/// Announces a computer newly linked to the account while the app is open.
///
/// The state is the latest announcement, `null` before the first. A list that
/// gains a computer announces it only when the previous list was not empty:
/// the first list after launch or sign-in holds nothing new, and the account's
/// first computer arrives through onboarding. This surface's own computer is
/// never announced, since the surface already works on it. When several
/// computers arrive in one list, the most recently seen one is announced. An
/// emptied list (sign-out) withdraws the announcement, back to `null`.
class LinkedComputerAlertCubit({
  required final RegisteredBridgesService _registeredBridgesService,
  required final ActiveBridgeLocality _activeBridgeLocality,
}) extends Cubit<LinkedComputerAlert?> {
  late final StreamSubscription<List<BridgeSummary>> _bridgesSubscription;
  Set<String> _knownIds = const {};

  this : super(null) {
    _knownIds = _idsOf(bridges: _registeredBridgesService.bridges.value);
    // skip(1): the replayed current list is already known.
    _bridgesSubscription = _registeredBridgesService.bridges.skip(1).listen(_onBridges);
  }

  void _onBridges(List<BridgeSummary> bridges) {
    final previousIds = _knownIds;
    _knownIds = _idsOf(bridges: bridges);
    if (bridges.isEmpty) {
      if (state != null) emit(null);
      return;
    }
    if (previousIds.isEmpty) return;
    final localId = _activeBridgeLocality.localBridgeId;
    final linked = bridges.where((bridge) => !previousIds.contains(bridge.id) && bridge.id != localId).firstOrNull;
    if (linked == null) return;
    emit(LinkedComputerAlert(bridgeId: linked.id, name: linked.name));
  }

  static Set<String> _idsOf({required List<BridgeSummary> bridges}) => {for (final bridge in bridges) bridge.id};

  @override
  Future<void> close() async {
    await _bridgesSubscription.cancel();
    await super.close();
  }
}
