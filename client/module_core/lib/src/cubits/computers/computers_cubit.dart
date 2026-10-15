import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../services/registered_bridges_service.dart";
import "../../services/selected_computer_service.dart";
import "computers_state.dart";

/// The Computers page's actions on the account's computers.
///
/// Holds only where the last action stands. The rows come from
/// `ComputerSwitcherCubit`, which sees a confirmed change through the list
/// [RegisteredBridgesService] publishes, and switching goes through the
/// shell's switch callback.
class ComputersCubit({
  required final RegisteredBridgesService _registeredBridgesService,
  required final SelectedComputerService _selectedComputerService,
}) extends Cubit<ComputersState> {
  this : super(const ComputersIdle());

  /// Names [computer] [name]. A blank name, or its hostname, clears its
  /// nickname so the hostname names it again; an unchanged name sends nothing.
  Future<void> rename({required BridgeSummary computer, required String name}) async {
    final trimmed = name.trim();
    final nickname = trimmed.isEmpty || trimmed == computer.hostname ? null : trimmed;
    final currentNickname = computer.name == computer.hostname ? null : computer.name;
    if (nickname == currentNickname) return;
    final bridgeId = computer.id;
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

  /// Removes the computer [bridgeId] from the account. When the app works on
  /// it, returns the computer to switch to instead, or `null` when none
  /// remains; the switch itself is the caller's.
  Future<String?> remove({required String bridgeId}) async {
    emit(ComputersRemoving(bridgeId: bridgeId));
    final response = await _registeredBridgesService.remove(bridgeId: bridgeId);
    if (isClosed) return null;
    switch (response) {
      case SuccessResponse():
        emit(const ComputersIdle());
        if (await _selectedComputerService.targetBridgeId() != bridgeId) return null;
        return _selectedComputerService.replacementAfterRemoving(bridgeId: bridgeId);
      case ErrorResponse(:final error):
        logw("Failed to remove computer $bridgeId", error);
        emit(ComputersRemoveFailed(bridgeId: bridgeId));
        return null;
    }
  }
}
