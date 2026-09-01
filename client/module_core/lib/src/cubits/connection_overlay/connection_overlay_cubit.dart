import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
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
class ConnectionOverlayCubit(
  final ConnectionService _connectionService,
  RegisteredBridgesService registeredBridgesService, {
  @visibleForTesting final Duration _reconnectingGrace = defaultReconnectingGrace,
}) extends Cubit<ConnectionOverlayState> {
  late final StreamSubscription<ConnectionOverlayState> _subscription;
  Timer? _reconnectingGraceTimer;

  /// How long a reconnect must persist before [ConnectionOverlayState.reconnecting]
  /// is surfaced. Routine fast reconnects (foreground resume, a bridge handover)
  /// complete within this window, so the banner appears only when the relay link
  /// is genuinely interrupted; the previous state is retained meanwhile.
  static const Duration defaultReconnectingGrace = Duration(seconds: 3);

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  this : super(_derive(_connectionService.currentStatus, registeredBridgesService.isRegistered.value)) {
    _subscription =
        Rx.combineLatest2(
          _connectionService.status,
          registeredBridgesService.isRegistered,
          _derive,
        ).listen(_onDerived);
  }

  void _onDerived(ConnectionOverlayState derived) {
    if (isClosed) return;
    if (derived is ConnectionOverlayReconnecting) {
      if (state is ConnectionOverlayReconnecting) return;
      _reconnectingGraceTimer ??= Timer(_reconnectingGrace, () {
        _reconnectingGraceTimer = null;
        if (!isClosed) emit(const ConnectionOverlayState.reconnecting());
      });
      return;
    }
    _reconnectingGraceTimer?.cancel();
    _reconnectingGraceTimer = null;
    // Guard equality ourselves: the first combineLatest2 emission replays
    // the same inputs the seeded state was derived from, and bloc does not
    // dedupe a cubit's very first emit — so without this it would surface
    // as a redundant (hidden -> hidden) rebuild on startup.
    if (derived != state) emit(derived);
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, combineLatest2 combiner requires positional parameters
  static ConnectionOverlayState _derive(ConnectionStatus status, bool isRegistered) {
    return switch (status) {
      ConnectionLost() => const ConnectionOverlayState.connectionLost(),
      ConnectionReconnecting() => const ConnectionOverlayState.reconnecting(),
      ConnectionBridgeOffline() =>
        isRegistered
            ? const ConnectionOverlayState.bridgeOffline()
            : const ConnectionOverlayState.hidden(connected: false),
      ConnectionConnected() => const ConnectionOverlayState.hidden(connected: true),
      ConnectionDisconnected() => const ConnectionOverlayState.hidden(connected: false),
    };
  }

  void reconnect() => _connectionService.reconnect();

  @override
  Future<void> close() async {
    _reconnectingGraceTimer?.cancel();
    _reconnectingGraceTimer = null;
    await _subscription.cancel();
    await super.close();
  }
}
