import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";

/// Cubit for [ConnectionOverlay] that bridges [ConnectionService]'s
/// reactive status stream into BLoC state management.
class ConnectionOverlayCubit extends Cubit<ConnectionStatus> {
  final ConnectionService _connectionService;
  final AuthSession _authSession;
  late final StreamSubscription<ConnectionStatus> _subscription;

  ConnectionOverlayCubit(ConnectionService connectionService, AuthSession authSession)
    : _connectionService = connectionService,
      _authSession = authSession,
      super(connectionService.currentStatus) {
    _subscription = _connectionService.status.listen((status) {
      if (!isClosed) emit(status);
    });
  }

  void reconnect() => _connectionService.reconnect();

  Future<void> disconnect() async {
    await _authSession.logoutCurrentDevice();
    _connectionService.disconnect();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
