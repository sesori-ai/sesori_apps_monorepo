import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "../../services/registered_bridges_service.dart";
import "computers_state.dart";

/// The Computers page's actions on the account's computers.
///
/// Holds only where the last action stands. The rows come from
/// `ComputerSwitcherCubit`, which sees a confirmed change through the list
/// [RegisteredBridgesService] publishes, and switching goes through the
/// shell's switch callback.
class ComputersCubit({required final RegisteredBridgesService _registeredBridgesService})
    extends Cubit<ComputersState> {
  this : super(const ComputersIdle());

  /// Gives [bridgeId] the [nickname], or clears its nickname with `null` so
  /// it is named by its hostname again.
  Future<void> rename({required String bridgeId, required String? nickname}) async {
    emit(ComputersRenaming(bridgeId: bridgeId));
    final response = await _registeredBridgesService.rename(bridgeId: bridgeId, nickname: nickname);
    if (isClosed) return;
    switch (response) {
      case SuccessResponse():
        emit(const ComputersIdle());
      case ErrorResponse(:final error):
        logw("Failed to rename computer $bridgeId", error);
        emit(ComputersRenameFailed(bridgeId: bridgeId));
    }
  }
}
