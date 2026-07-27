import "dart:async";
import "dart:math";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../repositories/models/plugin_management_result.dart";
import "../repositories/plugin_repository.dart";

typedef _ManagementRequestFence = ({
  int connectionEpoch,
  int publicationGeneration,
  int staleGeneration,
  String? bridgeId,
});

typedef _CapturedManagementRequest = ({
  _ManagementRequestFence fence,
  bool hasBridgeIdentity,
});

@lazySingleton
class PluginManagementService with Disposable {
  PluginManagementService({
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
  }) : _pluginRepository = pluginRepository,
       _connectionService = connectionService,
       _connected = connectionService.currentStatus is ConnectionConnected,
       _connectionEpoch = connectionService.currentStatus is ConnectionConnected ? 1 : 0 {
    _subscriptions
      ..add(_connectionService.status.listen(_onConnectionStatus))
      ..add(_connectionService.events.listen(_onSseEvent))
      ..add(_connectionService.dataMayBeStale.listen((_) => _markStale()));
  }

  final PluginRepository _pluginRepository;
  final ConnectionService _connectionService;
  final BehaviorSubject<PluginManagementLoadResult> _snapshots = BehaviorSubject();
  final CompositeSubscription _subscriptions = CompositeSubscription();

  bool _connected;
  int _connectionEpoch;
  bool _receivedInitialStatus = false;
  bool _disposed = false;

  int _publicationGeneration = 0;
  int _staleGeneration = 0;
  int _consumedStaleGeneration = 0;
  int _lastAttemptedStaleGeneration = 0;
  Future<void>? _refreshTail;

  bool _activeBridgeIdentityKnown = false;
  String? _activeBridgeId;

  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  Future<void> refresh() {
    _markStale();
    return _refreshTail ?? Future<void>.value();
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    return _runMutation(
      request: () => _pluginRepository.command(pluginId: pluginId, request: request),
    );
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) {
    return _runMutation(
      request: () => _pluginRepository.updateIdleTimeout(request: request),
    );
  }

  PluginManagementCommandPlan planApplyAllIdleTimeout({required String input}) {
    final idleTimeoutMins = int.tryParse(input.trim());
    if (idleTimeoutMins == null) return const PluginManagementCommandPlan.invalidInput();
    return PluginManagementCommandPlan.request(
      request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: idleTimeoutMins),
    );
  }

  PluginManagementCommandPlan planSetIdleTimeoutOverride({
    required String pluginId,
    required String input,
  }) {
    final idleTimeoutMins = int.tryParse(input.trim());
    if (idleTimeoutMins == null) return const PluginManagementCommandPlan.invalidInput();
    return PluginManagementCommandPlan.request(
      request: PluginIdleTimeoutUpdateRequest.setOverride(
        pluginId: pluginId,
        idleTimeoutMins: idleTimeoutMins,
      ),
    );
  }

  PluginManagementCommandPlan planClearIdleTimeoutOverride({required String pluginId}) {
    return PluginManagementCommandPlan.request(
      request: PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: pluginId),
    );
  }

  PluginManagementForceAssessment assessForce({
    required PluginLifecycleConflict conflict,
    required PluginManagementForceAction action,
  }) {
    final reasons = conflict.reasons;
    if (reasons.isEmpty || reasons.any((reason) => !_forceableConflictReasons.contains(reason))) {
      return const PluginManagementForceAssessment.notForceable();
    }
    final request = switch (action) {
      PluginManagementForceAction.disable => const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force),
      PluginManagementForceAction.restart => const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.force),
    };
    return PluginManagementForceAssessment.requiresConfirmation(request: request);
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (_disposed) return;
    final nextConnected = status is ConnectionConnected;
    if (!_receivedInitialStatus) {
      _receivedInitialStatus = true;
      if (nextConnected != _connected) {
        _connectionEpoch++;
        _connected = nextConnected;
        _forgetActiveBridgeIdentity();
      }
      if (nextConnected) _markStale();
      return;
    }

    if (nextConnected != _connected) {
      _connectionEpoch++;
      _connected = nextConnected;
      _forgetActiveBridgeIdentity();
    }
    if (nextConnected) _markStale();
  }

  void _onSseEvent(SseEvent event) {
    if (event.data case SesoriPluginManagementChanged(:final snapshotToken)) {
      final currentToken = switch (_currentSnapshot) {
        PluginManagementLoadResultSupported(:final response) => response.snapshotToken,
        PluginManagementLoadResultUnsupported() || PluginManagementLoadResultFailure() || null => null,
      };
      if (snapshotToken == currentToken) return;
      _markStale();
    }
  }

  void _markStale() {
    if (_disposed) return;
    _staleGeneration++;
    _ensureRefreshTail();
  }

  void _rearmStale() {
    if (_disposed) return;
    _staleGeneration++;
  }

  void _ensureRefreshTail() {
    if (_disposed || !_connected || _refreshTail != null) return;
    if (_consumedStaleGeneration >= _staleGeneration || _lastAttemptedStaleGeneration >= _staleGeneration) return;

    final tail = _drainRefreshes();
    _refreshTail = tail;
    unawaited(
      tail.whenComplete(() {
        if (!identical(_refreshTail, tail)) return;
        _refreshTail = null;
        _ensureRefreshTail();
      }),
    );
  }

  Future<void> _drainRefreshes() async {
    while (!_disposed && _connected && _consumedStaleGeneration < _staleGeneration) {
      final targetGeneration = _staleGeneration;
      if (_lastAttemptedStaleGeneration >= targetGeneration) return;
      _lastAttemptedStaleGeneration = targetGeneration;

      final outcome = await _loadAndPublish(targetGeneration: targetGeneration);
      if (outcome == _RefreshOutcome.fenced) return;
      if (outcome == _RefreshOutcome.failed && _staleGeneration <= targetGeneration) return;
    }
  }

  Future<_RefreshOutcome> _loadAndPublish({required int targetGeneration}) async {
    final captured = _captureRequest(staleGeneration: targetGeneration);
    final result = await _pluginRepository.getManagement();
    final publication = _coordinatePublication(
      captured: captured,
      candidate: result,
      consumeStalenessThrough: switch (result) {
        PluginManagementLoadResultSupported() || PluginManagementLoadResultUnsupported() => targetGeneration,
        PluginManagementLoadResultFailure() => null,
      },
      retainSupportedOnFailure: true,
    );
    switch (publication) {
      case _PublicationOutcome.applied:
        return result is PluginManagementLoadResultFailure ? _RefreshOutcome.failed : _RefreshOutcome.applied;
      case _PublicationOutcome.fenced:
        return _RefreshOutcome.fenced;
      case _PublicationOutcome.superseded || _PublicationOutcome.identitySuperseded:
        return _RefreshOutcome.superseded;
    }
  }

  Future<PluginManagementMutationResult> _runMutation({
    required Future<PluginManagementMutationResult> Function() request,
  }) async {
    if (_disposed || !_connected) {
      return PluginManagementMutationResult.failure(error: ApiError.generic());
    }

    final captured = _captureRequest(staleGeneration: _staleGeneration);
    final result = await request();
    switch (result) {
      case PluginManagementMutationResultSuccess(:final response):
        final publication = _coordinatePublication(
          captured: captured,
          candidate: PluginManagementLoadResult.supported(response: response, refreshError: null),
          consumeStalenessThrough: captured.fence.staleGeneration,
          retainSupportedOnFailure: false,
        );
        if (publication != _PublicationOutcome.applied) {
          await _refreshAfterUncertainMutation();
          return const PluginManagementMutationResult.uncertain();
        }
        return result;
      case PluginManagementMutationResultUncertain():
        await _refreshAfterUncertainMutation();
        return result;
      case PluginManagementMutationResultNotFound() ||
          PluginManagementMutationResultConflict() ||
          PluginManagementMutationResultFailure():
        return result;
    }
  }

  Future<void> _refreshAfterUncertainMutation() async {
    _markStale();
    await (_refreshTail ?? Future<void>.value());
  }

  _CapturedManagementRequest _captureRequest({required int staleGeneration}) {
    return (
      fence: (
        connectionEpoch: _connectionEpoch,
        publicationGeneration: _publicationGeneration,
        staleGeneration: staleGeneration,
        bridgeId: _activeBridgeIdentityKnown ? _activeBridgeId : null,
      ),
      hasBridgeIdentity: _activeBridgeIdentityKnown,
    );
  }

  bool _isConnectionFenceCurrent(_ManagementRequestFence fence) {
    return !_disposed && _connected && _connectionEpoch == fence.connectionEpoch;
  }

  bool _responseIdentitySupersedesRequest({
    required PluginManagementResponse response,
    required _CapturedManagementRequest captured,
  }) {
    return captured.hasBridgeIdentity && response.bridgeId != captured.fence.bridgeId;
  }

  _PublicationOutcome _coordinatePublication({
    required _CapturedManagementRequest captured,
    required PluginManagementLoadResult candidate,
    required int? consumeStalenessThrough,
    required bool retainSupportedOnFailure,
  }) {
    if (!_isConnectionFenceCurrent(captured.fence)) return _PublicationOutcome.fenced;
    if (_publicationGeneration != captured.fence.publicationGeneration) {
      _rearmStale();
      return _PublicationOutcome.superseded;
    }

    var publication = candidate;
    switch (candidate) {
      case PluginManagementLoadResultSupported(:final response):
        if (_responseIdentitySupersedesRequest(response: response, captured: captured)) {
          _invalidateBridgeIdentityFence();
          _rearmStale();
          return _PublicationOutcome.identitySuperseded;
        }
        _activeBridgeIdentityKnown = true;
        _activeBridgeId = response.bridgeId;
      case PluginManagementLoadResultUnsupported():
        _forgetActiveBridgeIdentity();
      case PluginManagementLoadResultFailure(:final error):
        if (retainSupportedOnFailure) {
          final retained = _retainedSnapshotForActiveBridge;
          if (retained != null) {
            publication = PluginManagementLoadResult.supported(response: retained, refreshError: error);
          }
        }
    }

    _publicationGeneration++;
    _snapshots.add(publication);
    if (consumeStalenessThrough != null) _consumeStalenessThrough(consumeStalenessThrough);
    return _PublicationOutcome.applied;
  }

  void _consumeStalenessThrough(int generation) {
    _consumedStaleGeneration = max(_consumedStaleGeneration, generation);
  }

  PluginManagementLoadResult? get _currentSnapshot => _snapshots.hasValue ? _snapshots.value : null;

  PluginManagementResponse? get _retainedSnapshotForActiveBridge {
    if (!_activeBridgeIdentityKnown) return null;
    return switch (_currentSnapshot) {
      PluginManagementLoadResultSupported(:final response) when response.bridgeId == _activeBridgeId => response,
      PluginManagementLoadResultSupported() ||
      PluginManagementLoadResultUnsupported() ||
      PluginManagementLoadResultFailure() ||
      null => null,
    };
  }

  void _forgetActiveBridgeIdentity() {
    _activeBridgeIdentityKnown = false;
    _activeBridgeId = null;
  }

  void _invalidateBridgeIdentityFence() {
    _connectionEpoch++;
    _forgetActiveBridgeIdentity();
  }

  @override
  Future<void> onDispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscriptions.dispose();
    await _refreshTail;
    await _snapshots.close();
  }
}

enum _RefreshOutcome { applied, failed, superseded, fenced }

enum _PublicationOutcome { applied, fenced, superseded, identitySuperseded }

sealed class PluginManagementCommandPlan {
  const PluginManagementCommandPlan();

  const factory PluginManagementCommandPlan.request({
    required PluginIdleTimeoutUpdateRequest request,
  }) = PluginManagementCommandPlanRequest;

  const factory PluginManagementCommandPlan.invalidInput() = PluginManagementCommandPlanInvalidInput;
}

final class PluginManagementCommandPlanRequest extends PluginManagementCommandPlan {
  const PluginManagementCommandPlanRequest({required this.request});

  final PluginIdleTimeoutUpdateRequest request;
}

final class PluginManagementCommandPlanInvalidInput extends PluginManagementCommandPlan {
  const PluginManagementCommandPlanInvalidInput();
}

enum PluginManagementForceAction { disable, restart }

sealed class PluginManagementForceAssessment {
  const PluginManagementForceAssessment();

  const factory PluginManagementForceAssessment.requiresConfirmation({
    required PluginLifecycleCommandRequest request,
  }) = PluginManagementForceAssessmentRequiresConfirmation;

  const factory PluginManagementForceAssessment.notForceable() = PluginManagementForceAssessmentNotForceable;
}

final class PluginManagementForceAssessmentRequiresConfirmation extends PluginManagementForceAssessment {
  const PluginManagementForceAssessmentRequiresConfirmation({required this.request});

  final PluginLifecycleCommandRequest request;
}

final class PluginManagementForceAssessmentNotForceable extends PluginManagementForceAssessment {
  const PluginManagementForceAssessmentNotForceable();
}

const _forceableConflictReasons = {
  PluginLifecycleConflictReason.inFlight,
  PluginLifecycleConflictReason.busy,
  PluginLifecycleConflictReason.workStateUnknown,
};
