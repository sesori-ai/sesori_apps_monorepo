import 'dart:async';

import 'package:sesori_shared/sesori_shared.dart' show ServerStateKind;

import 'server_health_event.dart';

class ServerHealthTracker {
  final StreamController<ServerStateKind> _stateChangesController = StreamController<ServerStateKind>.broadcast();
  ServerStateKind _currentState = ServerStateKind.running;
  StreamSubscription<ServerHealthEvent>? _subscription;

  ServerHealthTracker({required Stream<ServerHealthEvent> events}) {
    _subscription = events.listen((event) {
      final newState = switch (event) {
        ServerHealthEventRunning() => ServerStateKind.running,
        ServerHealthEventUnreachable() => ServerStateKind.unreachable,
        ServerHealthEventRestarting() => ServerStateKind.restarting,
        ServerHealthEventFailed() => ServerStateKind.failed,
      };
      if (newState != _currentState) {
        _currentState = newState;
        _stateChangesController.add(newState);
      }
    });
  }

  ServerStateKind get currentState => _currentState;
  Stream<ServerStateKind> get stateChanges => _stateChangesController.stream;

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _stateChangesController.close();
  }
}
