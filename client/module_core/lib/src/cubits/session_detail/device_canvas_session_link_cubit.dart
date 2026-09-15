import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../logging/logging.dart";
import "../../repositories/models/device_canvas_result.dart";
import "../../services/device_canvas_service.dart";
import "../../services/registered_bridges_service.dart";
import "device_canvas_session_link_state.dart";

class DeviceCanvasSessionLinkCubit({
  required final DeviceCanvasService _service,
  required final RegisteredBridgesService _registeredBridgesService,
  required ConnectionService connectionService,
  required final String _bridgeId,
  required final String? _projectId,
  required final String _sessionId,
}) extends Cubit<DeviceCanvasSessionLinkState> {
  late final StreamSubscription<ConnectionStatus> _connectionSubscription;
  late final StreamSubscription<SseEvent> _eventSubscription;
  int _verificationGeneration = 0;
  Future<void>? _activeVerification;
  bool _verificationPending = false;
  bool _isConnected = false;

  this : super(const DeviceCanvasSessionLinkWaiting()) {
    _connectionSubscription = connectionService.status.listen(_onConnectionStatus);
    _eventSubscription = connectionService.events
        .where((event) => event.data is SesoriDeviceCanvasChanged)
        .listen((_) => unawaited(verify()));
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (isClosed) return;
    _isConnected = status is ConnectionConnected;
    if (!_isConnected) {
      _verificationGeneration++;
      _activeVerification = null;
      _verificationPending = false;
      if (state is! DeviceCanvasSessionLinkWaiting) emit(const DeviceCanvasSessionLinkWaiting());
      return;
    }
    unawaited(verify());
  }

  Future<void> verify() {
    if (!_isConnected || isClosed) return Future<void>.value();
    final active = _activeVerification;
    if (active != null) {
      _verificationPending = true;
      return active;
    }
    final generation = ++_verificationGeneration;
    late final Future<void> verification;
    verification = _verify(generation: generation).whenComplete(() {
      if (!identical(_activeVerification, verification)) return;
      _activeVerification = null;
      if (_verificationPending && !isClosed) {
        _verificationPending = false;
        unawaited(verify());
      }
    });
    _activeVerification = verification;
    return verification;
  }

  Future<void> _verify({required int generation}) async {
    try {
      final result = await _service.getSessionStatus(sessionId: _sessionId);
      if (isClosed || generation != _verificationGeneration) return;
      switch (result) {
        case DeviceCanvasStatusSupported(:final status)
            when status.bridgeId == _bridgeId &&
                status.sessionId == _sessionId &&
                status.sessionAvailable &&
                (status.projectId?.isNotEmpty ?? false) &&
                (_projectId == null || status.projectId == _projectId):
          emit(DeviceCanvasSessionLinkVerified(status: status));
        case DeviceCanvasStatusSupported(:final status) when status.bridgeId != _bridgeId:
          final bridges = await _registeredBridgesService.getRegisteredBridges();
          if (isClosed || generation != _verificationGeneration) return;
          emit(
            bridges.any((bridge) => bridge.id == _bridgeId)
                ? const DeviceCanvasSessionLinkWaiting()
                : const DeviceCanvasSessionLinkUnavailable(),
          );
        case DeviceCanvasStatusSupported() || DeviceCanvasStatusUnsupported() || DeviceCanvasStatusFailure():
          emit(const DeviceCanvasSessionLinkUnavailable());
      }
    } on Object catch (error, stackTrace) {
      if (isClosed || generation != _verificationGeneration) return;
      loge("Failed to verify Device Canvas session link", error, stackTrace);
      emit(const DeviceCanvasSessionLinkUnavailable());
    }
  }

  @override
  Future<void> close() async {
    _verificationGeneration++;
    _activeVerification = null;
    _verificationPending = false;
    await Future.wait([
      _connectionSubscription.cancel(),
      _eventSubscription.cancel(),
    ]);
    return await super.close();
  }
}
