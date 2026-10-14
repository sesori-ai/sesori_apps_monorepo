import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/mcp_service.dart";
import "../../services/models/mcp_action_client_state.dart";

/// Observes the inventory view's action owner without owning its disposal.
class McpActionCubit({required final McpService _service}) extends Cubit<McpActionClientState> {
  this : super(_service.currentAction) {
    _subscription = _service.actions.listen((state) {
      if (!isClosed) emit(state);
    });
  }
  late final StreamSubscription<McpActionClientState> _subscription;
  Future<void> execute({required McpEntryAction action}) => _service.executeAction(action: action);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
