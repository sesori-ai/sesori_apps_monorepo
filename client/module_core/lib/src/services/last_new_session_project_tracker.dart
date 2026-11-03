import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../repositories/last_new_session_project_store.dart";
import "models/last_new_session_project.dart";

/// The project the user was last in on the connected computer: the one last
/// picked in the new-session composer or started a session in. It is stored
/// per computer, so it survives app restarts, and reads again when the
/// connection moves to another computer.
@lazySingleton
class LastNewSessionProjectTracker({
  required ConnectionService connectionService,
  required final LastNewSessionProjectStore _store,
}) {
  final BehaviorSubject<LastNewSessionProject> _project = BehaviorSubject.seeded(
    const LastNewSessionProjectUnknown(),
  );
  late final StreamSubscription<ConnectionStatus> _statusSubscription;

  /// The computer [project] belongs to; a disconnect keeps the last one.
  String? _bridgeId;

  ValueStream<LastNewSessionProject> get project => _project.stream;

  this {
    _onConnectionStatus(connectionService.currentStatus);
    _statusSubscription = connectionService.status.listen(_onConnectionStatus);
  }

  /// Called when the user picks [projectId]: by `NewSessionCubit` for a pick
  /// in the composer or a session started in it, and by `AllSessionsCubit`
  /// for a pick in the no-project prompt, before any composer exists.
  void record({required String projectId}) {
    final bridgeId = _bridgeId;
    if (bridgeId == null) return;
    _project.add(LastNewSessionProjectKnown(projectId: projectId));
    unawaited(_store.write(bridgeId: bridgeId, projectId: projectId));
  }

  void _onConnectionStatus(ConnectionStatus status) {
    final bridgeId = status.targetBridgeId;
    if (bridgeId == null || bridgeId == _bridgeId) return;
    _bridgeId = bridgeId;
    _project.add(const LastNewSessionProjectUnknown());
    unawaited(_load(bridgeId: bridgeId));
  }

  Future<void> _load({required String bridgeId}) async {
    final projectId = await _store.read(bridgeId: bridgeId);
    // Another computer took over, or a pick landed first and is newer.
    if (_project.isClosed || _bridgeId != bridgeId || _project.value is! LastNewSessionProjectUnknown) return;
    _project.add(LastNewSessionProjectKnown(projectId: projectId));
  }

  @disposeMethod
  Future<void> dispose() async {
    await _statusSubscription.cancel();
    await _project.close();
  }
}
