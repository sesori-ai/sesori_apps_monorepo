import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;

import "../../server/services/bridge_restart_service.dart";
import "routed_request.dart";

enum BridgeShutdownRequest() { restart }

/// Owns the single restart handoff shared by relay and debug route consumers.
class BridgeRestartDispatcher({required final BridgeRestartService _restartService}) {
  final StreamController<BridgeShutdownRequest> _shutdownRequests = StreamController<BridgeShutdownRequest>.broadcast(
    sync: true,
  );
  Future<void>? _handoff;
  bool _handoffSucceeded = false;
  bool _disposed = false;

  Stream<BridgeShutdownRequest> get shutdownRequests => _shutdownRequests.stream;

  Future<void> dispatch({required RestartAccepted restart}) {
    if (_disposed) {
      return Future<void>.error(StateError("BridgeRestartDispatcher is disposed"), StackTrace.current);
    }
    final activeHandoff = _handoff;
    if (activeHandoff != null) return activeHandoff;

    final handoff = _performHandoff();
    _handoff = handoff;
    handoff.whenComplete(() {
      if (!_handoffSucceeded && identical(_handoff, handoff)) {
        _handoff = null;
      }
    }).ignore();
    return handoff;
  }

  Future<void> _performHandoff() async {
    Log.i("[restart] restart requested");
    final proceed = await _restartService.performRestartHandoff();
    if (!proceed) {
      Console.error(
        "Restart requested but a new bridge could not be started; continuing to run. "
        "Re-run the install script if this persists: https://sesori.com/",
      );
      return;
    }

    _handoffSucceeded = true;
    Log.i("[restart] handing off; requesting shutdown");
    _shutdownRequests.add(BridgeShutdownRequest.restart);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _shutdownRequests.close();
  }
}
