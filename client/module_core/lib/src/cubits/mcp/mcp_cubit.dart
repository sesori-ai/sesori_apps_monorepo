import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/mcp_service.dart";
import "../../services/models/mcp_inventory_state.dart";

class McpCubit({
  required final McpService _service,
  required final McpInventoryRequest request,
  required final bool mutationsAllowed,
}) extends Cubit<McpInventoryState> {
  this : super(_service.currentState) {
    _subscription = _service.states.listen((state) {
      if (!isClosed) emit(state);
    });
    _service.bind(request: request, mutationsAllowed: mutationsAllowed);
  }
  late final StreamSubscription<McpInventoryState> _subscription;

  Future<void> refresh() => _service.refresh();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _service.dispose();
    await super.close();
  }
}
