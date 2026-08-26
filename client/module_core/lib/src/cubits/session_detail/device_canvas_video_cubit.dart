import "dart:async";
import "dart:convert";
import "dart:math";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../logging/logging.dart";
import "../../platform/device_canvas_video_peer.dart";
import "../../platform/lifecycle_source.dart";
import "../../repositories/models/device_canvas_result.dart";
import "../../services/device_canvas_service.dart";
import "device_canvas_session_state.dart";
import "device_canvas_video_state.dart";

typedef _DeviceCanvasVideoIdentity = ({
  String bridgeId,
  String sessionId,
  String deviceKey,
  int claimRevision,
});

class DeviceCanvasVideoCubit({
  required final DeviceCanvasService _service,
  required final DeviceCanvasVideoPeer _peer,
  required final LifecycleSource _lifecycleSource,
  required final ConnectionService _connectionService,
  required DeviceCanvasSessionState initialAuthorization,
  required final String _deviceKey,
  final Duration _connectionTimeout = const Duration(seconds: 15),
  final ClockProvider _clock = const ClockProvider(),
}) extends Cubit<DeviceCanvasVideoState> {
  final Random _random = Random.secure();
  late final StreamSubscription<DeviceCanvasVideoPeerConnectionState> _peerConnectionSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  late final StreamSubscription<ConnectionStatus> _relayConnectionSubscription;

  DeviceCanvasSessionState _authorizationState = initialAuthorization;
  _DeviceCanvasVideoIdentity? _identity;
  String? _offerFingerprint;
  String? _operationId;
  String? _leaseId;
  int? _expiresAt;
  Timer? _connectionTimer;
  Timer? _expiryTimer;
  Future<void>? _teardown;
  bool _relayConnected = _connectionService.currentStatus is ConnectionConnected;
  bool _started = false;
  bool _peerClosed = false;
  int _generation = 0;

  static const _statusReconciliationAttempts = 3;

  this : super(const DeviceCanvasVideoConnecting()) {
    _peerConnectionSubscription = _peer.connectionStateStream.listen(_onPeerConnectionState);
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen(_onLifecycleState);
    _relayConnectionSubscription = _connectionService.status.listen(_onRelayConnectionState);
  }

  Future<void> start() async {
    if (_started || isClosed || _teardown != null) return;
    _started = true;

    final authorization = _resolveAuthorization(_authorizationState);
    switch (authorization) {
      case _DeviceCanvasVideoAuthorizationPending():
        await _terminate(failure: DeviceCanvasVideoFailureReason.unavailable, notifyBridge: false);
        return;
      case _DeviceCanvasVideoAuthorizationInvalid(:final reason):
        await _terminate(failure: reason, notifyBridge: false);
        return;
      case _DeviceCanvasVideoAuthorizationValid(:final identity):
        _identity = identity;
    }
    if (!_relayConnected) {
      await _terminate(failure: DeviceCanvasVideoFailureReason.unavailable, notifyBridge: false);
      return;
    }

    final generation = ++_generation;
    try {
      final offer = await _peer.createOffer();
      if (!_isCurrent(generation)) return;
      if (offer.description.type != DeviceCanvasRtcDescriptionType.offer ||
          !offer.description.isValid ||
          offer.iceCandidates.length > maxDeviceCanvasIceCandidates ||
          !offer.iceCandidates.every((candidate) => candidate.isValid)) {
        throw const FormatException("invalid Device Canvas WebRTC offer");
      }
      _offerFingerprint = offer.description.fingerprint;
      final operationId = _generateOperationId();
      _operationId = operationId;
      final identity = _identity;
      if (identity == null) throw StateError("Device Canvas video authorization was not established");
      final result = await _service.startStream(
        request: DeviceCanvasStreamStartRequest(
          expectedBridgeId: identity.bridgeId,
          sessionId: identity.sessionId,
          deviceKey: identity.deviceKey,
          expectedClaimRevision: identity.claimRevision,
          operationId: operationId,
          control: false,
          offer: offer.description,
          iceCandidates: offer.iceCandidates,
        ),
      );
      if (!_isCurrent(generation)) {
        await _cleanupAbandonedStart(
          result: result,
          identity: identity,
          operationId: operationId,
          offerFingerprint: offer.description.fingerprint,
        );
        return;
      }
      await _handleStartResult(result: result, generation: generation);
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      final errorType = error.runtimeType.toString();
      loge("Failed to start Device Canvas LAN video ($errorType)");
      await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: _leaseId != null);
    }
  }

  void authorizationChanged(DeviceCanvasSessionState authorization) {
    _authorizationState = authorization;
    final identity = _identity;
    if (!_started || identity == null || _teardown != null || isClosed) return;
    switch (_resolveAuthorization(authorization)) {
      case _DeviceCanvasVideoAuthorizationPending():
        return;
      case _DeviceCanvasVideoAuthorizationValid(identity: final current) when current == identity:
        return;
      case _DeviceCanvasVideoAuthorizationValid():
        unawaited(_terminate(failure: DeviceCanvasVideoFailureReason.unauthorized, notifyBridge: true));
      case _DeviceCanvasVideoAuthorizationInvalid(:final reason):
        unawaited(_terminate(failure: reason, notifyBridge: true));
    }
  }

  Future<void> stop() => _terminate(failure: null, notifyBridge: true);

  Future<void> _handleStartResult({
    required DeviceCanvasStreamStartResult result,
    required int generation,
  }) async {
    switch (result) {
      case DeviceCanvasStreamStartSupported(:final response):
        switch (response.outcome) {
          case DeviceCanvasStreamStartOutcome.started:
            await _activateResponse(
              leaseId: response.leaseId,
              expiresAt: response.expiresAt,
              answer: response.answer,
              iceCandidates: response.iceCandidates,
              turn: response.turn,
              generation: generation,
            );
          case DeviceCanvasStreamStartOutcome.controllerConflict:
            await _terminate(failure: DeviceCanvasVideoFailureReason.controllerConflict, notifyBridge: false);
          case DeviceCanvasStreamStartOutcome.unavailable:
            await _terminate(failure: DeviceCanvasVideoFailureReason.unavailable, notifyBridge: false);
          case DeviceCanvasStreamStartOutcome.unauthorized:
            await _terminate(failure: DeviceCanvasVideoFailureReason.unauthorized, notifyBridge: false);
          case DeviceCanvasStreamStartOutcome.unsupported || DeviceCanvasStreamStartOutcome.unknown:
            await _terminate(failure: DeviceCanvasVideoFailureReason.unsupported, notifyBridge: false);
        }
      case DeviceCanvasStreamStartUncertain():
        await _reconcileUncertainStart(generation: generation);
      case DeviceCanvasStreamStartUnsupported():
        await _terminate(failure: DeviceCanvasVideoFailureReason.unsupported, notifyBridge: false);
      case DeviceCanvasStreamStartFailure():
        await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
    }
  }

  Future<void> _reconcileUncertainStart({required int generation}) async {
    final identity = _identity;
    final offerFingerprint = _offerFingerprint;
    final operationId = _operationId;
    if (identity == null || offerFingerprint == null || operationId == null) {
      await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
      return;
    }
    DeviceCanvasStreamStatusResult? result;
    for (var attempt = 0; attempt < _statusReconciliationAttempts; attempt++) {
      final current = await _service.statusStream(
        request: DeviceCanvasStreamStatusRequest(
          expectedBridgeId: identity.bridgeId,
          sessionId: identity.sessionId,
          deviceKey: identity.deviceKey,
          expectedClaimRevision: identity.claimRevision,
          operationId: operationId,
        ),
      );
      if (!_isCurrent(generation)) {
        await _cleanupAbandonedStatus(
          result: current,
          identity: identity,
          offerFingerprint: offerFingerprint,
        );
        return;
      }
      result = current;
      if (current is! DeviceCanvasStreamStatusFailure) break;
    }
    switch (result) {
      case DeviceCanvasStreamStatusSupported(:final response):
        switch (response.outcome) {
          case DeviceCanvasStreamStatusOutcome.active when response.offerFingerprint == offerFingerprint:
            await _activateResponse(
              leaseId: response.leaseId,
              expiresAt: response.expiresAt,
              answer: response.answer,
              iceCandidates: response.iceCandidates,
              turn: response.turn,
              generation: generation,
            );
          case DeviceCanvasStreamStatusOutcome.active:
            await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
          case DeviceCanvasStreamStatusOutcome.controllerConflict:
            await _terminate(failure: DeviceCanvasVideoFailureReason.controllerConflict, notifyBridge: false);
          case DeviceCanvasStreamStatusOutcome.unavailable || DeviceCanvasStreamStatusOutcome.inactive:
            await _terminate(failure: DeviceCanvasVideoFailureReason.unavailable, notifyBridge: false);
          case DeviceCanvasStreamStatusOutcome.unauthorized:
            await _terminate(failure: DeviceCanvasVideoFailureReason.unauthorized, notifyBridge: false);
          case DeviceCanvasStreamStatusOutcome.unknown:
            await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
        }
      case DeviceCanvasStreamStatusUnsupported():
        await _terminate(failure: DeviceCanvasVideoFailureReason.unsupported, notifyBridge: false);
      case DeviceCanvasStreamStatusFailure():
        await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
      case null:
        await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
    }
  }

  Future<void> _activateResponse({
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasRtcDescription? answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
    required int generation,
  }) async {
    if (leaseId == null || expiresAt == null || answer == null) {
      await _terminate(failure: DeviceCanvasVideoFailureReason.signalingFailed, notifyBridge: false);
      return;
    }
    await _activate(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
      generation: generation,
    );
  }

  Future<void> _activate({
    required String leaseId,
    required int expiresAt,
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
    required int generation,
  }) async {
    _leaseId = leaseId;
    _expiresAt = expiresAt;
    if (turn != null) {
      await _terminate(failure: DeviceCanvasVideoFailureReason.lanOnly, notifyBridge: true);
      return;
    }
    final remaining = expiresAt - _clock().millisecondsSinceEpoch;
    if (remaining <= 0) {
      await _terminate(failure: DeviceCanvasVideoFailureReason.expired, notifyBridge: true);
      return;
    }

    _connectionTimer = Timer(_connectionTimeout, () {
      unawaited(_terminate(failure: DeviceCanvasVideoFailureReason.connectionFailed, notifyBridge: true));
    });
    _expiryTimer = Timer(Duration(milliseconds: remaining), () {
      unawaited(_terminate(failure: DeviceCanvasVideoFailureReason.expired, notifyBridge: true));
    });
    await _peer.applyAnswer(answer: answer, iceCandidates: iceCandidates);
  }

  void _onPeerConnectionState(DeviceCanvasVideoPeerConnectionState peerState) {
    if (isClosed || _teardown != null) return;
    switch (peerState) {
      case DeviceCanvasVideoPeerConnectionState.connecting:
        return;
      case DeviceCanvasVideoPeerConnectionState.videoReady:
        final expiresAt = _expiresAt;
        if (_leaseId == null || expiresAt == null) return;
        _connectionTimer?.cancel();
        _connectionTimer = null;
        emit(DeviceCanvasVideoLive(expiresAt: expiresAt));
      case DeviceCanvasVideoPeerConnectionState.disconnected ||
          DeviceCanvasVideoPeerConnectionState.failed ||
          DeviceCanvasVideoPeerConnectionState.closed:
        if (_leaseId == null) return;
        unawaited(_terminate(failure: DeviceCanvasVideoFailureReason.connectionFailed, notifyBridge: true));
    }
  }

  void _onLifecycleState(LifecycleState lifecycleState) {
    if (isClosed || _teardown != null) return;
    switch (lifecycleState) {
      case LifecycleState.resumed || LifecycleState.inactive:
        return;
      case LifecycleState.hidden || LifecycleState.paused || LifecycleState.detached:
        unawaited(_terminate(failure: null, notifyBridge: true));
    }
  }

  void _onRelayConnectionState(ConnectionStatus connectionState) {
    _relayConnected = connectionState is ConnectionConnected;
    if (!_relayConnected && _started && !isClosed && _teardown == null) {
      unawaited(_terminate(failure: DeviceCanvasVideoFailureReason.unavailable, notifyBridge: false));
    }
  }

  Future<void> _terminate({
    required DeviceCanvasVideoFailureReason? failure,
    required bool notifyBridge,
  }) {
    final active = _teardown;
    if (active != null) return active;
    final teardown = _runTeardown(failure: failure, notifyBridge: notifyBridge);
    _teardown = teardown;
    return teardown;
  }

  Future<void> _runTeardown({
    required DeviceCanvasVideoFailureReason? failure,
    required bool notifyBridge,
  }) async {
    _generation++;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final identity = _identity;
    final leaseId = _leaseId;
    _leaseId = null;
    _expiresAt = null;
    if (!isClosed) {
      emit(failure == null ? const DeviceCanvasVideoStopped() : DeviceCanvasVideoFailed(reason: failure));
    }
    await _closePeer();
    if (notifyBridge && identity != null && leaseId != null) {
      await _stopLease(identity: identity, leaseId: leaseId);
    }
  }

  Future<void> _closePeer() async {
    if (_peerClosed) return;
    _peerClosed = true;
    try {
      await _peer.close();
    } on Object catch (error, stackTrace) {
      logw("Failed to close Device Canvas video peer", error, stackTrace);
    }
  }

  Future<void> _stopLease({
    required _DeviceCanvasVideoIdentity identity,
    required String leaseId,
  }) async {
    try {
      final result = await _service.stopStream(
        request: DeviceCanvasStreamStopRequest(
          expectedBridgeId: identity.bridgeId,
          sessionId: identity.sessionId,
          deviceKey: identity.deviceKey,
          expectedClaimRevision: identity.claimRevision,
          leaseId: leaseId,
        ),
      );
      switch (result) {
        case DeviceCanvasStreamStopSupported():
          return;
        case DeviceCanvasStreamStopUncertain():
          await _reconcileUncertainStop(identity: identity, leaseId: leaseId);
        case DeviceCanvasStreamStopUnsupported():
          logw("Device Canvas video stop is unsupported by the connected bridge");
        case DeviceCanvasStreamStopFailure(:final error):
          logw("Failed to stop Device Canvas video lease", error);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to stop Device Canvas video lease", error, stackTrace);
    }
  }

  Future<void> _cleanupAbandonedStart({
    required DeviceCanvasStreamStartResult result,
    required _DeviceCanvasVideoIdentity identity,
    required String operationId,
    required String offerFingerprint,
  }) async {
    switch (result) {
      case DeviceCanvasStreamStartSupported(
        response: DeviceCanvasStreamStartResponse(
          outcome: DeviceCanvasStreamStartOutcome.started,
          leaseId: final leaseId?,
        ),
      ):
        await _stopLease(identity: identity, leaseId: leaseId);
      case DeviceCanvasStreamStartUncertain():
        try {
          for (var attempt = 0; attempt < _statusReconciliationAttempts; attempt++) {
            final status = await _service.statusStream(
              request: DeviceCanvasStreamStatusRequest(
                expectedBridgeId: identity.bridgeId,
                sessionId: identity.sessionId,
                deviceKey: identity.deviceKey,
                expectedClaimRevision: identity.claimRevision,
                operationId: operationId,
              ),
            );
            if (status is DeviceCanvasStreamStatusFailure && attempt + 1 < _statusReconciliationAttempts) {
              continue;
            }
            await _cleanupAbandonedStatus(
              result: status,
              identity: identity,
              offerFingerprint: offerFingerprint,
            );
            return;
          }
        } on Object catch (error, stackTrace) {
          logw("Failed to reconcile an abandoned Device Canvas video start", error, stackTrace);
        }
      case DeviceCanvasStreamStartSupported() ||
          DeviceCanvasStreamStartUnsupported() ||
          DeviceCanvasStreamStartFailure():
        return;
    }
  }

  Future<void> _cleanupAbandonedStatus({
    required DeviceCanvasStreamStatusResult result,
    required _DeviceCanvasVideoIdentity identity,
    required String offerFingerprint,
  }) async {
    switch (result) {
      case DeviceCanvasStreamStatusSupported(
            response: DeviceCanvasStreamStatusResponse(
              outcome: DeviceCanvasStreamStatusOutcome.active,
              leaseId: final leaseId?,
              offerFingerprint: final activeOfferFingerprint,
            ),
          )
          when activeOfferFingerprint == offerFingerprint:
        await _stopLease(identity: identity, leaseId: leaseId);
      case DeviceCanvasStreamStatusFailure(:final error):
        logw("Failed to reconcile an abandoned Device Canvas video lease", error);
      case DeviceCanvasStreamStatusSupported() || DeviceCanvasStreamStatusUnsupported():
        return;
    }
  }

  Future<void> _reconcileUncertainStop({
    required _DeviceCanvasVideoIdentity identity,
    required String leaseId,
  }) async {
    final operationId = _operationId;
    if (operationId == null) {
      logw("Cannot reconcile Device Canvas video stop without an operation identifier");
      return;
    }
    final status = await _service.statusStream(
      request: DeviceCanvasStreamStatusRequest(
        expectedBridgeId: identity.bridgeId,
        sessionId: identity.sessionId,
        deviceKey: identity.deviceKey,
        expectedClaimRevision: identity.claimRevision,
        operationId: operationId,
      ),
    );
    switch (status) {
      case DeviceCanvasStreamStatusSupported(
            response: DeviceCanvasStreamStatusResponse(
              outcome: DeviceCanvasStreamStatusOutcome.active,
              leaseId: final activeLeaseId,
            ),
          )
          when activeLeaseId == leaseId:
        final retry = await _service.stopStream(
          request: DeviceCanvasStreamStopRequest(
            expectedBridgeId: identity.bridgeId,
            sessionId: identity.sessionId,
            deviceKey: identity.deviceKey,
            expectedClaimRevision: identity.claimRevision,
            leaseId: leaseId,
          ),
        );
        if (retry is DeviceCanvasStreamStopFailure) {
          logw("Failed to stop reconciled Device Canvas video lease", retry.error);
        }
      case DeviceCanvasStreamStatusFailure(:final error):
        logw("Failed to reconcile Device Canvas video stop", error);
      case DeviceCanvasStreamStatusSupported() || DeviceCanvasStreamStatusUnsupported():
        return;
    }
  }

  bool _isCurrent(int generation) => !isClosed && _teardown == null && generation == _generation;

  String _generateOperationId() =>
      base64Url.encode(List<int>.generate(24, (_) => _random.nextInt(256))).replaceAll("=", "");

  _DeviceCanvasVideoAuthorization _resolveAuthorization(DeviceCanvasSessionState state) {
    switch (state) {
      case DeviceCanvasSessionLoading():
        return const _DeviceCanvasVideoAuthorizationPending();
      case DeviceCanvasSessionHidden():
        return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unsupported);
      case DeviceCanvasSessionDisconnected() || DeviceCanvasSessionFailure():
        return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unavailable);
      case DeviceCanvasSessionReady(:final status):
        if (status.connection != DeviceCanvasClientConnectionStatus.connected || !status.sessionAvailable) {
          return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unavailable);
        }
        DeviceCanvasDeviceStatus? selected;
        for (final device in status.devices) {
          if (device.deviceKey == _deviceKey) {
            selected = device;
            break;
          }
        }
        final descriptor = selected?.descriptor;
        if (descriptor == null) {
          return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unavailable);
        }
        if (descriptor.platform != DeviceCanvasClientPlatform.android || !descriptor.capabilities.remoteVideo) {
          return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unsupported);
        }
        final claim = selected?.claim;
        if (claim == null ||
            claim.sessionId != status.sessionId ||
            claim.revision <= 0 ||
            status.bridgeId.isEmpty ||
            status.sessionId.isEmpty) {
          return const _DeviceCanvasVideoAuthorizationInvalid(DeviceCanvasVideoFailureReason.unauthorized);
        }
        return _DeviceCanvasVideoAuthorizationValid((
          bridgeId: status.bridgeId,
          sessionId: status.sessionId,
          deviceKey: _deviceKey,
          claimRevision: claim.revision,
        ));
    }
  }

  @override
  Future<void> close() async {
    await Future.wait([
      _peerConnectionSubscription.cancel(),
      _lifecycleSubscription.cancel(),
      _relayConnectionSubscription.cancel(),
    ]);
    await _terminate(failure: null, notifyBridge: true);
    return await super.close();
  }
}

sealed class const _DeviceCanvasVideoAuthorization();

final class const _DeviceCanvasVideoAuthorizationPending() extends _DeviceCanvasVideoAuthorization;

final class const _DeviceCanvasVideoAuthorizationValid(final _DeviceCanvasVideoIdentity identity)
    extends _DeviceCanvasVideoAuthorization;

final class const _DeviceCanvasVideoAuthorizationInvalid(final DeviceCanvasVideoFailureReason reason)
    extends _DeviceCanvasVideoAuthorization;
