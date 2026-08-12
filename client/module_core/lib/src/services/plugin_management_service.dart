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

typedef PluginAuthenticationTerminalUpdate = ({String pluginId, PluginAuthenticationProgress progress});

sealed class const PluginManagementIdleTimeoutInput() {
  const factory PluginManagementIdleTimeoutInput.noTimeout() = PluginManagementIdleTimeoutInputNoTimeout;

  const factory PluginManagementIdleTimeoutInput.custom({required String input}) =
      PluginManagementIdleTimeoutInputCustom;
}

final class const PluginManagementIdleTimeoutInputNoTimeout() extends PluginManagementIdleTimeoutInput;

final class const PluginManagementIdleTimeoutInputCustom({required this.input}) extends PluginManagementIdleTimeoutInput {
  final String input;
}

@lazySingleton
class PluginManagementService({
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
    required ProductAnalyticsService productAnalyticsService,
  }) with Disposable {
  this : _pluginRepository = pluginRepository,
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
  final BehaviorSubject<Map<String, PluginAuthenticationChallenge>> _authenticationChallenges = BehaviorSubject.seeded(
    const {},
  );
  final StreamController<PluginAuthenticationTerminalUpdate> _authenticationTerminalController =
      StreamController<PluginAuthenticationTerminalUpdate>.broadcast(sync: true);
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
  /// installs rather than surfaces watching one. An id is added when the
  /// command is issued and removed when its terminal event is reported or the
  /// bridge rejects the command.
  final Set<String> _selfStartedInstalls = {};

  /// Terminal phases that arrived before the issuing command returned. A fast
  /// install can settle within the request round trip, so the outcome is held
  /// here until acceptance is known rather than dropped.
  final Map<String, PluginInstallPhase> _pendingInstallOutcomes = {};

  /// Plugin ids with an install command still awaiting its response, used only
  /// to decide whether a terminal event must be held until acceptance is known.
  final Set<String> _installRequestsInFlight = {};
  final Set<String> _authenticationRequestsInFlight = {};
  final Set<String> _selfStartedAuthentications = {};
  final Map<String, PluginAuthenticationProgress> _pendingAuthenticationOutcomes = {};
  final Map<String, _ManagementRequestFence> _authenticationFences = {};

  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  /// In-flight managed runtime installs, keyed by plugin id. An entry appears
  /// when the bridge reports progress and disappears when the install settles.
  ValueStream<Map<String, PluginInstallProgress>> get installProgress => _installProgress.stream;

  ValueStream<Map<String, PluginAuthenticationChallenge>> get authenticationChallenges =>
      _authenticationChallenges.stream;

  Stream<PluginAuthenticationTerminalUpdate> get authenticationTerminal => _authenticationTerminalController.stream;

  Future<void> refresh() {
    _markStale();
    return _refreshTail ?? Future<void>.value();
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    final isInstall = request is PluginLifecycleInstallRequest;
    // Install progress is broadcast to every connected surface, so track which
    // installs this app started. Authorship is claimed up front because the
    // bridge can finish a cached install before this request returns; a
    // rejected command withdraws it below.
    if (isInstall) {
      _selfStartedInstalls.add(pluginId);
      _installRequestsInFlight.add(pluginId);
      _publishInstallProgress(_installProgress.value);
    }
    final result = await _runMutation(
      request: () => _pluginRepository.command(pluginId: pluginId, request: request),
    );
    if (!isInstall) return result;

    _installRequestsInFlight.remove(pluginId);

    // A terminal event that raced the response proves the bridge ran this
    // install, whatever the response ended up saying, so it settles the
    // install regardless of the result branch below.
    final pending = _pendingInstallOutcomes.remove(pluginId);
    if (pending != null) {
      if (_selfStartedInstalls.remove(pluginId)) _reportInstallOutcome(phase: pending);
      _releaseInstallRow(pluginId: pluginId);
      return result;
    }

    switch (result) {
      // Accepted: authorship and the busy row persist until the bridge's
      // terminal event. An uncertain outcome may still have reached the bridge
      // (the relay documents a lost response as possibly-dispatched), so it is
      // treated the same way — re-enabling Install could start a second
      // multi-minute download.
      case PluginManagementMutationResultSuccess() || PluginManagementMutationResultUncertain():
        return result;
      // A definite rejection: withdraw authorship so a later install of the
      // same harness, started elsewhere, is not misattributed to this app, and
      // drop the synthetic busy entry written at tap time.
      case PluginManagementMutationResultNotFound() ||
          PluginManagementMutationResultConflict() ||
          PluginManagementMutationResultFailure():
        _selfStartedInstalls.remove(pluginId);
        _releaseInstallRow(pluginId: pluginId);
        return result;
    }
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) {
    return _runMutation(
      request: () => _pluginRepository.updateIdleTimeout(request: request),
    );
  }

  Future<PluginAuthenticationStartResult> startAuthentication({required String pluginId}) async {
    if (_disposed || !_connected || !_activeBridgeIdentityKnown) {
      return PluginAuthenticationStartResult.failure(error: ApiError.generic());
    }
    final captured = _captureRequest(staleGeneration: _staleGeneration);
    _selfStartedAuthentications.add(pluginId);
    _authenticationRequestsInFlight.add(pluginId);
    _authenticationFences[pluginId] = captured.fence;
    final result = await _pluginRepository.startAuthentication(pluginId: pluginId);
    _authenticationRequestsInFlight.remove(pluginId);
    if (!_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      _forgetAuthentication(pluginId: pluginId);
      return const PluginAuthenticationStartResult.uncertain();
    }

    switch (result) {
      case PluginAuthenticationStartChallenge(:final challenge):
        final mapped = _mapAuthenticationChallenge(challenge);
        if (mapped == null) {
          _forgetAuthentication(pluginId: pluginId);
          return PluginAuthenticationStartResult.failure(error: ApiError.generic());
        }
        _publishAuthenticationChallenge(pluginId: pluginId, challenge: mapped);
        final pending = _pendingAuthenticationOutcomes.remove(pluginId);
        if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
        return result;
      case PluginAuthenticationStartUncertain():
        final pending = _pendingAuthenticationOutcomes.remove(pluginId);
        if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
        return result;
      case PluginAuthenticationStartNotFound() ||
          PluginAuthenticationStartConflict() ||
          PluginAuthenticationStartUnsupported() ||
          PluginAuthenticationStartFailure():
        _forgetAuthentication(pluginId: pluginId);
        return result;
    }
  }

  Future<PluginAuthenticationCancelResult> cancelAuthentication({required String pluginId}) async {
    if (_disposed || !_connected || !_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      return PluginAuthenticationCancelResult.failure(error: ApiError.generic());
    }
    _authenticationRequestsInFlight.add(pluginId);
    final result = await _pluginRepository.cancelAuthentication(pluginId: pluginId);
    _authenticationRequestsInFlight.remove(pluginId);
    if (!_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      return const PluginAuthenticationCancelResult.uncertain();
    }
    final pending = _pendingAuthenticationOutcomes.remove(pluginId);
    if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
    return result;
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
    if (event.data case SesoriPluginAuthenticationProgress(:final pluginId, :final progress)) {
      _applyAuthenticationProgress(pluginId: pluginId, progress: progress);
      return;
    }
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

  void _applyAuthenticationProgress({required String pluginId, required PluginAuthenticationProgress progress}) {
    if (_disposed) return;
    _markStale();
    if (_authenticationRequestsInFlight.contains(pluginId)) {
      _pendingAuthenticationOutcomes[pluginId] = progress;
      return;
    }
    _settleAuthentication(pluginId: pluginId, progress: progress);
  }

  void _settleAuthentication({required String pluginId, required PluginAuthenticationProgress progress}) {
    final startedHere =
        _selfStartedAuthentications.contains(pluginId) && _isAuthenticationFenceCurrent(pluginId: pluginId);
    _forgetAuthentication(pluginId: pluginId);
    if (startedHere && !_authenticationTerminalController.isClosed) {
      _authenticationTerminalController.add((pluginId: pluginId, progress: progress));
    }
  }

  PluginAuthenticationChallenge? _mapAuthenticationChallenge(PluginAuthenticationChallengeResponse challenge) {
    return switch (challenge) {
      PluginAuthenticationDeviceCodeChallengeResponse(
        :final verificationUrl,
        :final userCode,
      ) =>
        switch (Uri.tryParse(verificationUrl)) {
          final uri? when uri.scheme == "https" && uri.host.isNotEmpty => PluginAuthenticationChallenge(
            verificationUri: uri,
            userCode: userCode,
          ),
          _ => null,
        },
    };
  }

  bool _isAuthenticationFenceCurrent({required String pluginId}) {
    final fence = _authenticationFences[pluginId];
    return fence != null &&
        _isConnectionFenceCurrent(fence) &&
        _activeBridgeIdentityKnown &&
        _activeBridgeId == fence.bridgeId;
  }

  void _publishAuthenticationChallenge({
    required String pluginId,
    required PluginAuthenticationChallenge challenge,
  }) {
    if (_disposed || _authenticationChallenges.isClosed) return;
    _authenticationChallenges.add(
      Map<String, PluginAuthenticationChallenge>.unmodifiable({
        ..._authenticationChallenges.value,
        pluginId: challenge,
      }),
    );
  }

  void _forgetAuthentication({required String pluginId}) {
    _selfStartedAuthentications.remove(pluginId);
    _authenticationRequestsInFlight.remove(pluginId);
    _pendingAuthenticationOutcomes.remove(pluginId);
    _authenticationFences.remove(pluginId);
    if (_disposed || _authenticationChallenges.isClosed || !_authenticationChallenges.value.containsKey(pluginId)) {
      return;
    }
    _authenticationChallenges.add(
      Map<String, PluginAuthenticationChallenge>.unmodifiable(
        Map<String, PluginAuthenticationChallenge>.from(_authenticationChallenges.value)..remove(pluginId),
      ),
    );
  }

  void _clearAuthentications() {
    _selfStartedAuthentications.clear();
    _authenticationRequestsInFlight.clear();
    _pendingAuthenticationOutcomes.clear();
    _authenticationFences.clear();
    if (_disposed || _authenticationChallenges.isClosed || _authenticationChallenges.value.isEmpty) return;
    _authenticationChallenges.add(const {});
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
        next.remove(pluginId);
        // The bridge's terminal event is the authoritative outcome, so report
        // it here rather than at the tap — but only for an install this app
        // started, since every connected surface sees the same event. While
        // this app's own command is still in flight, hold the outcome until
        // acceptance is known instead of dropping or misreporting it.
        if (_installRequestsInFlight.contains(pluginId)) {
          _pendingInstallOutcomes[pluginId] = phase;
        } else if (_selfStartedInstalls.remove(pluginId)) {
          _reportInstallOutcome(phase: phase);
        }
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
    _publishInstallProgress(next);
  }

  /// Drops [pluginId]'s progress entry so its Install row is tappable again.
  /// Only meaningful once authorship has been released, since
  /// [_publishInstallProgress] re-adds a synthetic entry for tracked installs.
  void _releaseInstallRow({required String pluginId}) {
    _publishInstallProgress(
      Map<String, PluginInstallProgress>.from(_installProgress.value)..remove(pluginId),
    );
  }

  /// Publishes [progress] plus a synthetic entry for every install this app
  /// started that the bridge has not reported on yet, so the row stays busy for
  /// the whole window between the tap and the first progress event — which
  /// spans the command's own round trip and the gap after it.
  void _publishInstallProgress(Map<String, PluginInstallProgress> progress) {
    if (_disposed || _installProgress.isClosed) return;
    final next = Map<String, PluginInstallProgress>.from(progress);
    for (final pluginId in _selfStartedInstalls) {
      next.putIfAbsent(
        pluginId,
        () => const PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
      );
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
    // unattributable, so authorship is forgotten with the progress itself. The
    // in-flight set goes too, otherwise a command still awaiting its response
    // would resurrect a busy row on the fresh connection.
    _selfStartedInstalls.clear();
    _pendingInstallOutcomes.clear();
    _installRequestsInFlight.clear();
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
    _clearAuthentications();
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
    await _authenticationChallenges.close();
    await _authenticationTerminalController.close();
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
class const PluginInstallProgress({required this.phase, required this.percent}) {
  final PluginInstallPhase phase;

  /// Download completion, only present while downloading with a known total.
  final int? percent;

  @override
  bool operator ==(Object other) => other is PluginInstallProgress && other.phase == phase && other.percent == percent;

  @override
  int get hashCode => Object.hash(phase, percent);
}

@immutable
class const PluginAuthenticationChallenge({required this.verificationUri, required this.userCode}) {
  final Uri verificationUri;
  final String userCode;

  @override
  bool operator ==(Object other) =>
      other is PluginAuthenticationChallenge && other.verificationUri == verificationUri && other.userCode == userCode;

  @override
  int get hashCode => Object.hash(verificationUri, userCode);
}

enum _RefreshOutcome() { applied, failed, superseded, fenced }

enum _PublicationOutcome() { applied, fenced, superseded, identitySuperseded }

sealed class const PluginManagementCommandPlan() {
  const factory PluginManagementCommandPlan.request({
    required PluginIdleTimeoutUpdateRequest request,
  }) = PluginManagementCommandPlanRequest;

  const factory PluginManagementCommandPlan.invalidInput() = PluginManagementCommandPlanInvalidInput;
}

final class const PluginManagementCommandPlanRequest({required this.request}) extends PluginManagementCommandPlan {
  final PluginIdleTimeoutUpdateRequest request;
}

final class const PluginManagementCommandPlanInvalidInput() extends PluginManagementCommandPlan;

enum PluginManagementForceAction() { disable, restart }

sealed class const PluginManagementForceAssessment() {
  const factory PluginManagementForceAssessment.requiresConfirmation({
    required PluginLifecycleCommandRequest request,
  }) = PluginManagementForceAssessmentRequiresConfirmation;

  const factory PluginManagementForceAssessment.notForceable() = PluginManagementForceAssessmentNotForceable;
}

final class const PluginManagementForceAssessmentRequiresConfirmation({required this.request}) extends PluginManagementForceAssessment {
  final PluginLifecycleCommandRequest request;
}

final class const PluginManagementForceAssessmentNotForceable() extends PluginManagementForceAssessment;

const _forceableConflictReasons = {
  PluginLifecycleConflictReason.inFlight,
  PluginLifecycleConflictReason.busy,
  PluginLifecycleConflictReason.workStateUnknown,
};
