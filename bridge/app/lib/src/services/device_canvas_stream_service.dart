import "dart:async";
import "dart:convert";
import "dart:math";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ServerClock;
import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../bridge/device_canvas/integration_state.dart";
import "../bridge/device_canvas/protocol.dart";
import "../bridge/device_canvas/stream_gateway.dart";
import "../repositories/device_canvas_claim_repository.dart";
import "device_canvas_claim_service.dart";

class const DeviceCanvasStreamClient({
  required final int connectionId,
  required final Object connectionIncarnation,
});

class const DeviceCanvasStreamChange();

class DeviceCanvasStreamService({
  required final BridgeIdProvider _bridgeIdProvider,
  required final DeviceCanvasClaimService _claimService,
  required final DeviceCanvasIntegrationState _integrationState,
  required final DeviceCanvasStreamGateway _gateway,
  required final ServerClock _clock,
  Duration leaseDuration = const Duration(minutes: 10),
  Duration startOperationTimeout = const Duration(seconds: 15),
}) {
  final Duration _leaseDuration = leaseDuration;
  final Duration _startOperationTimeout = startOperationTimeout;
  final Random _random = Random.secure();
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final StreamController<DeviceCanvasStreamChange> _changes = StreamController<DeviceCanvasStreamChange>.broadcast(
    sync: true,
  );
  final Map<int, Object> _connectionIncarnations = <int, Object>{};
  final Map<String, _DeviceCanvasStreamLease> _leasesByDeviceKey = <String, _DeviceCanvasStreamLease>{};
  final Map<String, _DeviceCanvasStreamLease> _leasesById = <String, _DeviceCanvasStreamLease>{};
  final Set<_DeviceCanvasStreamStartOperation> _startOperations = <_DeviceCanvasStreamStartOperation>{};
  bool _accepting = true;
  bool _disposed = false;

  this {
    _claimService.committedClaims.listen(_handleCommittedClaim).addTo(_subscriptions);
    _claimService.changes.listen(_handleClaimChange).addTo(_subscriptions);
    _integrationState.connectionChanges.listen(_handleConnectionChange).addTo(_subscriptions);
    _integrationState.presenceChanges.listen(_handlePresenceChange).addTo(_subscriptions);
    _gateway.closedEvents.listen(_handleStreamClosed).addTo(_subscriptions);
  }

  Stream<DeviceCanvasStreamChange> get changes => _changes.stream;

  void registerConnection({required int connectionId, required Object connectionIncarnation}) {
    if (!_accepting) return;
    final previous = _connectionIncarnations[connectionId];
    if (previous != null && !identical(previous, connectionIncarnation)) {
      _revokeConnection(
        connectionId: connectionId,
        connectionIncarnation: previous,
        reason: DeviceCanvasStreamRevokeReason.clientDisconnected,
      );
    }
    _connectionIncarnations[connectionId] = connectionIncarnation;
  }

  void releaseConnection({required int connectionId}) {
    final connectionIncarnation = _connectionIncarnations.remove(connectionId);
    if (connectionIncarnation == null) return;
    _revokeConnection(
      connectionId: connectionId,
      connectionIncarnation: connectionIncarnation,
      reason: DeviceCanvasStreamRevokeReason.clientDisconnected,
    );
  }

  void clearConnections() {
    _connectionIncarnations.clear();
    _revokeAll(reason: DeviceCanvasStreamRevokeReason.clientDisconnected);
  }

  Future<DeviceCanvasStreamStartResponse> start({
    required DeviceCanvasStreamClient client,
    required DeviceCanvasStreamStartRequest request,
  }) {
    final operation = _DeviceCanvasStreamStartOperation(
      bridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      claimRevision: request.expectedClaimRevision,
      operationId: request.operationId,
      connectionId: client.connectionId,
      connectionIncarnation: client.connectionIncarnation,
    );
    _startOperations.add(operation);
    return _start(client: client, request: request, operation: operation)
        .timeout(
          _startOperationTimeout,
          onTimeout: () {
            _cancelStartOperation(operation);
            return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unavailable);
          },
        )
        .whenComplete(() {
          final lease = operation.lease;
          if (lease != null && lease.answer == null) _cancelStartOperation(operation);
          _startOperations.remove(operation);
          if (!operation.settled.isCompleted) operation.settled.complete();
        });
  }

  Future<DeviceCanvasStreamStartResponse> _start({
    required DeviceCanvasStreamClient client,
    required DeviceCanvasStreamStartRequest request,
    required _DeviceCanvasStreamStartOperation operation,
  }) async {
    final authorization = await _authorize(
      client: client,
      expectedBridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      expectedClaimRevision: request.expectedClaimRevision,
      control: request.control,
    );
    if (operation.cancelled) return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unavailable);
    switch (authorization) {
      case _DeviceCanvasStreamUnauthorized():
        return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unauthorized);
      case _DeviceCanvasStreamUnavailable():
        return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unavailable);
      case _DeviceCanvasStreamUnsupported():
        return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unsupported);
      case _DeviceCanvasStreamAuthorized(:final bridgeId):
        final existingLease = _leasesByDeviceKey[request.deviceKey];
        if (existingLease != null) {
          if (_matchesLeaseIdentity(
            lease: existingLease,
            bridgeId: bridgeId,
            sessionId: request.sessionId,
            deviceKey: request.deviceKey,
            claimRevision: request.expectedClaimRevision,
          )) {
            return _startWithoutPayload(DeviceCanvasStreamStartOutcome.controllerConflict);
          }
          _removeLease(lease: existingLease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
        }

        final expiresAt = _clock.now().add(_leaseDuration).millisecondsSinceEpoch;
        final lease = _DeviceCanvasStreamLease(
          leaseId: _generateLeaseId(),
          bridgeId: bridgeId,
          sessionId: request.sessionId,
          deviceKey: request.deviceKey,
          claimRevision: request.expectedClaimRevision,
          operationId: request.operationId,
          connectionId: client.connectionId,
          connectionIncarnation: client.connectionIncarnation,
          expiresAt: expiresAt,
          control: request.control,
          offerFingerprint: request.offer.fingerprint,
        );
        operation.lease = lease;
        _leasesByDeviceKey[lease.deviceKey] = lease;
        _leasesById[lease.leaseId] = lease;
        lease.expiryTimer = Timer(_leaseDuration, () {
          _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.expired, notifyCanvas: true);
        });

        final startResult = await _gateway.start(
          leaseId: lease.leaseId,
          bridgeId: lease.bridgeId,
          sessionId: lease.sessionId,
          deviceKey: lease.deviceKey,
          claimRevision: lease.claimRevision,
          expiresAt: lease.expiresAt,
          control: request.control,
          offer: request.offer,
          iceCandidates: request.iceCandidates,
          turn: null,
        );
        if (operation.cancelled) return _startAfterRevocation(lease);
        if (!_isCurrentLease(lease)) return _startAfterRevocation(lease);

        final currentAuthorization = await _authorize(
          client: client,
          expectedBridgeId: request.expectedBridgeId,
          sessionId: request.sessionId,
          deviceKey: request.deviceKey,
          expectedClaimRevision: request.expectedClaimRevision,
          control: request.control,
        );
        if (operation.cancelled) return _startAfterRevocation(lease);
        if (!_isCurrentLease(lease)) return _startAfterRevocation(lease);
        if (currentAuthorization is! _DeviceCanvasStreamAuthorized) {
          _removeLease(
            lease: lease,
            reason: currentAuthorization is _DeviceCanvasStreamUnauthorized
                ? DeviceCanvasStreamRevokeReason.claimChanged
                : DeviceCanvasStreamRevokeReason.deviceUnavailable,
            notifyCanvas: true,
          );
          return switch (currentAuthorization) {
            _DeviceCanvasStreamUnauthorized() => _startWithoutPayload(DeviceCanvasStreamStartOutcome.unauthorized),
            _DeviceCanvasStreamUnsupported() => _startWithoutPayload(DeviceCanvasStreamStartOutcome.unsupported),
            _DeviceCanvasStreamUnavailable() => _startWithoutPayload(DeviceCanvasStreamStartOutcome.unavailable),
            _DeviceCanvasStreamAuthorized() => throw StateError("unreachable authorization state"),
          };
        }

        switch (startResult) {
          case DeviceCanvasStreamStartSucceeded(:final answer, :final iceCandidates):
            lease
              ..answer = answer
              ..iceCandidates = List<DeviceCanvasIceCandidate>.unmodifiable(iceCandidates);
            _emitChange();
            return DeviceCanvasStreamStartResponse(
              outcome: DeviceCanvasStreamStartOutcome.started,
              leaseId: lease.leaseId,
              expiresAt: lease.expiresAt,
              answer: answer,
              iceCandidates: lease.iceCandidates,
              turn: null,
            );
          case DeviceCanvasStreamStartRejected(:final reason):
            _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.startFailed, notifyCanvas: true);
            return _startWithoutPayload(
              reason == DeviceCanvasStreamStartFailureReason.unsupported
                  ? DeviceCanvasStreamStartOutcome.unsupported
                  : DeviceCanvasStreamStartOutcome.unavailable,
            );
          case DeviceCanvasStreamStartUnavailable():
          case DeviceCanvasStreamStartTimedOut():
            _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.startFailed, notifyCanvas: true);
            return _startWithoutPayload(DeviceCanvasStreamStartOutcome.unavailable);
        }
    }
  }

  Future<DeviceCanvasStreamStatusResponse> status({
    required DeviceCanvasStreamClient client,
    required DeviceCanvasStreamStatusRequest request,
  }) async {
    var authorization = await _authorize(
      client: client,
      expectedBridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      expectedClaimRevision: request.expectedClaimRevision,
      control: false,
    );
    var authorizationFailure = _statusAuthorizationFailure(authorization);
    if (authorizationFailure != null) return authorizationFailure;

    var lease = _leasesByDeviceKey[request.deviceKey];
    if (lease == null || lease.answer == null) {
      final operation = _matchingStartOperation(client: client, request: request);
      if (operation != null) {
        await operation.settled.future;
        authorization = await _authorize(
          client: client,
          expectedBridgeId: request.expectedBridgeId,
          sessionId: request.sessionId,
          deviceKey: request.deviceKey,
          expectedClaimRevision: request.expectedClaimRevision,
          control: false,
        );
        authorizationFailure = _statusAuthorizationFailure(authorization);
        if (authorizationFailure != null) return authorizationFailure;
        lease = _leasesByDeviceKey[request.deviceKey];
      }
    }
    if (lease == null) return _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.inactive);
    if (!_matchesLeaseIdentity(
      lease: lease,
      bridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      claimRevision: request.expectedClaimRevision,
    )) {
      _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
      return _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.inactive);
    }
    if (!_isLeaseClient(lease: lease, client: client)) {
      return _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.controllerConflict);
    }
    if (lease.operationId != request.operationId) {
      return _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.controllerConflict);
    }
    if (lease.answer == null) {
      return _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.inactive);
    }
    return DeviceCanvasStreamStatusResponse(
      outcome: DeviceCanvasStreamStatusOutcome.active,
      leaseId: lease.leaseId,
      expiresAt: lease.expiresAt,
      answer: lease.answer,
      iceCandidates: lease.iceCandidates,
      turn: null,
      offerFingerprint: lease.offerFingerprint,
    );
  }

  Future<DeviceCanvasStreamStopResponse> stop({
    required DeviceCanvasStreamClient client,
    required DeviceCanvasStreamStopRequest request,
  }) async {
    final authorization = await _authorize(
      client: client,
      expectedBridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      expectedClaimRevision: request.expectedClaimRevision,
      control: false,
    );
    if (authorization is _DeviceCanvasStreamUnauthorized) {
      return const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.unauthorized);
    }
    final lease = _leasesById[request.leaseId];
    if (lease == null) {
      return const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.alreadyStopped);
    }
    if (!_matchesLeaseIdentity(
      lease: lease,
      bridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      claimRevision: request.expectedClaimRevision,
    )) {
      if (lease.deviceKey == request.deviceKey) {
        _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
      }
      return const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.unauthorized);
    }
    if (!_isLeaseClient(lease: lease, client: client)) {
      return const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.unauthorized);
    }
    _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.stopped, notifyCanvas: true);
    return const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.stopped);
  }

  void beginShutdown() {
    if (!_accepting) return;
    _accepting = false;
    _connectionIncarnations.clear();
    _revokeAll(reason: DeviceCanvasStreamRevokeReason.bridgeShutdown);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    beginShutdown();
    await _subscriptions.cancel();
    await _changes.close();
  }

  Future<_DeviceCanvasStreamAuthorization> _authorize({
    required DeviceCanvasStreamClient client,
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required bool control,
  }) async {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (!_accepting || bridgeId == null || bridgeId != expectedBridgeId || !_isCurrentClient(client)) {
      return const _DeviceCanvasStreamUnauthorized();
    }
    final claim = await _claimService.getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
    if (!_accepting || _bridgeIdProvider.bridgeId != bridgeId || !_isCurrentClient(client)) {
      return const _DeviceCanvasStreamUnauthorized();
    }
    if (!_matchesClaim(
      claim: claim,
      bridgeId: bridgeId,
      sessionId: sessionId,
      deviceKey: deviceKey,
      claimRevision: expectedClaimRevision,
    )) {
      return const _DeviceCanvasStreamUnauthorized();
    }
    if (!_integrationState.isConnected) return const _DeviceCanvasStreamUnavailable();
    final descriptor = _integrationState.presenceSnapshot.devicesByKey[deviceKey];
    if (descriptor == null) return const _DeviceCanvasStreamUnavailable();
    if (!descriptor.capabilities.remoteVideo ||
        (control && (!descriptor.capabilities.remoteControl || !descriptor.capabilities.input))) {
      return const _DeviceCanvasStreamUnsupported();
    }
    return _DeviceCanvasStreamAuthorized(bridgeId: bridgeId);
  }

  bool _matchesClaim({
    required DeviceCanvasClaim? claim,
    required String bridgeId,
    required String sessionId,
    required String deviceKey,
    required int claimRevision,
  }) =>
      claim != null &&
      claim.bridgeId == bridgeId &&
      claim.sessionId == sessionId &&
      claim.deviceKey == deviceKey &&
      claim.claimRevision == claimRevision;

  bool _isCurrentClient(DeviceCanvasStreamClient client) =>
      identical(_connectionIncarnations[client.connectionId], client.connectionIncarnation);

  bool _isLeaseClient({required _DeviceCanvasStreamLease lease, required DeviceCanvasStreamClient client}) =>
      lease.connectionId == client.connectionId &&
      identical(lease.connectionIncarnation, client.connectionIncarnation) &&
      _isCurrentClient(client);

  bool _isCurrentLease(_DeviceCanvasStreamLease lease) =>
      identical(_leasesById[lease.leaseId], lease) && identical(_leasesByDeviceKey[lease.deviceKey], lease);

  bool _matchesLeaseIdentity({
    required _DeviceCanvasStreamLease lease,
    required String bridgeId,
    required String sessionId,
    required String deviceKey,
    required int claimRevision,
  }) =>
      lease.bridgeId == bridgeId &&
      lease.sessionId == sessionId &&
      lease.deviceKey == deviceKey &&
      lease.claimRevision == claimRevision;

  _DeviceCanvasStreamStartOperation? _matchingStartOperation({
    required DeviceCanvasStreamClient client,
    required DeviceCanvasStreamStatusRequest request,
  }) {
    for (final operation in _startOperations) {
      if (!operation.cancelled &&
          operation.bridgeId == request.expectedBridgeId &&
          operation.sessionId == request.sessionId &&
          operation.deviceKey == request.deviceKey &&
          operation.claimRevision == request.expectedClaimRevision &&
          operation.operationId == request.operationId &&
          operation.connectionId == client.connectionId &&
          identical(operation.connectionIncarnation, client.connectionIncarnation)) {
        return operation;
      }
    }
    return null;
  }

  void _cancelStartOperation(_DeviceCanvasStreamStartOperation operation) {
    if (operation.cancelled) return;
    operation.cancelled = true;
    final lease = operation.lease;
    if (lease != null) {
      _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.startFailed, notifyCanvas: true);
    }
  }

  void _handleCommittedClaim(DeviceCanvasClaim claim) {
    final lease = _leasesByDeviceKey[claim.deviceKey];
    if (lease == null ||
        _matchesLeaseIdentity(
          lease: lease,
          bridgeId: claim.bridgeId,
          sessionId: claim.sessionId,
          deviceKey: claim.deviceKey,
          claimRevision: claim.claimRevision,
        )) {
      return;
    }
    _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
  }

  void _handleClaimChange(DeviceCanvasClaimChange change) {
    switch (change) {
      case DeviceCanvasClaimUpdated(:final projection):
        final lease = _leasesByDeviceKey[projection.deviceKey];
        if (lease == null || projection.bridgeId != lease.bridgeId || projection.claimRevision < lease.claimRevision) {
          return;
        }
        if (projection.sessionId != lease.sessionId || projection.claimRevision != lease.claimRevision) {
          _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
        }
      case DeviceCanvasClaimRemoved(:final bridgeId, :final deviceKey, :final claimRevision):
        final lease = _leasesByDeviceKey[deviceKey];
        if (lease != null && lease.bridgeId == bridgeId && claimRevision >= lease.claimRevision) {
          _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.claimChanged, notifyCanvas: true);
        }
    }
  }

  void _handleConnectionChange(DeviceCanvasConnectionSnapshot snapshot) {
    if (!snapshot.isConnected) {
      _revokeAll(reason: DeviceCanvasStreamRevokeReason.canvasDisconnected);
    }
  }

  void _handlePresenceChange(DeviceCanvasPresenceSnapshot snapshot) {
    for (final lease in _leasesById.values.toList(growable: false)) {
      final descriptor = snapshot.devicesByKey[lease.deviceKey];
      if (descriptor == null ||
          !descriptor.capabilities.remoteVideo ||
          (lease.control && (!descriptor.capabilities.remoteControl || !descriptor.capabilities.input))) {
        _removeLease(lease: lease, reason: DeviceCanvasStreamRevokeReason.deviceUnavailable, notifyCanvas: true);
      }
    }
  }

  void _handleStreamClosed(DeviceCanvasStreamClosedEvent event) {
    final lease = _leasesById[event.leaseId];
    if (lease != null) _removeLease(lease: lease, reason: null, notifyCanvas: false);
  }

  void _revokeConnection({
    required int connectionId,
    required Object connectionIncarnation,
    required DeviceCanvasStreamRevokeReason reason,
  }) {
    for (final lease in _leasesById.values.toList(growable: false)) {
      if (lease.connectionId == connectionId && identical(lease.connectionIncarnation, connectionIncarnation)) {
        _removeLease(lease: lease, reason: reason, notifyCanvas: true);
      }
    }
  }

  void _revokeAll({required DeviceCanvasStreamRevokeReason reason}) {
    for (final lease in _leasesById.values.toList(growable: false)) {
      _removeLease(lease: lease, reason: reason, notifyCanvas: true);
    }
  }

  void _removeLease({
    required _DeviceCanvasStreamLease lease,
    required DeviceCanvasStreamRevokeReason? reason,
    required bool notifyCanvas,
  }) {
    if (!_isCurrentLease(lease)) return;
    _leasesById.remove(lease.leaseId);
    _leasesByDeviceKey.remove(lease.deviceKey);
    lease
      ..revocationReason = reason
      ..expiryTimer?.cancel()
      ..expiryTimer = null;
    _gateway.cancelPendingStart(leaseId: lease.leaseId);
    if (notifyCanvas && reason != null) _gateway.revoke(leaseId: lease.leaseId, reason: reason);
    if (lease.answer != null) _emitChange();
  }

  DeviceCanvasStreamStartResponse _startAfterRevocation(_DeviceCanvasStreamLease lease) {
    return _startWithoutPayload(
      lease.revocationReason == DeviceCanvasStreamRevokeReason.claimChanged
          ? DeviceCanvasStreamStartOutcome.unauthorized
          : DeviceCanvasStreamStartOutcome.unavailable,
    );
  }

  void _emitChange() {
    if (!_changes.isClosed) _changes.add(const DeviceCanvasStreamChange());
  }

  String _generateLeaseId() {
    String leaseId;
    do {
      leaseId = base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256))).replaceAll("=", "");
    } while (leaseId.length > maxDeviceCanvasStreamLeaseIdLength || _leasesById.containsKey(leaseId));
    return leaseId;
  }

  static DeviceCanvasStreamStartResponse _startWithoutPayload(DeviceCanvasStreamStartOutcome outcome) =>
      DeviceCanvasStreamStartResponse(
        outcome: outcome,
        leaseId: null,
        expiresAt: null,
        answer: null,
        iceCandidates: const <DeviceCanvasIceCandidate>[],
        turn: null,
      );

  static DeviceCanvasStreamStatusResponse _statusWithoutPayload(DeviceCanvasStreamStatusOutcome outcome) =>
      DeviceCanvasStreamStatusResponse(
        outcome: outcome,
        leaseId: null,
        expiresAt: null,
        answer: null,
        iceCandidates: const <DeviceCanvasIceCandidate>[],
        turn: null,
        offerFingerprint: null,
      );

  static DeviceCanvasStreamStatusResponse? _statusAuthorizationFailure(
    _DeviceCanvasStreamAuthorization authorization,
  ) => switch (authorization) {
    _DeviceCanvasStreamUnauthorized() => _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.unauthorized),
    _DeviceCanvasStreamUnavailable() ||
    _DeviceCanvasStreamUnsupported() => _statusWithoutPayload(DeviceCanvasStreamStatusOutcome.unavailable),
    _DeviceCanvasStreamAuthorized() => null,
  };
}

sealed class const _DeviceCanvasStreamAuthorization();

final class const _DeviceCanvasStreamAuthorized({required final String bridgeId})
    extends _DeviceCanvasStreamAuthorization;

final class const _DeviceCanvasStreamUnauthorized() extends _DeviceCanvasStreamAuthorization;

final class const _DeviceCanvasStreamUnavailable() extends _DeviceCanvasStreamAuthorization;

final class const _DeviceCanvasStreamUnsupported() extends _DeviceCanvasStreamAuthorization;

class _DeviceCanvasStreamLease({
  required final String leaseId,
  required final String bridgeId,
  required final String sessionId,
  required final String deviceKey,
  required final int claimRevision,
  required final String operationId,
  required final int connectionId,
  required final Object connectionIncarnation,
  required final int expiresAt,
  required final bool control,
  required final String offerFingerprint,
}) {
  Timer? expiryTimer;
  DeviceCanvasRtcDescription? answer;
  List<DeviceCanvasIceCandidate> iceCandidates = const <DeviceCanvasIceCandidate>[];
  DeviceCanvasStreamRevokeReason? revocationReason;
}

class _DeviceCanvasStreamStartOperation({
  required final String bridgeId,
  required final String sessionId,
  required final String deviceKey,
  required final int claimRevision,
  required final String operationId,
  required final int connectionId,
  required final Object connectionIncarnation,
}) {
  final Completer<void> settled = Completer<void>();
  _DeviceCanvasStreamLease? lease;
  bool cancelled = false;
}
