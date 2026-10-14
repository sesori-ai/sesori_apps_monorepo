import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/mcp_authentication_service.dart";
import "../../services/models/mcp_authentication_client_state.dart";

/// Closing a surface stops observing; only an explicit cancel intent stops native work.
class McpAuthenticationCubit({required final McpAuthenticationService _service})
    extends Cubit<McpAuthenticationClientState> {
  this : super(_service.currentState) {
    _subscription = _service.states.listen((state) {
      if (!isClosed) emit(state);
    });
  }
  late final StreamSubscription<McpAuthenticationClientState> _subscription;

  Future<void> start({required McpAuthenticationStartRequest request}) => _service.start(request: request);
  Future<void> refresh() => _service.refresh();
  Future<void> openBrowser() => _service.openBrowser();
  Future<void> cancel() => _service.cancel();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
