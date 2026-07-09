import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../services/registered_bridges_service.dart";
import "connection_overlay_state.dart";

/// Drives the app-wide connection banner. Derives what the banner should show
/// from the [ConnectionService] status combined with the
/// [RegisteredBridgesService] latch: a bridge-offline park only warrants the
/// banner when the account actually has a registered bridge — a never-registered
/// account parks offline as a normal part of onboarding and must not be alarmed.
///
/// The combine is reactive on purpose. `ConnectionBridgeOffline` is emitted once
/// per park, so a one-shot registration check at park time could be wrong if the
/// latch resolves (or flips) afterwards; combining the two streams re-derives the
/// banner whenever either input changes.
class ConnectionOverlayCubit extends Cubit<ConnectionOverlayState> {
  final ConnectionService _connectionService;
  late final StreamSubscription<ConnectionOverlayState> _subscription;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  ConnectionOverlayCubit(
    ConnectionService connectionService,
    RegisteredBridgesService registeredBridgesService,
  ) : _connectionService = connectionService,
      super(_derive(connectionService.currentStatus, registeredBridgesService.isRegistered.value)) {
    _subscription =
        Rx.combineLatest2(
          _connectionService.status,
          registeredBridgesService.isRegistered,
          _derive,
        ).listen((derived) {
          // Guard equality ourselves: the first combineLatest2 emission replays
          // the same inputs the seeded state was derived from, and bloc does not
          // dedupe a cubit's very first emit — so without this it would surface
          // as a redundant (hidden -> hidden) rebuild on startup.
          if (!isClosed && derived != state) emit(derived);
        });
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, combineLatest2 combiner requires positional parameters
  static ConnectionOverlayState _derive(ConnectionStatus status, bool isRegistered) {
    return switch (status) {
      ConnectionLost() => const ConnectionOverlayState.connectionLost(),
      ConnectionReconnecting() => const ConnectionOverlayState.reconnecting(),
      ConnectionBridgeOffline() => isRegistered
          ? const ConnectionOverlayState.bridgeOffline()
          : const ConnectionOverlayState.hidden(),
      ConnectionConnected() || ConnectionDisconnected() => const ConnectionOverlayState.hidden(),
    };
  }

  void reconnect() => _connectionService.reconnect();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
