import "dart:async";
import "dart:io";
import "dart:math";

import "package:collection/collection.dart";
import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/platform/active_bridge_locality.dart";
import "../foundation/platform/plugin_authentication_browser.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/models/plugin_management_result.dart";
import "../repositories/plugin_repository.dart";
import "models/plugin_install_state.dart";
import "plugin_authentication_browser_service.dart";
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

sealed class const PluginAuthenticationBrowserState();

final class const PluginAuthenticationBrowserOpening() extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserWaiting() extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserFinalizing() extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserCancelling() extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserCancellingUncertain() extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserRetryableFailure({
  required final PluginAuthenticationBrowserFlowFailed failure,
}) extends PluginAuthenticationBrowserState;

final class const PluginAuthenticationBrowserFatalFailure({
  required final PluginAuthenticationBrowserFlowFailed failure,
}) extends PluginAuthenticationBrowserState;

sealed class const PluginManagementIdleTimeoutInput() {
  const factory noTimeout() = PluginManagementIdleTimeoutInputNoTimeout;

  const factory custom({required String input}) = PluginManagementIdleTimeoutInputCustom;
}

final class const PluginManagementIdleTimeoutInputNoTimeout() extends PluginManagementIdleTimeoutInput;

final class const PluginManagementIdleTimeoutInputCustom({required final String input})
    extends PluginManagementIdleTimeoutInput;

@lazySingleton
class PluginManagementService({
  required final PluginRepository _pluginRepository,
  required final ConnectionService _connectionService,
  required final ProductAnalyticsService _productAnalyticsService,
  required final PluginAuthenticationBrowserService _authenticationBrowserService,
  required final ActiveBridgeLocality _activeBridgeLocality,
}) with Disposable {
  this {
    _subscriptions
      ..add(_connectionService.status.listen(_onConnectionStatus))
      ..add(_connectionService.events.listen(_onSseEvent))
      ..add(_connectionService.dataMayBeStale.listen((_) => _markStale()));
  }

  final BehaviorSubject<PluginManagementLoadResult> _snapshots = BehaviorSubject();
  final BehaviorSubject<Map<String, PluginInstallState>> _installStates = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, PluginAuthenticationChallenge>> _authenticationChallenges = BehaviorSubject.seeded(
    const {},
  );
  final StreamController<PluginAuthenticationTerminalUpdate> _authenticationTerminalController =
      StreamController<PluginAuthenticationTerminalUpdate>.broadcast(sync: true);
  final BehaviorSubject<Map<String, PluginAuthenticationBrowserState>> _authenticationBrowserStates =
      BehaviorSubject.seeded(const {}, sync: true);
  final CompositeSubscription _subscriptions = CompositeSubscription();

  bool _connected = _connectionService.currentStatus is ConnectionConnected;
  int _connectionEpoch = _connectionService.currentStatus is ConnectionConnected ? 1 : 0;
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

  /// Per-request identity prevents a stale same-plugin completion from
  /// releasing pending outcome coordination owned by a replacement attempt.
  final Map<String, ({_AuthenticationRequestToken token, _ManagementRequestFence fence})> _authenticationRequestOwners =
      {};
  final Set<String> _selfStartedAuthentications = {};
  final Map<String, PluginAuthenticationProgress> _pendingAuthenticationOutcomes = {};
  final Map<String, _ManagementRequestFence> _authenticationFences = {};
  final Map<String, _ManagementRequestFence> _authenticationRedirectClaims = {};
  final Map<String, Uri> _heldAuthenticationCallbacks = {};
  final Map<String, PluginAuthenticationProgress> _heldAuthenticationProgress = {};
  int _authenticationBrowserGeneration = 0;
  String? _activeAuthenticationBrowserPluginId;

  ValueStream<PluginManagementLoadResult> get snapshots => _snapshots.stream;

  /// Replayed in-progress installs and failures, scoped to this connection.
  ValueStream<Map<String, PluginInstallState>> get installStates => _installStates.stream;

  ValueStream<Map<String, PluginAuthenticationChallenge>> get authenticationChallenges =>
      _authenticationChallenges.stream;

  Stream<PluginAuthenticationTerminalUpdate> get authenticationTerminal => _authenticationTerminalController.stream;

  ValueStream<Map<String, PluginAuthenticationBrowserState>> get authenticationBrowserStates =>
      _authenticationBrowserStates.stream;

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
      _publishInstallStates(Map<String, PluginInstallState>.from(_installStates.value)..remove(pluginId));
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
    if (_disposed || !_connected || !_activeBridgeIdentityKnown || _selfStartedAuthentications.contains(pluginId)) {
      return PluginAuthenticationStartResult.failed(
        failure: PluginAuthenticationFailure.request(error: ApiError.generic()),
      );
    }
    final captured = _captureRequest(staleGeneration: _staleGeneration);
    final requestOwner = _AuthenticationRequestToken();
    _selfStartedAuthentications.add(pluginId);
    _authenticationRequestOwners[pluginId] = (token: requestOwner, fence: captured.fence);
    _authenticationFences[pluginId] = captured.fence;
    final result = await _pluginRepository.startAuthentication(pluginId: pluginId);
    final requestOwnership = _authenticationRequestOwners[pluginId];
    final currentFence = _authenticationFences[pluginId];
    final ownsStartResult =
        identical(requestOwnership?.token, requestOwner) &&
        requestOwnership?.fence == captured.fence &&
        _selfStartedAuthentications.contains(pluginId) &&
        currentFence != null &&
        _isConnectionFenceCurrent(currentFence) &&
        _activeBridgeIdentityKnown &&
        captured.fence.bridgeId == _activeBridgeId &&
        currentFence.bridgeId == captured.fence.bridgeId;
    if (!ownsStartResult) {
      if (identical(requestOwnership?.token, requestOwner)) _forgetAuthentication(pluginId: pluginId);
      return const PluginAuthenticationStartResult.failed(failure: PluginAuthenticationFailure.uncertain());
    }
    _authenticationRequestOwners.remove(pluginId);

    switch (result) {
      case PluginAuthenticationStartChallenge(:final challenge)
          when challenge is PluginAuthenticationUnsupportedChallenge ||
              challenge is PluginAuthenticationBrowserChallenge &&
                  _validatedAuthenticationRedirect(
                        rawInput: challenge.expectedCallbackUri.toString(),
                        challenge: challenge,
                      ) ==
                      null:
        const unsupportedChallenge = PluginAuthenticationUnsupportedChallenge();
        _publishAuthenticationChallenge(pluginId: pluginId, challenge: unsupportedChallenge);
        final pending = _pendingAuthenticationOutcomes.remove(pluginId);
        if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
        return const PluginAuthenticationStartResult.challenge(challenge: unsupportedChallenge);
      case PluginAuthenticationStartChallenge(:final challenge):
        _publishAuthenticationChallenge(pluginId: pluginId, challenge: challenge);
        final pending = _pendingAuthenticationOutcomes.remove(pluginId);
        if (pending != null) {
          _settleAuthentication(pluginId: pluginId, progress: pending);
        } else if (challenge is PluginAuthenticationBrowserChallenge) {
          _runBrowserAuthentication(pluginId: pluginId, reuseActiveListener: false);
        }
        return result;
      // An uncertain start may still have reached the bridge, so keep tracking
      // the plugin and let a pending outcome settle it.
      case PluginAuthenticationStartFailed(failure: PluginAuthenticationFailureUncertain()):
        final pending = _pendingAuthenticationOutcomes.remove(pluginId);
        if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
        return result;
      case PluginAuthenticationStartFailed():
        _forgetAuthentication(pluginId: pluginId);
        return result;
    }
  }

  Future<void> retryBrowserAuthentication({required String pluginId}) async {
    if (_authenticationBrowserStates.value[pluginId] is! PluginAuthenticationBrowserRetryableFailure) return;
    await _beginBrowserAuthentication(pluginId: pluginId, reuseActiveListener: true);
  }

  void _runBrowserAuthentication({required String pluginId, required bool reuseActiveListener}) {
    unawaited(
      _beginBrowserAuthentication(pluginId: pluginId, reuseActiveListener: reuseActiveListener).catchError(
        (Object error, StackTrace stackTrace) {
          loge(
            "Unexpected plugin authentication browser orchestration failure",
            _AuthenticationBrowserDiagnosticError(innerError: error),
            stackTrace,
          );
        },
      ),
    );
  }

  Future<void> _beginBrowserAuthentication({
    required String pluginId,
    required bool reuseActiveListener,
  }) async {
    final challenge = _authenticationChallenges.value[pluginId];
    final fence = _authenticationFences[pluginId];
    final bridgeId = fence?.bridgeId;
    if (challenge is! PluginAuthenticationBrowserChallenge ||
        fence == null ||
        bridgeId == null ||
        !_activeBridgeIdentityKnown ||
        bridgeId != _activeBridgeId) {
      return;
    }
    final generation = reuseActiveListener ? _authenticationBrowserGeneration : ++_authenticationBrowserGeneration;
    _activeAuthenticationBrowserPluginId = pluginId;
    final result = await _authenticationBrowserService.authenticate(
      challenge: challenge,
      isLocalBridge: _activeBridgeLocality.isLocalBridge(bridgeId: bridgeId),
      reuseActiveListener: reuseActiveListener,
      onPhase: (phase) {
        if (!_ownsBrowserOperation(pluginId: pluginId, generation: generation)) return;
        _publishAuthenticationBrowserState(
          pluginId: pluginId,
          browserState: switch (phase) {
            PluginAuthenticationBrowserPhase.opening => const PluginAuthenticationBrowserOpening(),
            PluginAuthenticationBrowserPhase.waiting => const PluginAuthenticationBrowserWaiting(),
          },
        );
      },
      onDetachedFailure: (failure) {
        _runDetachedBrowserFailure(pluginId: pluginId, generation: generation, failure: failure);
      },
    );
    if (!_ownsBrowserOperation(pluginId: pluginId, generation: generation)) return;
    switch (result) {
      case PluginAuthenticationBrowserDirect():
        _publishAuthenticationBrowserState(
          pluginId: pluginId,
          browserState: const PluginAuthenticationBrowserWaiting(),
        );
      case PluginAuthenticationBrowserCaptured(:final callbackUri):
        _heldAuthenticationCallbacks[pluginId] = callbackUri;
        _publishAuthenticationBrowserState(
          pluginId: pluginId,
          browserState: const PluginAuthenticationBrowserFinalizing(),
        );
        _runHeldAuthenticationCallback(pluginId: pluginId, generation: generation);
      case PluginAuthenticationBrowserFlowCancelled():
        _publishAuthenticationBrowserState(
          pluginId: pluginId,
          browserState: const PluginAuthenticationBrowserCancelling(),
        );
        _runAuthenticationCancellation(pluginId: pluginId);
      case final PluginAuthenticationBrowserFlowFailed failure when failure.retryableWithActiveListener:
        _recordBrowserFailure(failure: failure);
        _publishAuthenticationBrowserState(
          pluginId: pluginId,
          browserState: PluginAuthenticationBrowserRetryableFailure(failure: failure),
        );
      case final PluginAuthenticationBrowserFlowFailed failure:
        await _handleFatalBrowserFailure(pluginId: pluginId, generation: generation, failure: failure);
    }
  }

  bool _ownsBrowserOperation({required String pluginId, required int generation}) =>
      !_disposed &&
      generation == _authenticationBrowserGeneration &&
      _activeAuthenticationBrowserPluginId == pluginId &&
      _selfStartedAuthentications.contains(pluginId);

  void _runDetachedBrowserFailure({
    required String pluginId,
    required int generation,
    required PluginAuthenticationBrowserFlowFailed failure,
  }) {
    unawaited(
      _handleFatalBrowserFailure(pluginId: pluginId, generation: generation, failure: failure).catchError(
        (Object error, StackTrace stackTrace) {
          loge(
            "Unexpected detached plugin authentication browser failure",
            _AuthenticationBrowserDiagnosticError(innerError: error),
            stackTrace,
          );
        },
      ),
    );
  }

  Future<void> _handleFatalBrowserFailure({
    required String pluginId,
    required int generation,
    required PluginAuthenticationBrowserFlowFailed failure,
  }) async {
    _recordBrowserFailure(failure: failure);
    if (!_ownsBrowserOperation(pluginId: pluginId, generation: generation)) return;
    _publishAuthenticationBrowserState(
      pluginId: pluginId,
      browserState: PluginAuthenticationBrowserFatalFailure(failure: failure),
    );
    await _completeAuthenticationCancellation(pluginId: pluginId);
  }

  void _recordBrowserFailure({required PluginAuthenticationBrowserFlowFailed failure}) {
    loge(
      "Plugin authentication browser flow failed",
      _AuthenticationBrowserDiagnosticError(innerError: failure.innerError),
      failure.stackTrace,
    );
  }

  void _runAuthenticationCancellation({required String pluginId}) {
    unawaited(_completeAuthenticationCancellation(pluginId: pluginId));
  }

  Future<void> _completeAuthenticationCancellation({required String pluginId}) async {
    try {
      final result = await cancelAuthentication(pluginId: pluginId);
      if (result is PluginAuthenticationCancelFailed &&
          result.failure is! PluginAuthenticationFailureUncertain &&
          _selfStartedAuthentications.contains(pluginId)) {
        _settleAuthentication(
          pluginId: pluginId,
          progress: const PluginAuthenticationProgress.failed(message: "Browser authentication could not continue"),
        );
      }
    } on Object catch (error, stackTrace) {
      loge(
        "Unexpected plugin authentication cancellation failure",
        _AuthenticationBrowserDiagnosticError(innerError: error),
        stackTrace,
      );
      if (_selfStartedAuthentications.contains(pluginId)) {
        _settleAuthentication(
          pluginId: pluginId,
          progress: const PluginAuthenticationProgress.failed(message: "Browser authentication could not continue"),
        );
      }
    }
  }

  void _runHeldAuthenticationCallback({required String pluginId, required int generation}) {
    unawaited(
      _dispatchHeldAuthenticationCallback(pluginId: pluginId, generation: generation).catchError(
        (Object error, StackTrace stackTrace) {
          loge(
            "Unexpected plugin authentication callback forwarding failure",
            _AuthenticationBrowserDiagnosticError(innerError: error),
            stackTrace,
          );
        },
      ),
    );
  }

  Future<void> _dispatchHeldAuthenticationCallback({required String pluginId, required int generation}) async {
    final callbackUri = _heldAuthenticationCallbacks[pluginId];
    if (callbackUri == null || !_connected || !_isAuthenticationFenceCurrent(pluginId: pluginId)) return;
    final result = await submitAuthenticationRedirect(pluginId: pluginId, capturedRedirectUri: callbackUri);
    if (_disposed ||
        generation != _authenticationBrowserGeneration ||
        _heldAuthenticationCallbacks[pluginId] != callbackUri) {
      return;
    }
    switch (result) {
      case PluginAuthenticationContinuationApplied() ||
          PluginAuthenticationContinuationUncertain() ||
          PluginAuthenticationContinuationRejected(reason: PluginAuthenticationContinuationRejection.alreadySubmitted):
        _heldAuthenticationCallbacks.remove(pluginId);
      case PluginAuthenticationContinuationInvalidRedirect() ||
          PluginAuthenticationContinuationNotFound() ||
          PluginAuthenticationContinuationRejected() ||
          PluginAuthenticationContinuationRequestFailure():
        _heldAuthenticationCallbacks.remove(pluginId);
        final failure = PluginAuthenticationBrowserFlowFailed(
          innerError: StateError("Bridge rejected captured authentication callback"),
          stackTrace: StackTrace.current,
          retryableWithActiveListener: false,
        );
        await _handleFatalBrowserFailure(pluginId: pluginId, generation: generation, failure: failure);
    }
  }

  Future<PluginAuthenticationContinuationResult> submitAuthenticationRedirect({
    required String pluginId,
    required Uri capturedRedirectUri,
  }) async {
    final fence = _authenticationFences[pluginId];
    if (_disposed || !_connected || fence == null || !_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      return const PluginAuthenticationContinuationResult.uncertain();
    }
    final challenge = _authenticationChallenges.value[pluginId];
    if (challenge == null) {
      return const PluginAuthenticationContinuationResult.rejected(
        reason: PluginAuthenticationContinuationRejection.noActive,
      );
    }
    if (challenge is! PluginAuthenticationBrowserChallenge) {
      return const PluginAuthenticationContinuationResult.rejected(
        reason: PluginAuthenticationContinuationRejection.wrongKind,
      );
    }
    if (_authenticationRedirectClaims[pluginId] == fence) {
      return const PluginAuthenticationContinuationResult.rejected(
        reason: PluginAuthenticationContinuationRejection.alreadySubmitted,
      );
    }
    final redirectUri = _validatedAuthenticationRedirect(
      rawInput: capturedRedirectUri.toString(),
      challenge: challenge,
    );
    if (redirectUri == null) return const PluginAuthenticationContinuationResult.invalidRedirect();

    _authenticationRedirectClaims[pluginId] = fence;
    final result = await _pluginRepository.submitAuthenticationRedirect(pluginId: pluginId, redirectUri: redirectUri);
    if (!_isConnectionFenceCurrent(fence) ||
        !_activeBridgeIdentityKnown ||
        _activeBridgeId != fence.bridgeId ||
        _authenticationFences[pluginId] != null && _authenticationFences[pluginId] != fence) {
      return const PluginAuthenticationContinuationResult.uncertain();
    }
    if (result is PluginAuthenticationContinuationInvalidRedirect ||
        result is PluginAuthenticationContinuationNotFound ||
        result is PluginAuthenticationContinuationRejected &&
            (result.reason == PluginAuthenticationContinuationRejection.noActive ||
                result.reason == PluginAuthenticationContinuationRejection.wrongKind)) {
      _authenticationRedirectClaims.remove(pluginId);
    }
    return result;
  }

  Future<PluginAuthenticationCancelResult> cancelAuthentication({required String pluginId}) async {
    final originalFence = _authenticationFences[pluginId];
    if (originalFence == null || !_ownsAuthenticationFence(pluginId: pluginId, fence: originalFence)) {
      return PluginAuthenticationCancelResult.failed(
        failure: PluginAuthenticationFailure.request(error: ApiError.generic()),
      );
    }
    if (_authenticationChallenges.value[pluginId] is PluginAuthenticationBrowserChallenge &&
        _authenticationBrowserStates.value[pluginId] is! PluginAuthenticationBrowserFatalFailure) {
      _publishAuthenticationBrowserState(
        pluginId: pluginId,
        browserState: const PluginAuthenticationBrowserCancelling(),
      );
    }
    await _cancelOwnedBrowserCapture(pluginId: pluginId);
    if (!_ownsAuthenticationFence(pluginId: pluginId, fence: originalFence)) {
      return const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain());
    }

    final requestOwner = _AuthenticationRequestToken();
    _authenticationRequestOwners[pluginId] = (token: requestOwner, fence: originalFence);
    late final PluginAuthenticationCancelResult result;
    try {
      try {
        result = await _pluginRepository.cancelAuthentication(pluginId: pluginId);
      } finally {
        if (identical(_authenticationRequestOwners[pluginId]?.token, requestOwner)) {
          _authenticationRequestOwners.remove(pluginId);
        }
      }
    } on Object {
      if (!_ownsAuthenticationFence(pluginId: pluginId, fence: originalFence)) {
        _reissuePendingAuthenticationCancellation(pluginId: pluginId);
        return const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain());
      }
      rethrow;
    }
    if (!_ownsAuthenticationFence(pluginId: pluginId, fence: originalFence)) {
      _reissuePendingAuthenticationCancellation(pluginId: pluginId);
      return const PluginAuthenticationCancelResult.failed(failure: PluginAuthenticationFailure.uncertain());
    }
    final pending = _pendingAuthenticationOutcomes.remove(pluginId);
    if (pending != null) _settleAuthentication(pluginId: pluginId, progress: pending);
    if (result case PluginAuthenticationCancelFailed(failure: PluginAuthenticationFailureUncertain())
        when _authenticationChallenges.value[pluginId] is PluginAuthenticationBrowserChallenge &&
            _authenticationBrowserStates.value[pluginId] is! PluginAuthenticationBrowserFatalFailure) {
      _publishAuthenticationBrowserState(
        pluginId: pluginId,
        browserState: const PluginAuthenticationBrowserCancellingUncertain(),
      );
    }
    return result;
  }

  bool _ownsAuthenticationFence({required String pluginId, required _ManagementRequestFence fence}) =>
      !_disposed &&
      _selfStartedAuthentications.contains(pluginId) &&
      _authenticationFences[pluginId] == fence &&
      _isConnectionFenceCurrent(fence) &&
      _activeBridgeIdentityKnown &&
      _activeBridgeId == fence.bridgeId;

  bool _authenticationCancellationPending({required String pluginId}) =>
      switch (_authenticationBrowserStates.value[pluginId]) {
        PluginAuthenticationBrowserFatalFailure() ||
        PluginAuthenticationBrowserCancelling() ||
        PluginAuthenticationBrowserCancellingUncertain() => true,
        PluginAuthenticationBrowserOpening() ||
        PluginAuthenticationBrowserWaiting() ||
        PluginAuthenticationBrowserFinalizing() ||
        PluginAuthenticationBrowserRetryableFailure() ||
        null => false,
      };

  void _reissuePendingAuthenticationCancellation({required String pluginId}) {
    final fence = _authenticationFences[pluginId];
    if (!_authenticationCancellationPending(pluginId: pluginId) ||
        fence == null ||
        _authenticationRequestOwners[pluginId]?.fence == fence ||
        !_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      return;
    }
    _runAuthenticationCancellation(pluginId: pluginId);
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
    if (nextConnected != _connected) {
      final preserveAuthentication = _selfStartedAuthentications.isNotEmpty;
      _connectionEpoch++;
      _connected = nextConnected;
      _forgetActiveBridgeIdentity();
      _invalidatePublishedSnapshot(preserveAuthentication: preserveAuthentication);
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
    if (_authenticationRequestOwners.containsKey(pluginId)) {
      _pendingAuthenticationOutcomes[pluginId] = progress;
      return;
    }
    if (_selfStartedAuthentications.contains(pluginId) &&
        _authenticationFences.containsKey(pluginId) &&
        !_isAuthenticationFenceCurrent(pluginId: pluginId)) {
      _heldAuthenticationProgress[pluginId] = progress;
      return;
    }
    _settleAuthentication(pluginId: pluginId, progress: progress);
  }

  void _settleAuthentication({required String pluginId, required PluginAuthenticationProgress progress}) {
    _finishAuthentication(
      pluginId: pluginId,
      progress: progress,
      startedHere: _selfStartedAuthentications.contains(pluginId) && _isAuthenticationFenceCurrent(pluginId: pluginId),
    );
  }

  void _settleRetainedAuthentication({required String pluginId, required PluginAuthenticationProgress progress}) {
    _finishAuthentication(
      pluginId: pluginId,
      progress: progress,
      startedHere: _selfStartedAuthentications.contains(pluginId),
    );
  }

  void _finishAuthentication({
    required String pluginId,
    required PluginAuthenticationProgress progress,
    required bool startedHere,
  }) {
    if (!startedHere) return;
    _runOwnedBrowserCaptureCancellation(pluginId: pluginId);
    _forgetAuthentication(pluginId: pluginId);
    if (!_authenticationTerminalController.isClosed) {
      _authenticationTerminalController.add((pluginId: pluginId, progress: progress));
    }
  }

  void _runOwnedBrowserCaptureCancellation({required String pluginId}) {
    unawaited(
      _cancelOwnedBrowserCapture(pluginId: pluginId).catchError((Object error, StackTrace stackTrace) {
        loge(
          "Unexpected plugin authentication browser cleanup failure",
          _AuthenticationBrowserDiagnosticError(innerError: error),
          stackTrace,
        );
      }),
    );
  }

  Future<void> _cancelOwnedBrowserCapture({required String pluginId}) async {
    if (_activeAuthenticationBrowserPluginId != pluginId) return;
    _activeAuthenticationBrowserPluginId = null;
    _authenticationBrowserGeneration++;
    final failure = await _authenticationBrowserService.cancelActive();
    if (failure != null) _recordBrowserFailure(failure: failure);
  }

  void _publishAuthenticationBrowserState({
    required String pluginId,
    required PluginAuthenticationBrowserState browserState,
  }) {
    if (_disposed || _authenticationBrowserStates.isClosed) return;
    _authenticationBrowserStates.add(
      Map<String, PluginAuthenticationBrowserState>.unmodifiable({
        ..._authenticationBrowserStates.value,
        pluginId: browserState,
      }),
    );
  }

  Uri? _validatedAuthenticationRedirect({
    required String rawInput,
    required PluginAuthenticationBrowserChallenge challenge,
  }) {
    if (rawInput.isEmpty || rawInput.length > PluginAuthenticationRedirectRequest.maxRedirectUrlLength) return null;
    final redirectUri = Uri.tryParse(rawInput);
    final expected = challenge.expectedCallbackUri;
    if (redirectUri == null ||
        !redirectUri.isAbsolute ||
        redirectUri.userInfo.isNotEmpty ||
        redirectUri.fragment.isNotEmpty ||
        !_isLoopbackHost(expected.host) ||
        expected.userInfo.isNotEmpty ||
        expected.fragment.isNotEmpty ||
        (expected.scheme != "http" && expected.scheme != "https") ||
        redirectUri.scheme != expected.scheme ||
        redirectUri.host != expected.host ||
        redirectUri.port != expected.port ||
        redirectUri.path != expected.path) {
      return null;
    }
    return redirectUri;
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
    _authenticationRequestOwners.remove(pluginId);
    _pendingAuthenticationOutcomes.remove(pluginId);
    _authenticationFences.remove(pluginId);
    _authenticationRedirectClaims.remove(pluginId);
    _heldAuthenticationCallbacks.remove(pluginId);
    _heldAuthenticationProgress.remove(pluginId);
    if (!_disposed &&
        !_authenticationBrowserStates.isClosed &&
        _authenticationBrowserStates.value.containsKey(pluginId)) {
      _authenticationBrowserStates.add(
        Map<String, PluginAuthenticationBrowserState>.unmodifiable(
          Map<String, PluginAuthenticationBrowserState>.from(_authenticationBrowserStates.value)..remove(pluginId),
        ),
      );
    }
    if (_disposed || _authenticationChallenges.isClosed || !_authenticationChallenges.value.containsKey(pluginId)) {
      return;
    }
    _authenticationChallenges.add(
      Map<String, PluginAuthenticationChallenge>.unmodifiable(
        Map<String, PluginAuthenticationChallenge>.from(_authenticationChallenges.value)..remove(pluginId),
      ),
    );
  }

  void _clearAuthentications({bool cancelBrowser = true}) {
    _selfStartedAuthentications.clear();
    _authenticationRequestOwners.clear();
    _pendingAuthenticationOutcomes.clear();
    _authenticationFences.clear();
    _authenticationRedirectClaims.clear();
    _heldAuthenticationCallbacks.clear();
    _heldAuthenticationProgress.clear();
    _authenticationBrowserGeneration++;
    _activeAuthenticationBrowserPluginId = null;
    if (cancelBrowser) {
      unawaited(
        _authenticationBrowserService.cancelActive().then((failure) {
          if (failure != null) _recordBrowserFailure(failure: failure);
        }),
      );
    }
    if (!_disposed && !_authenticationBrowserStates.isClosed && _authenticationBrowserStates.value.isNotEmpty) {
      _authenticationBrowserStates.add(const {});
    }
    if (_disposed || _authenticationChallenges.isClosed || _authenticationChallenges.value.isEmpty) return;
    _authenticationChallenges.add(const {});
  }

  void _applyInstallProgress({
    required String pluginId,
    required PluginInstallPhase phase,
    required int? percent,
  }) {
    if (_disposed || _installStates.isClosed) return;
    final next = Map<String, PluginInstallState>.from(_installStates.value);
    switch (phase) {
      case PluginInstallPhase.completed || PluginInstallPhase.failed:
        if (phase == PluginInstallPhase.failed) {
          next[pluginId] = const PluginInstallState.failed();
        } else {
          next.remove(pluginId);
        }
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
        next[pluginId] = PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: phase, percent: percent),
        );
      case PluginInstallPhase.unknown:
        // A newer bridge phase: keep the row in an in-progress state without
        // claiming a phase this app can name.
        next[pluginId] = const PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
        );
    }
    _publishInstallStates(next);
  }

  /// Drops [pluginId]'s progress entry so its Install row is tappable again.
  /// Only meaningful once authorship has been released, since
  /// [_publishInstallStates] re-adds a synthetic entry for tracked installs.
  void _releaseInstallRow({required String pluginId}) {
    if (_installStates.value[pluginId] is! PluginInstallInProgress) return;
    _publishInstallStates(Map<String, PluginInstallState>.from(_installStates.value)..remove(pluginId));
  }

  /// Publishes [progress] plus a synthetic entry for every install this app
  /// started that the bridge has not reported on yet, so the row stays busy for
  /// the whole window between the tap and the first progress event — which
  /// spans the command's own round trip and the gap after it.
  void _publishInstallStates(Map<String, PluginInstallState> progress) {
    if (_disposed || _installStates.isClosed) return;
    final next = Map<String, PluginInstallState>.from(progress);
    for (final pluginId in _selfStartedInstalls) {
      next.putIfAbsent(
        pluginId,
        () => const PluginInstallState.inProgress(
          progress: PluginInstallProgress(phase: PluginInstallPhase.unknown, percent: null),
        ),
      );
    }
    _installStates.add(Map<String, PluginInstallState>.unmodifiable(next));
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

  void _clearInstallStates() {
    // A new connection or bridge identity makes any pending outcome
    // unattributable, so authorship is forgotten with the progress itself. The
    // in-flight set goes too, otherwise a command still awaiting its response
    // would resurrect a busy row on the fresh connection.
    _selfStartedInstalls.clear();
    _pendingInstallOutcomes.clear();
    _installRequestsInFlight.clear();
    if (_disposed || _installStates.isClosed || _installStates.value.isEmpty) return;
    _installStates.add(const {});
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
    final snapshot = _currentSnapshot;
    if (_disposed ||
        !_connected ||
        !_activeBridgeIdentityKnown ||
        snapshot is! PluginManagementLoadResultSupported ||
        snapshot.response.bridgeId != _activeBridgeId) {
      return PluginManagementMutationResult.failure(error: ApiError.generic());
    }

    final captured = _captureRequest(staleGeneration: _staleGeneration);
    final result = await request();
    if (!_isConnectionFenceCurrent(captured.fence)) {
      await _refreshAfterMutation();
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
        if (publication == _PublicationOutcome.applied) return result;

        await _refreshAfterMutation();
        // An intervening publication rejects this snapshot, not the correlated
        // acknowledgment. Recheck identity after reconciliation: that GET can
        // itself discover a replacement bridge, or outlive the connection.
        if (publication == _PublicationOutcome.superseded &&
            _isConnectionFenceCurrent(captured.fence) &&
            _activeBridgeIdentityKnown &&
            _activeBridgeId == response.bridgeId) {
          return result;
        }
        return const PluginManagementMutationResult.uncertain();
      case PluginManagementMutationResultUncertain():
        await _refreshAfterMutation();
        return result;
      case PluginManagementMutationResultNotFound() ||
          PluginManagementMutationResultConflict() ||
          PluginManagementMutationResultFailure():
        return result;
    }
  }

  Future<void> _refreshAfterMutation() async {
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
    // Identity changes invalidate every captured request, even when a newer
    // publication already prevents this response from replacing the snapshot.
    if (candidate case PluginManagementLoadResultSupported(:final response)
        when _responseIdentitySupersedesRequest(response: response, captured: captured)) {
      _invalidateBridgeIdentityFence();
      _rearmStale();
      return _PublicationOutcome.identitySuperseded;
    }
    if (_publicationGeneration != captured.fence.publicationGeneration) {
      _rearmStale();
      return _PublicationOutcome.superseded;
    }

    var publication = candidate;
    switch (candidate) {
      case PluginManagementLoadResultLoading():
        break;
      case PluginManagementLoadResultSupported(:final response):
        _activeBridgeIdentityKnown = true;
        _activeBridgeId = response.bridgeId;
        _reconcileAuthenticationAfterRefresh(response: response);
        final installs = Map<String, PluginInstallState>.from(_installStates.value);
        for (final plugin in response.plugins) {
          final runtimeInstalled =
              plugin.setup.state == PluginSetupState.ready ||
              plugin.setup.state == PluginSetupState.authenticationRequired;
          if (runtimeInstalled && installs[plugin.setup.id] is PluginInstallFailed) {
            installs.remove(plugin.setup.id);
          }
        }
        if (installs.length != _installStates.value.length) {
          _publishInstallStates(installs);
        }
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

  void _invalidatePublishedSnapshot({bool preserveAuthentication = false}) {
    _publicationGeneration++;
    // Progress belongs to the bridge connection that reported it; a new
    // connection or bridge identity re-reports whatever is still running.
    _clearInstallStates();
    if (!preserveAuthentication) {
      _clearAuthentications();
      _snapshots.add(const PluginManagementLoadResult.loading());
    }
  }

  void _reconcileAuthenticationAfterRefresh({required PluginManagementResponse response}) {
    for (final pluginId in _selfStartedAuthentications.toList(growable: false)) {
      final fence = _authenticationFences[pluginId];
      if (fence == null || _isConnectionFenceCurrent(fence)) continue;
      final plugin = response.plugins.firstWhereOrNull((candidate) => candidate.setup.id == pluginId);
      if (fence.bridgeId == response.bridgeId) {
        _authenticationFences[pluginId] = (
          connectionEpoch: _connectionEpoch,
          publicationGeneration: _publicationGeneration,
          staleGeneration: _staleGeneration,
          bridgeId: response.bridgeId,
        );
        final heldProgress = _heldAuthenticationProgress.remove(pluginId);
        if (heldProgress != null) {
          _settleAuthentication(pluginId: pluginId, progress: heldProgress);
        } else if (plugin?.authenticationState == PluginAuthenticationState.inProgress) {
          if (_authenticationCancellationPending(pluginId: pluginId)) {
            _reissuePendingAuthenticationCancellation(pluginId: pluginId);
          } else {
            final generation = _authenticationBrowserGeneration;
            _runHeldAuthenticationCallback(pluginId: pluginId, generation: generation);
          }
        } else {
          _settleAuthentication(pluginId: pluginId, progress: const PluginAuthenticationProgress.unknown());
        }
      } else {
        _settleRetainedAuthentication(
          pluginId: pluginId,
          progress: const PluginAuthenticationProgress.unknown(),
        );
      }
    }
  }

  @override
  Future<void> onDispose() async {
    if (_disposed) return;
    _disposed = true;
    final cleanupFailure = await _authenticationBrowserService.cancelActive();
    if (cleanupFailure != null) _recordBrowserFailure(failure: cleanupFailure);
    _clearAuthentications(cancelBrowser: false);
    await _subscriptions.dispose();
    await _refreshTail;
    await _snapshots.close();
    await _installStates.close();
    await _authenticationChallenges.close();
    await _authenticationTerminalController.close();
    await _authenticationBrowserStates.close();
  }
}

final class _AuthenticationRequestToken();

final class _AuthenticationBrowserDiagnosticError({required final Object innerError}) {
  @override
  String toString() => switch (innerError) {
    final PluginAuthenticationBrowserPlatformException error => error.toString(),
    SocketException(:final osError, :final address, :final port) =>
      "Authentication socket failure (${osError?.toString()}; address=${address?.address}; port=${port?.toString()})",
    TimeoutException(:final duration) => "Authentication browser timed out (duration=${duration?.toString()})",
    _ => "Authentication browser failure (${innerError.runtimeType.toString()})",
  };
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

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == "localhost" || normalized == "::1") return true;
  final octets = normalized.split(".");
  if (octets.length != 4 || octets.first != "127") return false;
  return octets.every((octet) {
    final value = int.tryParse(octet);
    return value != null && value >= 0 && value <= 255 && value.toString() == octet;
  });
}

enum _RefreshOutcome() {
  applied,
  failed,
  superseded,
  fenced,
}

enum _PublicationOutcome() {
  applied,
  fenced,
  superseded,
  identitySuperseded,
}

sealed class const PluginManagementCommandPlan() {
  const factory request({
    required PluginIdleTimeoutUpdateRequest request,
  }) = PluginManagementCommandPlanRequest;

  const factory invalidInput() = PluginManagementCommandPlanInvalidInput;
}

final class const PluginManagementCommandPlanRequest({required final PluginIdleTimeoutUpdateRequest request})
    extends PluginManagementCommandPlan;

final class const PluginManagementCommandPlanInvalidInput() extends PluginManagementCommandPlan;

enum PluginManagementForceAction() {
  disable,
  restart,
}

sealed class const PluginManagementForceAssessment() {
  const factory requiresConfirmation({
    required PluginLifecycleCommandRequest request,
  }) = PluginManagementForceAssessmentRequiresConfirmation;

  const factory notForceable() = PluginManagementForceAssessmentNotForceable;
}

final class const PluginManagementForceAssessmentRequiresConfirmation({
  required final PluginLifecycleCommandRequest request,
}) extends PluginManagementForceAssessment;

final class const PluginManagementForceAssessmentNotForceable() extends PluginManagementForceAssessment;

const _forceableConflictReasons = {
  PluginLifecycleConflictReason.inFlight,
  PluginLifecycleConflictReason.busy,
  PluginLifecycleConflictReason.workStateUnknown,
};
