import "dart:async";
import "dart:convert";
import "dart:math";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/relay/room_key_storage.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../relay/relay_client.dart";
import "../relay/relay_config.dart";
import "api_paths.dart";
import "models/connection_status.dart";
import "models/sse_event.dart";
import "server_connection_config.dart";

@lazySingleton
class ClockProvider {
  const ClockProvider();

  DateTime call() => DateTime.now();
}

@lazySingleton
class RelayClientFactory {
  const RelayClientFactory();

  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
  }) => RelayClient(
    relayHost: relayHost,
    cryptoService: cryptoService,
    roomKeyStorage: roomKeyStorage,
    authToken: authToken,
  );
}

@lazySingleton
class ConnectionService {
  final RelayCryptoService _cryptoService;
  final RoomKeyStorage _roomKeyStorage;
  final LifecycleSource _lifecycleSource;
  final AuthTokenProvider _authTokenProvider;
  final AuthSession _authSession;
  final FailureReporter _failureReporter;
  final ClockProvider _clock;
  final RelayClientFactory _relayClientFactory;

  final BehaviorSubject<ConnectionStatus> _status = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
  final StreamController<SseEvent> _events = StreamController<SseEvent>.broadcast();
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  final _compositeSubscription = CompositeSubscription();

  RelayClient? _relayClient;
  RelayClient? _connectingRelayClient;
  StreamSubscription<RelaySseEvent>? _relaySseSubscription;
  StreamSubscription<BridgeStatus>? _bridgeStatusSubscription;
  StreamSubscription<void>? _socketClosedSubscription;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectDelayCompleter;
  Future<bool>? _activeAuthConnect;
  Future<void>? _activeDisconnect;
  int _requestCounter = 0;
  final Random _requestIdRandom = Random();
  int _authRetryCount = 0;
  Duration _relayReconnectBackoff = const Duration(seconds: 1);
  // Last health metadata fetched on a fresh-DH connect. Resumed reconnects skip
  // the /global/health round-trip, so this is reused to keep the degraded
  // filesystem-access warning stable across reconnects instead of clearing it.
  HealthResponse? _lastHealth;
  int _reconnectAttemptId = 0;
  bool _isInBackground = false;
  DateTime? _backgroundedAt;

  static const _maxRelayReconnectBackoff = Duration(seconds: 30);

  /// Once the app has been backgrounded longer than this, the relay has very
  /// likely already closed our phone socket: it pings every 30s with a 15s
  /// pong deadline, and a suspended app cannot answer in time. Past this point
  /// a status that still reads "connected" can no longer be trusted, so on
  /// resume we reconnect proactively instead of waiting to discover the dead
  /// socket via a request timeout.
  static const _resumeReconnectThreshold = Duration(seconds: 20);

  /// 90% of the bridge's SSE replay window, providing a safety margin
  /// to ensure we detect staleness before events are actually lost.
  static final Duration staleThreshold = Duration(
    milliseconds: (sseReplayWindow.inMilliseconds * 0.9).round(),
  );

  ConnectionService(
    RelayCryptoService cryptoService,
    RoomKeyStorage roomKeyStorage,
    AuthTokenProvider authTokenProvider,
    AuthSession authSession,
    LifecycleSource lifecycleSource,
    FailureReporter failureReporter, {
    @visibleForTesting ClockProvider clock = const ClockProvider(),
    @visibleForTesting RelayClientFactory relayClientFactory = const RelayClientFactory(),
  }) : _cryptoService = cryptoService,
       _roomKeyStorage = roomKeyStorage,
       _authTokenProvider = authTokenProvider,
       _authSession = authSession,
       _lifecycleSource = lifecycleSource,
       _failureReporter = failureReporter,
       _clock = clock,
       _relayClientFactory = relayClientFactory {
    _compositeSubscription.add(
      _lifecycleSource.lifecycleStateStream.listen((state) {
        switch (state) {
          case .resumed:
            _onAppResumed();
          case .inactive:
            break;
          case .hidden:
            break;
          case .paused:
            _onAppBackgrounded();
          case .detached:
            break;
        }
      }),
    );
    _compositeSubscription.add(
      _authSession.authStateStream.listen((state) {
        switch (state) {
          case AuthAuthenticated():
            unawaited(connectWithFreshAuthToken());
          case AuthUnauthenticated():
            disconnect();
            unawaited(
              _roomKeyStorage.clearRoomKey().catchError((Object error, StackTrace stackTrace) {
                loge("Failed to clear room key after logout", error, stackTrace);
              }),
            );
          case AuthInitial():
          case AuthAuthenticating():
          case AuthFailed():
            break;
        }
      }),
    );
  }

  /// Connects to the relay using the best currently available auth token.
  ///
  /// Used after explicit auth success and by screens that were reached from a
  /// local-only startup decision. Errors are logged and represented as `false`.
  Future<bool> connectWithFreshAuthToken() {
    return _activeAuthConnect ??= _connectWithFreshAuthToken().whenComplete(() {
      _activeAuthConnect = null;
    });
  }

  Future<bool> _connectWithFreshAuthToken() async {
    try {
      if (_status.value is ConnectionConnected || _status.value is ConnectionBridgeOffline) {
        return true;
      }
      final token = await _authTokenProvider.getFreshAccessToken(minTtl: const Duration(minutes: 2));
      if (token == null) {
        logw("Auto-connect after auth skipped: no valid token");
        return false;
      }
      final config = ServerConnectionConfig(relayHost: relayHost, authToken: token);
      final result = await connect(config);
      return result is SuccessResponse<HealthResponse>;
    } catch (error, stackTrace) {
      loge("Auto-connect after auth failed", error, stackTrace);
      return false;
    }
  }

  /// Called by the platform layer when the app moves to the background.
  /// CLI/TUI apps that have no lifecycle events simply never call this.
  void _onAppBackgrounded() {
    if (_isInBackground) return;
    _isInBackground = true;
    _backgroundedAt = _clock();
    logd("App backgrounded — pausing reconnect attempts");
    _reconnectTimer?.cancel();
    if (_reconnectDelayCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Push-based connection status stream.
  /// Late subscribers immediately receive the current value.
  ValueStream<ConnectionStatus> get status => _status.stream;

  /// Push-based SSE event stream for all typed events.
  Stream<SseEvent> get events => _events.stream;

  Stream<void> get dataMayBeStale => _dataMayBeStale.stream;

  /// Filtered stream of events scoped to [sessionId], already typed as
  /// [SesoriSessionEvent]. Enables exhaustive switching in session cubits
  /// without leaking unrelated event types.
  Stream<SesoriSessionEvent> sessionEvents(String sessionId) => _events.stream
      .where((event) => event.sessionId == sessionId)
      .map((event) => event.data)
      .whereType<SesoriSessionEvent>();

  /// Synchronous access to the current connection status.
  ConnectionStatus get currentStatus => _status.value;

  @visibleForTesting
  void emitStatusForTesting(ConnectionStatus status) {
    _status.add(status);
  }

  /// The active config, or null if disconnected.
  ServerConnectionConfig? get activeConfig => switch (_status.value) {
    ConnectionConnected(:final config) => config,
    ConnectionLost(:final config) => config,
    ConnectionReconnecting(:final config) => config,
    ConnectionBridgeOffline(:final config) => config,
    ConnectionDisconnected() => null,
  };

  /// The current project directory. Set when the user enters a
  /// project context and used by feature cubits/services as request context.
  String? _activeDirectory;
  String? get activeDirectory => _activeDirectory;
  RelayClient? get relayClient => _relayClient;

  void setActiveDirectory(String directory) {
    _activeDirectory = directory;
  }

  /// Stateless transport primitive: declares to the bridge which session this
  /// phone is currently viewing ([sessionId] == null when viewing nothing).
  /// Fire-and-forget; silently no-ops when not connected. The viewing-state
  /// machine (current session, reconnect/lifecycle re-assert) is owned by
  /// `SessionViewingService` (Layer 3), not here.
  Future<void> sendSessionView({required String? sessionId}) async {
    await _relayClient?.sendSessionView(sessionId: sessionId);
  }

  /// Connects to the server. Health-checks first, then opens SSE stream
  /// for ongoing heartbeat monitoring.
  Future<ApiResponse<HealthResponse>> connect(
    ServerConnectionConfig config,
  ) async => (await _connectViaRelay(config)).response;

  Future<({ApiResponse<HealthResponse> response, int? closeCode})> _connectViaRelay(
    ServerConnectionConfig config, {
    bool Function()? isStale,
  }) async {
    await _disconnectRelayClient();

    // If a newer reconnect attempt superseded us (or we were disconnected) while
    // the previous socket was tearing down, don't open a replacement — otherwise
    // two sockets briefly race for the same account (relay close code 4005).
    if (isStale?.call() ?? false) {
      return (response: ApiResponse<HealthResponse>.error(ApiError.generic()), closeCode: null);
    }

    final relayClient = _relayClientFactory.call(
      relayHost: config.relayHost,
      cryptoService: _cryptoService,
      roomKeyStorage: _roomKeyStorage,
      authToken: config.authToken,
    );
    _connectingRelayClient = relayClient;

    if (isStale?.call() ?? false) {
      _clearConnectingRelayClient(relayClient);
      await relayClient.disconnect();
      return (response: ApiResponse<HealthResponse>.error(ApiError.generic()), closeCode: null);
    }

    try {
      await relayClient.connect();

      // If this attempt was superseded while the websocket handshake awaited,
      // stop before sending health on a socket that a newer attempt now owns.
      if (isStale?.call() ?? false) {
        _clearConnectingRelayClient(relayClient);
        await relayClient.disconnect();
        return (response: ApiResponse<HealthResponse>.error(ApiError.generic()), closeCode: null);
      }

      // connect() returned but isConnected is false: the relay accepted and is
      // holding our socket open, but no bridge is in the account group yet, so
      // no E2E session exists. Commit the socket and arm the bridge-status
      // watcher, skipping the health probe (no session encryptor) and SSE (needs
      // the room key). When a bridge appears the relay pushes bridge_connected;
      // _subscribeBridgeStatus then drives a reconnect that runs a fresh key
      // exchange — the same recovery path as a bridge that drops after a live
      // connection. No await runs between the staleness check above and this
      // commit, so there is no superseding race to re-check. Gate on the
      // transport state being `connected` too: a bridge-absent park sets the
      // state to connected with no session encryptor, whereas a disposed/early
      // return leaves it in `connecting` — only the former should park here.
      if (relayClient.connectionState == RelayClientConnectionState.connected && !relayClient.isConnected) {
        const bridgeOfflineHealth = HealthResponse(healthy: true, version: "", filesystemAccessDegraded: null);
        _clearConnectingRelayClient(relayClient);
        _relayClient = relayClient;
        _authRetryCount = 0;
        _relayReconnectBackoff = const Duration(seconds: 1);
        try {
          _subscribeBridgeStatus(
            relayClient: relayClient,
            config: config,
            health: bridgeOfflineHealth,
          );
          _watchSocketClosedWhileBridgeOffline(relayClient);
        } catch (error, stackTrace) {
          loge("Failed to set up watchers after bridge-absent relay connect", error, stackTrace);
          await _disconnectRelayClient();
          return (
            response: ApiResponse<HealthResponse>.error(ApiError.generic()),
            closeCode: relayClient.lastCloseCode,
          );
        }
        _status.add(ConnectionStatus.bridgeOffline(config: config, health: bridgeOfflineHealth));
        return (response: ApiResponse.success(bridgeOfflineHealth), closeCode: null);
      }

      // A resume_ack already proves the bridge is reachable; only fresh-DH
      // connects need the extra health round-trip. A non-error status code is
      // sufficient proof that the bridge request path is live. Plugin
      // lifecycle and diagnostics are discovered through plugin-scoped APIs.
      //
      // On a RESUMED connect we reuse the last fetched health so a previously
      // reported degraded-filesystem warning stays stable across reconnects
      // (the bridge's access hasn't changed and we don't re-probe).
      //
      // On a FRESH connect we parse the body (when present) so the bridge can
      // report a degraded filesystem-access warning. A new bridge identity is
      // being probed here, so an unparseable/legacy body must fall back to the
      // plain-healthy default — NOT a cached flag from a previous bridge, which
      // would otherwise leak a stale degraded warning onto a different bridge.
      const defaultHealth = HealthResponse(healthy: true, version: "", filesystemAccessDegraded: null);
      HealthResponse health;
      if (relayClient.didResume) {
        health = _lastHealth ?? defaultHealth;
      } else {
        final response = await relayClient.sendRequest(
          RelayRequest(
            id: _nextRelayRequestId(),
            method: "GET",
            path: ApiPaths.health,
            headers: {},
            body: null,
          ),
        );

        if (response.status < 200 || response.status >= 300 || response.body == null) {
          _clearConnectingRelayClient(relayClient);
          await relayClient.disconnect();
          return (
            response: ApiResponse<HealthResponse>.error(
              ApiError.nonSuccessCode(
                errorCode: response.status,
                rawErrorString: response.body,
              ),
            ),
            closeCode: relayClient.lastCloseCode,
          );
        }

        health = _parseHealthResponse(response.body) ?? defaultHealth;
      }

      // The handshake spanned several awaits; if a newer attempt or a disconnect
      // landed meanwhile, tear down this socket instead of committing it as the
      // live connection.
      if (isStale?.call() ?? false) {
        _clearConnectingRelayClient(relayClient);
        await relayClient.disconnect();
        return (response: ApiResponse<HealthResponse>.error(ApiError.generic()), closeCode: null);
      }

      // Cache health only after the staleness gate, so a superseded attempt
      // never updates the warning shown for the live connection.
      _lastHealth = health;

      _clearConnectingRelayClient(relayClient);
      _relayClient = relayClient;
      _authRetryCount = 0;
      _relayReconnectBackoff = const Duration(seconds: 1);
      try {
        _openRelaySseStream(relayClient);
        _subscribeBridgeStatus(
          relayClient: relayClient,
          config: config,
          health: health,
        );
      } catch (error, stackTrace) {
        loge("Failed to setup SSE streams after successful relay connect", error, stackTrace);
        await _disconnectRelayClient();
        return (
          response: ApiResponse<HealthResponse>.error(ApiError.generic()),
          closeCode: relayClient.lastCloseCode,
        );
      }
      _status.add(ConnectionStatus.connected(config: config, health: health));
      return (response: ApiResponse.success(health), closeCode: null);
    } catch (error, stackTrace) {
      loge("Failed to connect via relay", error, stackTrace);
      final closeCode = relayClient.lastCloseCode;
      _clearConnectingRelayClient(relayClient);
      try {
        await relayClient.disconnect().timeout(const Duration(seconds: 3));
      } catch (disconnectError, disconnectStackTrace) {
        logw("Best-effort relay disconnect failed after connect error: ${disconnectError.toString()}");
        loge("Relay disconnect cleanup failed", disconnectError, disconnectStackTrace);
      }
      return (response: ApiResponse<HealthResponse>.error(ApiError.generic()), closeCode: closeCode);
    }
  }

  void _clearConnectingRelayClient(RelayClient relayClient) {
    if (identical(_connectingRelayClient, relayClient)) {
      _connectingRelayClient = null;
    }
  }

  /// Parses the `/global/health` response body into a [HealthResponse].
  ///
  /// Returns `null` when the body is absent or malformed (e.g. an older bridge
  /// that returns an empty `{}` body), so the caller keeps its healthy
  /// fallback rather than failing the connection.
  // COMPATIBILITY 2026-06-27 (v1.2.0): Old bridges may return an empty health body. Fail malformed health responses once those bridges are unsupported.
  HealthResponse? _parseHealthResponse(String? body) {
    if (body == null) return null;
    try {
      return HealthResponse.fromJson(jsonDecodeMap(body));
    } on Object catch (error, stackTrace) {
      // An older bridge returns an empty `{}` body here, which is expected and
      // benign — keep the healthy fallback rather than treating it as failure.
      logd("Health response body not parseable; assuming healthy", error, stackTrace);
      return null;
    }
  }

  /// Manually disconnect. Clears config, closes SSE, cancels timers.
  void disconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectDelayCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    unawaited(_disconnectRelayClient());
    _status.add(const ConnectionStatus.disconnected());
  }

  /// Manually trigger reconnect attempt (e.g. from the overlay).
  void reconnect() {
    final config = activeConfig;
    if (config == null) return;

    _reconnectTimer?.cancel();
    if (_reconnectDelayCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    _relayReconnectBackoff = const Duration(seconds: 1);
    _status.add(ConnectionStatus.reconnecting(config: config));
    unawaited(_reconnectRelayWithRefresh(config, immediate: true));
  }

  // ---------------------------------------------------------------------------
  // SSE stream management
  // ---------------------------------------------------------------------------

  void _openRelaySseStream(RelayClient relayClient) {
    final previousSubscription = _relaySseSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }

    _relaySseSubscription = relayClient
        .subscribeSse(ApiPaths.sseEvents)
        .listen(
          (event) {
            _onSseData(event.data);
          },
          onError: (Object error, StackTrace stackTrace) {
            loge("Relay SSE stream error", error, stackTrace);
            _onRelayConnectionDrop();
          },
          onDone: _onRelayConnectionDrop,
        );
  }

  void _subscribeBridgeStatus({
    required RelayClient relayClient,
    required ServerConnectionConfig config,
    required HealthResponse health,
  }) {
    _bridgeStatusSubscription = relayClient.bridgeStatus.listen(
      (status) {
        switch (status) {
          case BridgeStatus.online:
            if (_status.value is ConnectionBridgeOffline) {
              logd("Bridge came back online — reconnecting to re-establish encryption");
              // immediate: the bridge is provably present and the parked (or
              // stale) socket needs replacing now, so skip the reconnect backoff
              // delay. Backoff still applies to genuinely failed retries, so a
              // flapping bridge is not hammered.
              unawaited(_reconnectRelayWithRefresh(config, immediate: true));
            }
          case BridgeStatus.offline:
            if (_status.value is ConnectionConnected) {
              logd("Bridge went offline — entering bridge offline state");
              _status.add(ConnectionStatus.bridgeOffline(config: config, health: health));
            }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        loge("Bridge status stream error", error, stackTrace);
      },
    );
  }

  /// While parked in [ConnectionBridgeOffline] with no SSE stream (the bridge
  /// never came online, so there is no room key and no SSE subscription), the
  /// SSE drop handler that normally detects a dead socket is absent. Watch the
  /// relay socket directly so a relay restart or network drop while waiting is
  /// recovered the same way an SSE drop would be.
  void _watchSocketClosedWhileBridgeOffline(RelayClient relayClient) {
    _socketClosedSubscription = relayClient.onSocketClosed.listen(
      (_) {
        logd("Relay socket closed while bridge offline — handling as a connection drop");
        _onRelayConnectionDrop();
      },
      onError: (Object error, StackTrace stackTrace) {
        loge("Relay socket-closed stream error", error, stackTrace);
      },
    );
  }

  void _onSseData(String rawData) {
    if (rawData.isEmpty) return;

    try {
      // ignore: no_slop_linter/prefer_specific_type, JSON decode requires dynamic values
      final decoded = jsonDecode(rawData);
      // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires dynamic
      if (decoded is! Map<String, dynamic>) return;

      final payloadValue = decoded["payload"];
      // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires dynamic
      if (payloadValue is! Map<String, dynamic>) return;

      final typeValue = payloadValue["type"];
      if (typeValue is! String) return;

      final propertiesValue = payloadValue["properties"];
      // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires dynamic
      final properties = propertiesValue is Map<String, dynamic> ? propertiesValue : <String, dynamic>{};
      // ignore: no_slop_linter/prefer_specific_type
      final merged = <String, Object?>{"type": typeValue, ...properties};

      final SesoriSseEvent eventData;
      try {
        eventData = SesoriSseEvent.fromJson(merged);
      } catch (e, st) {
        loge("Failed to parse SSE event payload", e, st);
        _failureReporter.recordFailure(
          error: e,
          stackTrace: st,
          uniqueIdentifier: "sse_parse_failure:$typeValue",
          fatal: false,
          reason: "Unknown or malformed SSE event type: $typeValue",
          information: properties.entries.map((e) => "${e.key}: ${e.value.toString()}").toList(),
        );
        return;
      }

      logd("[SSE] event: ${eventData.runtimeType}");
      final directory = switch (decoded["directory"]) {
        final String value => value,
        _ => null,
      };
      _events.add(SseEvent(data: eventData, directory: directory));
    } catch (e, st) {
      loge("Failed to parse SSE frame", e, st);
    }
  }

  /// Tears down the active relay client, coalescing concurrent callers so an
  /// eager teardown (e.g. on resume) and the reconnect path's own teardown share
  /// a single in-flight operation. A replacement socket is therefore never
  /// opened until the previous client's disconnect has fully completed, avoiding
  /// briefly holding two phone sockets for the same account (which the relay can
  /// reject as account-full at the device limit).
  Future<void> _disconnectRelayClient() {
    return _activeDisconnect ??= _doDisconnectRelayClient().whenComplete(() {
      _activeDisconnect = null;
    });
  }

  Future<void> _doDisconnectRelayClient() async {
    // Detach the client synchronously first so callers (e.g. RelayHttpApiClient)
    // stop routing requests through a socket we're tearing down, rather than
    // during the async subscription cancellations below.
    final relayClient = _relayClient;
    final connectingRelayClient = _connectingRelayClient;
    _relayClient = null;
    _connectingRelayClient = null;

    // Never let teardown complete with an error: several callers invoke this via
    // `unawaited(...)`, so a thrown cancellation/disconnect error would surface
    // as an uncaught async error in the zone.
    try {
      await _relaySseSubscription?.cancel();
    } catch (error, stackTrace) {
      loge("Failed to cancel relay SSE subscription", error, stackTrace);
    }
    _relaySseSubscription = null;

    try {
      await _bridgeStatusSubscription?.cancel();
    } catch (error, stackTrace) {
      loge("Failed to cancel bridge status subscription", error, stackTrace);
    }
    _bridgeStatusSubscription = null;

    try {
      await _socketClosedSubscription?.cancel();
    } catch (error, stackTrace) {
      loge("Failed to cancel relay socket-closed subscription", error, stackTrace);
    }
    _socketClosedSubscription = null;

    if (relayClient == null && connectingRelayClient == null) {
      return;
    }

    for (final client in <RelayClient?>{
      relayClient,
      connectingRelayClient,
    }.whereType<RelayClient>()) {
      try {
        await client.disconnect();
      } catch (error, stackTrace) {
        loge("Failed to disconnect relay client", error, stackTrace);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnect cycle
  // ---------------------------------------------------------------------------

  void _onAppResumed() {
    if (!_isInBackground) return;
    _isInBackground = false;
    logd("App resumed — checking connection state");

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    final backgroundedFor = backgroundedAt == null ? Duration.zero : _clock().difference(backgroundedAt);

    if (backgroundedAt != null && backgroundedFor >= staleThreshold && activeConfig != null) {
      logd("App was backgrounded for $backgroundedFor — emitting stale reconnect signal");
      _dataMayBeStale.add(null);
    }

    final status = _status.value;
    final config = activeConfig;
    if (config == null) return;

    // The relay closes backgrounded phones once its ping/pong window lapses
    // (~30-45s). Past [_resumeReconnectThreshold], a still-"connected" status is
    // almost certainly a dead socket, so reconnect proactively rather than
    // discovering it later via a request timeout.
    //
    // ConnectionBridgeOffline is treated the same way: while parked waiting for
    // the bridge, the relay can reap our backgrounded socket and with it the
    // bridge-status watcher, so on resume that watcher can no longer be trusted
    // to fire. Reconnecting re-establishes a live socket; if the bridge is still
    // offline the attempt lands back in ConnectionBridgeOffline (a successful
    // bridge-absent connect, not a failure), so this no longer risks dropping
    // into the blocking ConnectionLost state the way it would have before the
    // bridge-absent connect path existed.
    final connectionLikelyStale =
        (status is ConnectionConnected || status is ConnectionBridgeOffline) &&
        backgroundedFor >= _resumeReconnectThreshold;

    final needsReconnect = status is ConnectionLost || status is ConnectionReconnecting || connectionLikelyStale;
    if (!needsReconnect) return;

    logd("App resumed — triggering reconnect (status=${status.runtimeType}, backgrounded=$backgroundedFor)");
    // Detach the likely-dead socket immediately so requests fired right after
    // foregrounding fail fast instead of routing through the zombie connection
    // while the replacement socket is being established.
    unawaited(_disconnectRelayClient());
    _relayReconnectBackoff = const Duration(seconds: 1);
    _status.add(ConnectionStatus.reconnecting(config: config));
    // Resume is user-visible and the prior socket is already dead, so attempt
    // the first reconnect immediately; backoff still applies to later retries.
    unawaited(_reconnectRelayWithRefresh(config, immediate: true));
  }

  void _onRelayConnectionDrop() {
    final config = activeConfig;
    if (config == null) return;
    if (_status.value is ConnectionDisconnected) return;

    if (_isInBackground) {
      logd("App is backgrounded — deferring reconnect to foreground resume");
      unawaited(_disconnectRelayClient());
      _status.add(ConnectionStatus.connectionLost(config: config));
      return;
    }

    final closeCode = _relayClient?.lastCloseCode;

    if (!RelayCloseCodes.shouldReconnect(closeCode)) {
      final isAuthCode = closeCode == RelayCloseCodes.authFailure || closeCode == RelayCloseCodes.authRequired;
      if (isAuthCode && _authRetryCount < 1) {
        _authRetryCount++;
        logd("Auth close code $closeCode - attempting token refresh (attempt $_authRetryCount)");
        unawaited(_disconnectRelayClient());
        _status.add(ConnectionStatus.reconnecting(config: config));
        unawaited(_reconnectRelayWithRefresh(config));
        return;
      }

      if (closeCode == RelayCloseCodes.accountFull) {
        logw("Relay closed: account full — too many devices connected (4005)");
      } else {
        logw("Relay closed with terminal closeCode=$closeCode, stopping reconnect loop");
      }
      unawaited(_disconnectRelayClient());
      _status.add(ConnectionStatus.connectionLost(config: config));
      return;
    }

    unawaited(_disconnectRelayClient());
    _status.add(ConnectionStatus.reconnecting(config: config));

    unawaited(_reconnectRelayWithRefresh(config));
  }

  /// Reconnects to relay after refreshing the auth token.
  ///
  /// When [immediate] is true the pre-attempt backoff delay is skipped for this
  /// first attempt. It is used on foreground resume, where the user is waiting
  /// and the previous socket is already known-dead, so the artificial ~1s wait
  /// would be pure latency. The exponential backoff + jitter still applies to
  /// every retry that follows a *failed* attempt (a failure doubles
  /// [_relayReconnectBackoff]), so a genuinely unreachable bridge is never
  /// hammered.
  Future<void> _reconnectRelayWithRefresh(
    ServerConnectionConfig config, {
    bool immediate = false,
  }) async {
    if (_isInBackground) {
      logd("App is backgrounded — skipping reconnect attempt");
      _status.add(ConnectionStatus.connectionLost(config: config));
      return;
    }
    if (_status.value is ConnectionDisconnected) return;

    // Each reconnect attempt claims a generation id. A newer attempt (another
    // drop, resume, or manual reconnect) bumps the id, so any older attempt that
    // wakes from an await boundary below sees it has been superseded and bails —
    // keeping two attempts from opening relay sockets concurrently.
    final attemptId = ++_reconnectAttemptId;

    void handleFailure({required int? closeCode}) {
      if (attemptId != _reconnectAttemptId) return;
      if (_isInBackground) {
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }
      if (_status.value is ConnectionDisconnected) return;
      if (!RelayCloseCodes.shouldReconnect(closeCode)) {
        logw("Relay reconnect stopped by terminal closeCode=$closeCode");
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }

      _relayReconnectBackoff = Duration(
        milliseconds: min(
          _relayReconnectBackoff.inMilliseconds * 2,
          _maxRelayReconnectBackoff.inMilliseconds,
        ),
      );
      logw("Relay reconnect failed; retrying automatically");
      _status.add(ConnectionStatus.reconnecting(config: config));
      unawaited(_reconnectRelayWithRefresh(config));
    }

    if (!immediate) {
      final backoff = _relayReconnectBackoff;
      final jitter = (backoff.inMilliseconds * 0.25 * (Random().nextDouble() * 2 - 1)).round();
      final delayMs = backoff.inMilliseconds + jitter;

      logd("Relay reconnect: waiting ${delayMs}ms before attempt to ${config.relayHost}");
      _reconnectTimer?.cancel();
      final completer = Completer<void>();
      _reconnectDelayCompleter = completer;
      _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      if (identical(_reconnectDelayCompleter, completer)) {
        _reconnectTimer = null;
        _reconnectDelayCompleter = null;
      }
      if (attemptId != _reconnectAttemptId) return;
      if (_isInBackground) {
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }
      if (_status.value is ConnectionDisconnected) return;
    } else {
      logd("Relay reconnect: immediate first attempt to ${config.relayHost}");
    }

    logd("Relay reconnect: refreshing token and reconnecting to ${config.relayHost}");

    try {
      final authToken = await _authTokenProvider.getFreshAccessToken(
        minTtl: const Duration(minutes: 2),
      );

      if (attemptId != _reconnectAttemptId) return;
      if (_isInBackground) {
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }
      if (_status.value is ConnectionDisconnected) return;

      if (authToken == null) {
        logw("Relay reconnect skipped: no valid auth token");
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }

      final freshConfig = ServerConnectionConfig(
        relayHost: config.relayHost,
        authToken: authToken,
      );

      final connectResult = await _connectViaRelay(
        freshConfig,
        isStale: () => attemptId != _reconnectAttemptId || _status.value is ConnectionDisconnected || _isInBackground,
      );

      // A newer attempt or a disconnect during connect means that owner is now
      // responsible for the resulting state — don't clobber it with our outcome.
      if (attemptId != _reconnectAttemptId) return;
      if (_isInBackground) {
        _status.add(ConnectionStatus.connectionLost(config: config));
        return;
      }
      if (_status.value is ConnectionDisconnected) return;

      if (connectResult.response is ErrorResponse<HealthResponse>) {
        handleFailure(closeCode: connectResult.closeCode);
      }
    } catch (error, stackTrace) {
      loge("Relay reconnect attempt failed unexpectedly", error, stackTrace);
      handleFailure(closeCode: null);
    }
  }

  String _nextRelayRequestId() {
    _requestCounter = (_requestCounter + 1) & 0xFFFF;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final counter = _requestCounter.toRadixString(16).padLeft(4, "0");
    final random = _requestIdRandom.nextInt(0x10000).toRadixString(16).padLeft(4, "0");
    return "$timestamp-$counter$random";
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void dispose() {
    _reconnectTimer?.cancel();
    if (_reconnectDelayCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    _status.add(const ConnectionStatus.disconnected());
    unawaited(_disconnectRelayClient());
    _compositeSubscription.dispose();
    _dataMayBeStale.close();
    _events.close();
    _status.close();
  }
}
