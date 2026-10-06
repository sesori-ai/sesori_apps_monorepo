import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeKind, HealthResponse;

import "../../capabilities/server_connection/connection_service.dart";

/// How the bridge was installed, so the update steps match it: the
/// command-line bridge or the one Sesori Desktop bundles and updates.
///
/// Follows the health the bridge last reported, so the kind holds through
/// reconnects and offline parks. `null` before any bridge answered or after an
/// explicit disconnect.
class BridgeKindCubit({required ConnectionService connectionService}) extends Cubit<BridgeKind?> {
  late final StreamSubscription<HealthResponse?> _subscription;

  this : super(connectionService.lastHealth.value?.bridgeKind) {
    _subscription = connectionService.lastHealth.listen((health) {
      if (!isClosed) emit(health?.bridgeKind);
    });
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
