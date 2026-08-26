import "dart:async";
import "dart:convert";
import "dart:math";

import "package:sesori_shared/sesori_shared.dart"
    show DeviceCanvasIceCandidate, DeviceCanvasRtcDescription, DeviceCanvasTurnConfiguration;

import "protocol.dart";

sealed class const DeviceCanvasStreamStartResult();

final class const DeviceCanvasStreamStartSucceeded({
  required final DeviceCanvasRtcDescription answer,
  required final List<DeviceCanvasIceCandidate> iceCandidates,
}) extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartRejected({required final DeviceCanvasStreamStartFailureReason reason})
    extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartUnavailable() extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartTimedOut() extends DeviceCanvasStreamStartResult;

class const DeviceCanvasStreamClosedEvent({
  required final String leaseId,
  required final DeviceCanvasStreamCloseReason reason,
});

class DeviceCanvasStreamGateway({
  Duration startTimeout = const Duration(seconds: 12),
}) {
  static const int maxRequestIdLength = 128;
  static const int _maxSettledStarts = 128;

  final Duration _startTimeout = startTimeout;
  final Random _random = Random.secure();
  final StreamController<DeviceCanvasOutboundMessage> _commands =
      StreamController<DeviceCanvasOutboundMessage>.broadcast(sync: true);
  final StreamController<DeviceCanvasStreamClosedEvent> _closedEvents =
      StreamController<DeviceCanvasStreamClosedEvent>.broadcast(sync: true);
  final Map<String, _PendingDeviceCanvasStreamStart> _pending = <String, _PendingDeviceCanvasStreamStart>{};
  final Map<String, String> _settledWithoutResponse = <String, String>{};
  bool _disposed = false;

  Stream<DeviceCanvasOutboundMessage> get commands => _commands.stream;
  Stream<DeviceCanvasStreamClosedEvent> get closedEvents => _closedEvents.stream;

  Future<DeviceCanvasStreamStartResult> start({
    required String leaseId,
    required String bridgeId,
    required String sessionId,
    required String deviceKey,
    required int claimRevision,
    required int expiresAt,
    required bool control,
    required DeviceCanvasRtcDescription offer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
  }) {
    if (_disposed) return Future<DeviceCanvasStreamStartResult>.value(const DeviceCanvasStreamStartUnavailable());

    final requestId = _generateRequestId();
    final completer = Completer<DeviceCanvasStreamStartResult>();
    final timer = Timer(_startTimeout, () {
      final pending = _pending.remove(requestId);
      if (pending != null) {
        _rememberSettled(requestId: requestId, leaseId: pending.leaseId);
        pending.completer.complete(const DeviceCanvasStreamStartTimedOut());
      }
    });
    _pending[requestId] = _PendingDeviceCanvasStreamStart(
      leaseId: leaseId,
      completer: completer,
      timer: timer,
    );
    _commands.add(
      DeviceCanvasOutboundMessage.streamStart(
        requestId: requestId,
        leaseId: leaseId,
        bridgeId: bridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        claimRevision: claimRevision,
        expiresAt: expiresAt,
        control: control,
        offer: offer,
        iceCandidates: iceCandidates,
        turn: turn,
      ),
    );
    return completer.future;
  }

  void revoke({required String leaseId, required DeviceCanvasStreamRevokeReason reason}) {
    if (_disposed) return;
    _commands.add(DeviceCanvasOutboundMessage.streamRevoke(leaseId: leaseId, reason: reason));
  }

  bool cancelPendingStart({required String leaseId}) {
    String? requestId;
    for (final entry in _pending.entries) {
      if (entry.value.leaseId == leaseId) {
        requestId = entry.key;
        break;
      }
    }
    if (requestId == null) return false;
    final pending = _pending.remove(requestId)!;
    pending.timer.cancel();
    _rememberSettled(requestId: requestId, leaseId: leaseId);
    pending.completer.complete(const DeviceCanvasStreamStartUnavailable());
    return true;
  }

  bool resolveStarted({
    required String requestId,
    required String leaseId,
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
  }) {
    final pending = _takeMatching(requestId: requestId, leaseId: leaseId);
    if (pending == null) return _isSettled(requestId: requestId, leaseId: leaseId);
    pending.completer.complete(DeviceCanvasStreamStartSucceeded(answer: answer, iceCandidates: iceCandidates));
    return true;
  }

  bool resolveStartFailed({
    required String requestId,
    required String leaseId,
    required DeviceCanvasStreamStartFailureReason reason,
  }) {
    final pending = _takeMatching(requestId: requestId, leaseId: leaseId);
    if (pending == null) return _isSettled(requestId: requestId, leaseId: leaseId);
    pending.completer.complete(DeviceCanvasStreamStartRejected(reason: reason));
    return true;
  }

  bool failPendingStart({required String requestId, required String leaseId}) {
    final pending = _takeMatching(requestId: requestId, leaseId: leaseId);
    if (pending == null) return false;
    pending.completer.complete(const DeviceCanvasStreamStartUnavailable());
    return true;
  }

  void handleClosed({required String leaseId, required DeviceCanvasStreamCloseReason reason}) {
    if (_disposed) return;
    _closedEvents.add(DeviceCanvasStreamClosedEvent(leaseId: leaseId, reason: reason));
  }

  void disconnect() {
    final pending = _pending.entries.toList(growable: false);
    _pending.clear();
    for (final entry in pending) {
      final start = entry.value;
      _rememberSettled(requestId: entry.key, leaseId: start.leaseId);
      start.timer.cancel();
      start.completer.complete(const DeviceCanvasStreamStartUnavailable());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    await _commands.close();
    await _closedEvents.close();
  }

  _PendingDeviceCanvasStreamStart? _takeMatching({required String requestId, required String leaseId}) {
    final pending = _pending[requestId];
    if (pending == null || pending.leaseId != leaseId) return null;
    _pending.remove(requestId);
    pending.timer.cancel();
    return pending;
  }

  void _rememberSettled({required String requestId, required String leaseId}) {
    _settledWithoutResponse[requestId] = leaseId;
    while (_settledWithoutResponse.length > _maxSettledStarts) {
      _settledWithoutResponse.remove(_settledWithoutResponse.keys.first);
    }
  }

  bool _isSettled({required String requestId, required String leaseId}) =>
      _settledWithoutResponse[requestId] == leaseId;

  String _generateRequestId() {
    String requestId;
    do {
      requestId = "local-${base64Url.encode(List<int>.generate(18, (_) => _random.nextInt(256))).replaceAll("=", "")}";
    } while (
      requestId.length > maxRequestIdLength ||
      _pending.containsKey(requestId) ||
      _settledWithoutResponse.containsKey(requestId)
    );
    return requestId;
  }
}

class _PendingDeviceCanvasStreamStart({
  required final String leaseId,
  required final Completer<DeviceCanvasStreamStartResult> completer,
  required final Timer timer,
});
