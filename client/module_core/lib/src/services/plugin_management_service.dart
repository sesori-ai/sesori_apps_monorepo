import "dart:async";
import "dart:math";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/models/plugin_management_result.dart";
import "../repositories/plugin_repository.dart";
import "product_analytics_service.dart";

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

sealed class PluginManagementIdleTimeoutInput {
  const PluginManagementIdleTimeoutInput();

  const factory PluginManagementIdleTimeoutInput.noTimeout() = PluginManagementIdleTimeoutInputNoTimeout;

  const factory PluginManagementIdleTimeoutInput.custom({required String input}) =
      PluginManagementIdleTimeoutInputCustom;
}

final class PluginManagementIdleTimeoutInputNoTimeout extends PluginManagementIdleTimeoutInput {
  const PluginManagementIdleTimeoutInputNoTimeout();
}

final class PluginManagementIdleTimeoutInputCustom extends PluginManagementIdleTimeoutInput {
  const PluginManagementIdleTimeoutInputCustom({required this.input});

  final String input;
}

@lazySingleton
class PluginManagementService with Disposable {
  PluginManagementService({
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
    required ProductAnalyticsService productAnalyticsService,
  }) : _pluginRepository = pluginRepository,
       _connectionService = connectionService,
       _productAnalyticsService = productAnalyticsService,
       _connected = connectionService.currentStatus is ConnectionConnected,
       _connectionEpoch = connectionService.currentStatus is ConnectionConnected ? 1 : 0 {
    _subscriptions
      ..add(_connectionService.status.listen(_onConnectionStatus))
      ..add(_connectionService.events.listen(_onSseEvent))
      ..add(_connectionService.dataMayBeStale.listen((_) => _markStale()));
  }

  final PluginRepository _pluginRepository;
  final ConnectionService _connectionService;
  final ProductAnalyticsService _productAnalyticsService;
  final BehaviorSubject<PluginManagementLoadResult> _snapshots = BehaviorSubject();
  final BehaviorSubject<Map<String, PluginInstallProgress>> _installProgress = BehaviorSubject.seeded(const {});
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

  /// Plugin ids whose install this app started, so its analytics report counts
  /// installs rather than surfaces watching one.
  final Set<String> _selfStartedInstalls = {};

  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  /// In-flight managed runtime installs, keyed by plugin id. An entry appears
  /// when the bridge reports progress and disappears when the install settles.
  ValueStream<Map<String, PluginInstallProgress>> get installProgress => _installProgress.stream;

  Future<void> refresh() {
    _markStale();
    return _refreshTail ?? Future<void>.value();
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    final result = await _runMutation(
      request: () => _pluginRepository.command(pluginId: pluginId, request: request),
    );
    // Install progress is broadcast to every connected surface, so remember
    // which installs this app actually started — but only once the bridge has
    // accepted the command, so a rejected or offline attempt never claims a
    // later install someone else started.
    if (request is PluginLifecycleInstallRequest && result is PluginManagementMutationResultSuccess) {
      _selfStartedInstalls.add(pluginId);
    }
    return result;
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) {
    return _runMutation(
      request: () => _pluginRepository.updateIdleTimeout(request: request),
    );
  }

  PluginManagementCommandPlan planApplyAllIdleTimeout({required PluginManagementIdleTimeoutInput input}) {
    final idleTimeoutMins = _parseIdleTimeoutMins(input: input);
    if (idleTimeoutMins == null) return const PluginManagementCommandPlan.invalidInput();
    return PluginManagementCommandPlan.request(
      request: PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: idleTimeoutMins),
    );
  }

  PluginManagementCommandPlan planSetIdleTimeoutOverride({
    required String pluginId,
    required PluginManagementIdleTimeoutInput input,
  }) {
    final idleTimeoutMins = _parseIdleTimeoutMins(input: input);
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
        _invalidatePublishedSnapshot();
      }
      if (nextConnected) _markStale();
      return;
    }

    if (nextConnected != _connected) {
      _connectionEpoch++;
      _connected = nextConnected;
      _forgetActiveBridgeIdentity();
      _invalidatePublishedSnapshot();
    }
    if (nextConnected) _markStale();
  }

  void _onSseEvent(SseEvent event) {
    if (event.data case SesoriPluginInstallProgress(:final pluginId, :final phase, :final percent)) {
      _applyInstallProgress(pluginId: pluginId, phase: phase, percent: percent);
      return;
    }
    if (event.data case SesoriPluginManagementChanged(:final snapshotToken)) {
      final currentToken = switch (_currentSnapshot) {
        PluginManagementLoadResultSupported(:final response) => response.snapshotToken,
        PluginManagementLoadResultLoading() ||
        PluginManagementLoadResultUnsupported() ||
        PluginManagementLoadResultFailure() ||
        null => null,
      };
      if (snapshotToken == currentToken) return;
      _markStale();
    }
  }

  void _applyInstallProgress({
    required String pluginId,
    required PluginInstallPhase phase,
    required int? percent,
  }) {
    if (_disposed || _installProgress.isClosed) return;
    final next = Map<String, PluginInstallProgress>.from(_installProgress.value);
    switch (phase) {
      case PluginInstallPhase.completed || PluginInstallPhase.failed:
        // The terminal outcome is carried by the refreshed snapshot (and, on
        // failure, the harness' unchanged setup state), so the transient
        // progress entry is dropped here.
        final wasTracked = next.remove(pluginId) != null;
        // The bridge's terminal event is the authoritative outcome, so report
        // it here rather than at the tap — but only for an install this app
        // started, since every connected surface sees the same event.
        if (_selfStartedInstalls.remove(pluginId)) _reportInstallOutcome(phase: phase);
        if (!wasTracked) return;
      case PluginInstallPhase.downloading ||
          PluginInstallPhase.verifying ||
          PluginInstallPhase.extracting ||
          PluginInstallPhase.finalizing:
        next[pluginId] = PluginInstallProgress(phase: phase, percent: percent);
      case PluginInstallPhase.unknown:
        // A newer bridge phase: keep the row in an in-progress state without
        // claiming a phase this app can name.
        next[pluginId] = const PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null);
    }
    _installProgress.add(Map<String, PluginInstallProgress>.unmodifiable(next));
  }

  void _reportInstallOutcome({required PluginInstallPhase phase}) {
    final outcome = switch (phase) {
      PluginInstallPhase.completed => AnalyticsHarnessInstallOutcome.completed,
      PluginInstallPhase.failed => AnalyticsHarnessInstallOutcome.failed,
      PluginInstallPhase.downloading ||
      PluginInstallPhase.verifying ||
      PluginInstallPhase.extracting ||
      PluginInstallPhase.finalizing ||
      PluginInstallPhase.unknown => null,
    };
    if (outcome == null) return;
    unawaited(
      _productAnalyticsService
          .logEvent(
            event: ProductAnalyticsEvent.harnessInstallFinished(outcome: outcome),
            occurredAtUtc: DateTime.now().toUtc(),
          )
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report harness install outcome analytics event", error, stackTrace);
            return AnalyticsDeliveryResult.failed;
          }),
    );
  }

  void _clearInstallProgress() {
    // A new connection or bridge identity makes any pending outcome
    // unattributable, so authorship is forgotten with the progress itself.
    _selfStartedInstalls.clear();
    if (_disposed || _installProgress.isClosed || _installProgress.value.isEmpty) return;
    _installProgress.add(const {});
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
        PluginManagementLoadResultLoading() || PluginManagementLoadResultFailure() => null,
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
    if (!_isConnectionFenceCurrent(captured.fence)) {
      await _refreshAfterUncertainMutation();
      return const PluginManagementMutationResult.uncertain();
    }
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
      case PluginManagementLoadResultLoading():
        break;
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
    if (consumeStalenessThrough != null) {
      _consumeStalenessThrough(generation: consumeStalenessThrough);
    }
    return _PublicationOutcome.applied;
  }

  void _consumeStalenessThrough({required int generation}) {
    _consumedStaleGeneration = max(_consumedStaleGeneration, generation);
  }

  PluginManagementLoadResult? get _currentSnapshot => _snapshots.hasValue ? _snapshots.value : null;

  PluginManagementResponse? get _retainedSnapshotForActiveBridge {
    if (!_activeBridgeIdentityKnown) return null;
    return switch (_currentSnapshot) {
      PluginManagementLoadResultSupported(:final response) when response.bridgeId == _activeBridgeId => response,
      PluginManagementLoadResultLoading() ||
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
    _invalidatePublishedSnapshot();
  }

  void _invalidatePublishedSnapshot() {
    _publicationGeneration++;
    // Progress belongs to the bridge connection that reported it; a new
    // connection or bridge identity re-reports whatever is still running.
    _clearInstallProgress();
    _snapshots.add(const PluginManagementLoadResult.loading());
  }

  @override
  Future<void> onDispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscriptions.dispose();
    await _refreshTail;
    await _snapshots.close();
    await _installProgress.close();
  }
}

int? _parseIdleTimeoutMins({required PluginManagementIdleTimeoutInput input}) {
  return switch (input) {
    PluginManagementIdleTimeoutInputNoTimeout() => 0,
    PluginManagementIdleTimeoutInputCustom(:final input) => switch (int.tryParse(input.trim())) {
      final value? when value > 0 => value,
      _ => null,
    },
  };
}

/// One harness' in-flight managed runtime install, as last reported.
@immutable
class PluginInstallProgress {
  const PluginInstallProgress({required this.phase, required this.percent});

  final PluginInstallPhase phase;

  /// Download completion, only present while downloading with a known total.
  final int? percent;

  @override
  bool operator ==(Object other) =>
      other is PluginInstallProgress && other.phase == phase && other.percent == percent;

  @override
  int get hashCode => Object.hash(phase, percent);
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
