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
    final outcome = await _renameOutcome(bridgeId: bridgeId, nickname: nickname);
    // The page may have closed meanwhile; the failure is logged either way.
    if (isClosed) return;
    emit(outcome);
  }

  Future<ComputersState> _renameOutcome({required String bridgeId, required String? nickname}) async {
    try {
      final response = await _registeredBridgesService.rename(bridgeId: bridgeId, nickname: nickname);
      switch (response) {
        case SuccessResponse():
          return const ComputersIdle();
        case ErrorResponse(:final error):
          logw("Failed to rename computer $bridgeId", error);
          return ComputersRenameFailed(bridgeId: bridgeId);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to rename computer $bridgeId (unexpected error)", error, stackTrace);
      return ComputersRenameFailed(bridgeId: bridgeId);
    }
  }

  /// Removes the computer [bridgeId] from the account. When it [isCurrent],
  /// the one the app works on, and the user has not switched elsewhere
  /// meanwhile, returns the computer to switch to instead, or `null` when
  /// none remains; the switch itself is the caller's.
  Future<String?> remove({required String bridgeId, required bool isCurrent}) async {
    emit(ComputersRemoving(bridgeId: bridgeId));
    final removed = await _removeOnServer(bridgeId: bridgeId);
    // The page may have closed meanwhile; the switch away is still owed.
    if (!isClosed) emit(removed ? const ComputersIdle() : ComputersRemoveFailed(bridgeId: bridgeId));
    if (!removed || !isCurrent) return null;
    // The user may have switched elsewhere while the removal ran.
    final target = await _selectedComputerService.targetBridgeId();
    if (target != null && target != bridgeId) return null;
    return _selectedComputerService.replacementAfterRemoving(bridgeId: bridgeId);
  }

  /// Whether the server removed [bridgeId]; logs why when it did not.
  Future<bool> _removeOnServer({required String bridgeId}) async {
    try {
      final response = await _registeredBridgesService.remove(bridgeId: bridgeId);
      switch (response) {
        case SuccessResponse():
          return true;
        case ErrorResponse(:final error):
          logw("Failed to remove computer $bridgeId", error);
          return false;
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to remove computer $bridgeId (unexpected error)", error, stackTrace);
      return false;
    }
  }
}
