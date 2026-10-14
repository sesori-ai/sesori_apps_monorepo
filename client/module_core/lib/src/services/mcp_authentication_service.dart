import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/platform/active_bridge_locality.dart";
import "../logging/logging.dart";
import "../repositories/mcp_repository.dart";
import "../repositories/models/mcp_authentication_response.dart";
import "../repositories/models/plugin_management_result.dart";
import "models/mcp_authentication_client_state.dart";
import "plugin_authentication_browser_service.dart";
import "plugin_management_service.dart" show PluginManagementService;

/// One client observes the bridge's one native attempt; view closure is not cancellation.
@lazySingleton
class McpAuthenticationService({
  required final McpRepository _repository,
  required final ConnectionService _connectionService,
  required final PluginManagementService _managementService,
  required final PluginAuthenticationBrowserService _browserService,
  required final ActiveBridgeLocality _locality,
}) with Disposable {
  this {
    _subscriptions
      ..add(_connectionService.status.listen((status) => _onConnection(status: status)))
      ..add(_managementService.snapshots.listen((snapshot) => _onManagement(snapshot: snapshot)))
      ..add(
        _connectionService.events.listen((event) {
          if (event.data is SesoriMcpAuthenticationChanged) _invalidate();
        }),
      )
      ..add(_connectionService.dataMayBeStale.listen((_) => _invalidate()));
    unawaited(_managementService.refresh());
  }

  final _states = BehaviorSubject<McpAuthenticationClientState>.seeded(
    const McpAuthenticationClientState(
      observation: McpAuthenticationOffline(),
      request: McpAuthenticationRequestIdle(),
      browser: McpAuthenticationBrowserIdle(),
    ),
  );
  final _subscriptions = CompositeSubscription();
  ConnectionStatus _connection = _connectionService.currentStatus;
  String? _bridgeId;
  int _epoch = 0;
  int _observationVersion = 0;
  int _staleVersion = 0;
  int? _readingEpoch;
  int _mutationVersion = 0;
  ({String attemptId, PluginAuthenticationBrowserOwner owner, PluginAuthenticationBrowserChallenge challenge})?
  _browser;

  ValueStream<McpAuthenticationClientState> get states => _states.stream;
  McpAuthenticationClientState get currentState => _states.value;

  void _onConnection({required ConnectionStatus status}) {
    final next = status;
    final previous = _connection;
    if (_states.isClosed) return;
    if (next is! ConnectionConnected || previous is! ConnectionConnected || next.config != previous.config) {
      _reset();
    }
    _connection = next;
  }

  void _onManagement({required PluginManagementLoadResult snapshot}) {
    if (_states.isClosed || _connection is! ConnectionConnected) return;
    if (snapshot case PluginManagementLoadResultSupported(:final response, refreshError: null)) {
      if (_bridgeId != response.bridgeId) {
        _reset();
        _bridgeId = response.bridgeId;
        _invalidate();
      }
    } else if (_bridgeId == null) {
      _observe(
        observation: snapshot is PluginManagementLoadResultLoading
            ? const McpAuthenticationLoading()
            : McpAuthenticationIdentityUnavailable(cause: snapshot),
      );
    }
  }

  void _reset() {
    _epoch++;
    _bridgeId = null;
    unawaited(_releaseBrowser());
    _states.add(
      const McpAuthenticationClientState(
        observation: McpAuthenticationOffline(),
        request: McpAuthenticationRequestIdle(),
        browser: McpAuthenticationBrowserIdle(),
      ),
    );
  }

  bool _current({required int epoch}) =>
      !_states.isClosed && epoch == _epoch && _connection is ConnectionConnected && _bridgeId != null;

  void _invalidate() {
    _staleVersion++;
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final epoch = _epoch;
    if (!_current(epoch: epoch) || _readingEpoch == epoch) return;
    final stale = _staleVersion;
    final observation = _observationVersion;
    _readingEpoch = epoch;
    if (currentState.observation is! McpAuthenticationObserved) _observe(observation: const McpAuthenticationLoading());
    final response = await _repository.getAuthentication();
    if (!_current(epoch: epoch)) return;
    _readingEpoch = null;
    if (observation == _observationVersion) {
      _apply(response: response);
    } else {
      _staleVersion++;
    }
    if (_staleVersion > stale) unawaited(refresh());
  }

  Future<void> start({required McpAuthenticationStartRequest request}) async {
    if (currentState.request is McpAuthenticationRequestPending) return;
    if (_bridgeId == null) await _managementService.refresh();
    if (currentState.request is McpAuthenticationRequestPending) return;
    await _mutate(
      kind: McpAuthenticationRequestKind.start,
      send: () => _repository.startAuthentication(request: request),
    );
  }

  Future<void> cancel() async {
    final native = currentState.observation;
    if (native is! McpAuthenticationObserved) return;
    final attempt = mcpAuthenticationAttempt(state: native.state);
    if (attempt == null ||
        native.state is McpAuthenticationCompleted ||
        native.state is McpAuthenticationCancelled ||
        native.state is McpAuthenticationFailed) {
      return;
    }
    if (attempt.cancellation == McpAuthenticationCancellation.nativeSettlement) return;
    if (currentState.request case McpAuthenticationRequestPending(kind: McpAuthenticationRequestKind.cancellation)) {
      return;
    }
    // Read-only preparation can be cancelled even before its native mode is known.
    final epoch = _epoch;
    await _mutate(
      kind: McpAuthenticationRequestKind.cancellation,
      send: () async {
        _browserState(browser: const McpAuthenticationBrowserIdle());
        await _releaseBrowser();
        if (!_current(epoch: epoch)) {
          return const McpAuthenticationReceived(result: McpAuthenticationResultUnknown());
        }
        return await _repository.cancelAuthentication(
          request: McpAuthenticationCancelRequest(attemptId: attempt.attemptId),
        );
      },
    );
  }

  Future<void> _mutate({
    required McpAuthenticationRequestKind kind,
    required Future<McpAuthenticationResponse> Function() send,
  }) async {
    final epoch = _epoch;
    if (!_current(epoch: epoch)) return;
    final mutation = ++_mutationVersion;
    final observation = _observationVersion;
    _request(request: McpAuthenticationRequestPending(kind: kind));
    final response = await send();
    if (!_current(epoch: epoch) || mutation != _mutationVersion) return;
    _request(
      request: switch (response) {
        McpAuthenticationRequestFailed(:final cause) => McpAuthenticationRequestUncertain(cause: cause),
        McpAuthenticationReceived(result: McpAuthenticationStateResult()) => const McpAuthenticationRequestIdle(),
        McpAuthenticationReceived() ||
        McpAuthenticationRouteMissing() => McpAuthenticationRequestRejected(response: response),
      },
    );
    if (observation == _observationVersion &&
        response is McpAuthenticationReceived &&
        response.result is McpAuthenticationStateResult) {
      _apply(response: response);
    }
    // Invalidation GETs continue while the start POST waits for native readiness.
    // A slow response cannot replace newer native truth; uncertainty requires GET recovery.
    _invalidate();
  }

  void _apply({required McpAuthenticationResponse response}) {
    _observationVersion++;
    if (response case McpAuthenticationReceived(result: McpAuthenticationStateResult(:final state))) {
      final nextId = mcpAuthenticationAttempt(state: state)?.attemptId;
      final active =
          state is McpAuthenticationStarting ||
          state is McpAuthenticationCallbackChallenge ||
          state is McpAuthenticationSettling;
      final browser = _browser;
      final changedChallenge =
          browser != null &&
          state is McpAuthenticationCallbackChallenge &&
          (browser.challenge.authorizationUri.toString() != state.authorizationUrl ||
              browser.challenge.expectedCallbackUri.toString() != state.expectedCallbackUrl);
      if (!active || browser != null && (browser.attemptId != nextId || changedChallenge)) {
        unawaited(_releaseBrowser());
        _browserState(browser: const McpAuthenticationBrowserIdle());
      }
      _observe(observation: McpAuthenticationObserved(state: state, refreshFailure: null));
    } else {
      final previous = currentState.observation;
      _observe(
        observation: previous is McpAuthenticationObserved
            ? McpAuthenticationObserved(state: previous.state, refreshFailure: response)
            : McpAuthenticationReadFailure(response: response),
      );
    }
  }

  /// Recovery never launches a destination. Only this explicit user intent does.
  Future<void> openBrowser() async {
    final state = switch (currentState.observation) {
      McpAuthenticationObserved(state: final McpAuthenticationCallbackChallenge challenge) => challenge,
      McpAuthenticationIdentityUnavailable() ||
      McpAuthenticationOffline() ||
      McpAuthenticationLoading() ||
      McpAuthenticationReadFailure() ||
      McpAuthenticationObserved() => null,
    };
    final bridgeId = _bridgeId;
    if (state == null || bridgeId == null) return;
    final epoch = _epoch;
    if (!_current(epoch: epoch) ||
        currentState.browser is McpAuthenticationBrowserOpening ||
        currentState.browser is McpAuthenticationBrowserWaiting) {
      return;
    }
    final previous = _browser;
    final challenge = previous?.challenge ?? _repository.browserChallenge(state: state);
    if (challenge == null) {
      _browserState(
        browser: McpAuthenticationBrowserFailed(
          failure: PluginAuthenticationBrowserFlowFailed(
            innerError: const FormatException("Unsupported MCP authentication browser challenge"),
            stackTrace: StackTrace.current,
            retryableWithActiveListener: false,
          ),
        ),
      );
      return;
    }
    final owner =
        previous?.owner ??
        PluginAuthenticationBrowserOwner(
          bridgeId: bridgeId,
          connectionEpoch: epoch,
          purpose: PluginAuthenticationBrowserPurpose.mcp,
        );
    final result = await _browserService.authenticate(
      owner: owner,
      challenge: challenge,
      isLocalBridge: _locality.isLocalBridge(bridgeId: bridgeId),
      reuseActiveListener: previous != null,
      onPhase: (phase) {
        if (!_currentAttempt(epoch: epoch, attemptId: state.attempt.attemptId)) return;
        _browser = (attemptId: state.attempt.attemptId, owner: owner, challenge: challenge);
        _browserState(
          browser: switch (phase) {
            PluginAuthenticationBrowserPhase.opening => const McpAuthenticationBrowserOpening(),
            PluginAuthenticationBrowserPhase.waiting => const McpAuthenticationBrowserWaiting(),
          },
        );
      },
      onDetachedFailure: (failure) {
        if (_currentAttempt(epoch: epoch, attemptId: state.attempt.attemptId) && identical(_browser?.owner, owner)) {
          _browser = null;
          _browserState(browser: McpAuthenticationBrowserFailed(failure: failure));
        }
      },
    );
    if (!_currentAttempt(epoch: epoch, attemptId: state.attempt.attemptId)) return;
    switch (result) {
      case PluginAuthenticationBrowserBusy():
        _browserState(browser: const McpAuthenticationBrowserBlocked());
      case PluginAuthenticationBrowserDirect():
        _browserState(browser: const McpAuthenticationBrowserWaiting());
      case PluginAuthenticationBrowserCaptured(:final callbackUri):
        _browser = null;
        _browserState(browser: const McpAuthenticationBrowserIdle());
        if (currentState.observation case McpAuthenticationObserved(state: McpAuthenticationCallbackChallenge())) {
          await _mutate(
            kind: McpAuthenticationRequestKind.continuation,
            send: () => _repository.continueAuthentication(
              request: McpAuthenticationContinueRequest(
                attemptId: state.attempt.attemptId,
                callbackUrl: callbackUri.toString(),
              ),
            ),
          );
        }
      case PluginAuthenticationBrowserFlowCancelled():
        // Matching cleanup already owns native cancellation or connection teardown.
        if (!identical(_browser?.owner, owner) ||
            currentState.browser is! McpAuthenticationBrowserOpening &&
                currentState.browser is! McpAuthenticationBrowserWaiting) {
          return;
        }
        _browser = null;
        _browserState(browser: const McpAuthenticationBrowserIdle());
        await cancel();
      case PluginAuthenticationBrowserFlowFailed():
        if (!result.retryableWithActiveListener) _browser = null;
        _browserState(browser: McpAuthenticationBrowserFailed(failure: result));
    }
  }

  bool _currentAttempt({required int epoch, required String attemptId}) =>
      _current(epoch: epoch) &&
      switch (currentState.observation) {
        McpAuthenticationObserved(:final state) =>
          mcpAuthenticationAttempt(state: state)?.attemptId == attemptId &&
              (state is McpAuthenticationStarting ||
                  state is McpAuthenticationCallbackChallenge ||
                  state is McpAuthenticationSettling),
        McpAuthenticationIdentityUnavailable() ||
        McpAuthenticationOffline() ||
        McpAuthenticationLoading() ||
        McpAuthenticationReadFailure() => false,
      };

  Future<void> _releaseBrowser() async {
    final browser = _browser;
    if (browser == null) return;
    try {
      final failure = await _browserService.cancel(owner: browser.owner);
      if (identical(_browser?.owner, browser.owner)) {
        _browser = null;
        if (failure != null) {
          loge(
            "MCP authentication browser cleanup failed",
            _McpAuthenticationBrowserCleanupException(innerError: failure.innerError),
            failure.stackTrace,
          );
        }
      }
    } finally {
      if (identical(_browser?.owner, browser.owner)) _browser = null;
    }
  }

  void _observe({required McpAuthenticationObservation observation}) => _states.add(
    McpAuthenticationClientState(
      observation: observation,
      request: currentState.request,
      browser: currentState.browser,
    ),
  );
  void _request({required McpAuthenticationRequestState request}) => _states.add(
    McpAuthenticationClientState(
      observation: currentState.observation,
      request: request,
      browser: currentState.browser,
    ),
  );
  void _browserState({required McpAuthenticationBrowserState browser}) => _states.add(
    McpAuthenticationClientState(
      observation: currentState.observation,
      request: currentState.request,
      browser: browser,
    ),
  );

  @override
  Future<void> onDispose() async {
    _epoch++;
    _bridgeId = null;
    final closing = _states.close();
    await _subscriptions.cancel();
    await _releaseBrowser();
    await closing;
  }
}

final class const _McpAuthenticationBrowserCleanupException({required final Object innerError}) implements Exception {
  @override
  String toString() => "MCP authentication browser cleanup failed";
}
