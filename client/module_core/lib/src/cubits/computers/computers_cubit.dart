import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

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
}
