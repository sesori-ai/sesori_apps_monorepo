import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../services/registered_bridges_service.dart";
import "../../services/selected_computer_service.dart";
import "computer_switcher_state.dart";

/// Feeds a computer switcher: the account's computers and the one the app
/// works on.
///
/// Mirrors the registered list as its owner publishes it; the surface that
/// names the computer (the Projects bar's identity) is what fetches it. A
/// switch itself goes through `ComputerSwitchDispatcher`, which owns the
/// navigation that comes with it.
class ComputerSwitcherCubit({
  required final RegisteredBridgesService _registeredBridgesService,
  required final ConnectionService _connectionService,
  required final SelectedComputerService _selectedComputerService,
}) extends Cubit<ComputerSwitcherState> {
  late final StreamSubscription<List<BridgeSummary>> _bridgesSubscription;
  late final StreamSubscription<ConnectionStatus> _statusSubscription;

  this
    : super(
        ComputerSwitcherState(
          computers: _registeredBridgesService.bridges.value,
          targetId: _connectionService.currentStatus.targetBridgeId,
        ),
      ) {
    // skip(1): the replayed current values are already in the initial state.
    _bridgesSubscription = _registeredBridgesService.bridges.skip(1).listen((computers) {
      emit(ComputerSwitcherState(computers: computers, targetId: state.targetId));
    });
    _statusSubscription = _connectionService.status
        .skip(1)
        .listen((status) => _adoptTarget(targetId: status.targetBridgeId));
    // Before any connection names a target, the stored pick is the target.
    if (state.targetId == null) unawaited(_readStoredTarget());
  }

  Future<void> _readStoredTarget() async {
    final targetId = await _selectedComputerService.targetBridgeId();
    if (isClosed || state.targetId != null) return;
    _adoptTarget(targetId: targetId);
  }

  void _adoptTarget({required String? targetId}) {
    // A status without a target (disconnected) does not unpick the computer.
    if (targetId == null || targetId == state.targetId) return;
    emit(ComputerSwitcherState(computers: state.computers, targetId: targetId));
  }

  @override
  Future<void> close() async {
    await _bridgesSubscription.cancel();
    await _statusSubscription.cancel();
    await super.close();
  }
}
