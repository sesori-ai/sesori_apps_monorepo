import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeKind;

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";

/// How the connected bridge was installed, so the update steps match it: the
/// command-line bridge or the one Sesori Desktop bundles and updates.
///
/// `null` while no bridge is connected — the kind is only known from the health
/// the bridge reports on connect.
class BridgeKindCubit({required ConnectionService connectionService}) extends Cubit<BridgeKind?> {
  late final StreamSubscription<ConnectionStatus> _subscription;

  this : super(_kindOf(status: connectionService.currentStatus)) {
    _subscription = connectionService.status.listen((status) {
      if (!isClosed) emit(_kindOf(status: status));
    });
  }

  static BridgeKind? _kindOf({required ConnectionStatus status}) {
    return switch (status) {
      ConnectionConnected(:final health) => health.bridgeKind,
      // The offline park carries a placeholder health, not one the bridge sent.
      ConnectionBridgeOffline() || ConnectionDisconnected() || ConnectionReconnecting() || ConnectionLost() => null,
    };
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
