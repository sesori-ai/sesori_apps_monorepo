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
import "api_paths.dart";
import "models/connection_status.dart";
import "models/sse_event.dart";
import "server_connection_config.dart";

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
  final DateTime Function() _clock;
  final RelayClientFactory _relayClientFactory;

  final BehaviorSubject<ConnectionStatus> _status = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
  final StreamController<SseEvent> _events = StreamController<SseEvent>.broadcast();
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  final _compositeSubscription = CompositeSubscription();

  RelayClient? _relayClient;
  StreamSubscription<RelaySseEvent>? _relaySseSubscription;
  StreamSubscription<BridgeStatus>? _bridgeStatusSubscription;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectDelayCompleter;
  int _requestCounter = 0;
  final Random _requestIdRandom = Random();
  int _authRetryCount = 0;
  Duration _relayReconnectBackoff = const Duration(seconds: 1);
  bool _isInBackground = false;
  DateTime? _backgroundedAt;

  static const _maxRelayReconnectBackoff = Duration(seconds: 30);

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
    @visibleForTesting DateTime Function() clock = DateTime.now,
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
            _onAppBackgrounded();
          case .paused:
            break;
          case .detached:
            break;
        }
      }),
    );
    _compositeSubscription.add(
      _authSession.authStateStream.listen((state) {
        if (state is! AuthUnauthenticated) return;
        disconnect();
        unawaited(
          _roomKeyStorage.clearRoomKey().catchError((Object error, StackTrace stackTrace) {
            loge("Failed to clear room key after logout", error, stackTrace);
          }),
        );
      }),
    );
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

  /// Connects to the server. Health-checks first, then opens SSE stream
  /// for ongoing heartbeat monitoring.
  Future<ApiResponse<HealthResponse>> connect(
    ServerConnectionConfig config,
  ) => _connectViaRelay(config);

  Future<ApiResponse<HealthResponse>> _connectViaRelay(ServerConnectionConfig config) async {
    await _disconnectRelayClient();

    final relayClient = _relayClientFactory.call(
      relayHost: config.relayHost,
      cryptoService: _cryptoService,
      roomKeyStorage: _roomKeyStorage,
      authToken: config.authToken,
    );

    try {
      await relayClient.connect();

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
        await relayClient.disconnect();
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.status,
            rawErrorString: response.body,
          ),
        );
      }

      final responseBody = response.body;
      if (responseBody == null) {
        throw const FormatException("Health response body is null");
      }
      // ignore: no_slop_linter/avoid_dynamic_type, JSON decode requires dynamic values
      final json = jsonDecode(responseBody);
      if (json is! Map<String, Object?>) {
        throw const FormatException("Health response is not a JSON object");
      }
      final health = HealthResponse.fromJson(json);
      if (!health.healthy) {
        await relayClient.disconnect();
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: 503,
            rawErrorString: response.body,
          ),
        );
      }

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
        return ApiResponse.error(ApiError.generic());
      }
      _status.add(ConnectionStatus.connected(config: config, health: health));
      return ApiResponse.success(health);
    } catch (error, stackTrace) {
      loge("Failed to connect via relay", error, stackTrace);
      try {
        await relayClient.disconnect().timeout(const Duration(seconds: 3));
      } catch (disconnectError, disconnectStackTrace) {
        logw("Best-effort relay disconnect failed after connect error: ${disconnectError.toString()}");
        loge("Relay disconnect cleanup failed", disconnectError, disconnectStackTrace);
      }
      return ApiResponse.error(ApiError.generic());
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

    _status.add(ConnectionStatus.reconnecting(config: config));
    unawaited(_reconnectRelayWithRefresh(config));
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
              unawaited(_reconnectRelayWithRefresh(config));
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

  void _onSseData(String rawData) {
    if (rawData.isEmpty) return;

    try {
      // ignore: no_slop_linter/avoid_dynamic_type, JSON decode requires dynamic values
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, Object?>) return;

      final payloadValue = decoded["payload"];
      if (payloadValue is! Map<String, Object?>) return;

      final typeValue = payloadValue["type"];
      if (typeValue is! String) return;

      final propertiesValue = payloadValue["properties"];
      final properties = propertiesValue is Map<String, Object?> ? propertiesValue : <String, Object?>{};
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

  Future<void> _disconnectRelayClient() async {
    await _relaySseSubscription?.cancel();
    _relaySseSubscription = null;

    await _bridgeStatusSubscription?.cancel();
    _bridgeStatusSubscription = null;

    final relayClient = _relayClient;
    _relayClient = null;
    if (relayClient == null) {
      return;
    }

    try {
      await relayClient.disconnect();
    } catch (error, stackTrace) {
      loge("Failed to disconnect relay client", error, stackTrace);
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
    if (backgroundedAt != null) {
      final elapsed = _clock().difference(backgroundedAt);
      if (elapsed >= staleThreshold && activeConfig != null) {
        logd("App was backgrounded for $elapsed — emitting stale reconnect signal");
        _dataMayBeStale.add(null);
      }
    }

    final status = _status.value;
    final config = activeConfig;
    if (config == null) return;

    final needsReconnect = status is ConnectionLost || status is ConnectionReconnecting;
    if (!needsReconnect) return;

    logd("App resumed with lost connection — triggering reconnect");
    _relayReconnectBackoff = const Duration(seconds: 1);
    _status.add(ConnectionStatus.reconnecting(config: config));
    unawaited(_reconnectRelayWithRefresh(config));
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
  Future<void> _reconnectRelayWithRefresh(ServerConnectionConfig config) async {
    if (_isInBackground) {
      logd("App is backgrounded — skipping reconnect attempt");
      _status.add(ConnectionStatus.connectionLost(config: config));
      return;
    }
    if (_status.value is ConnectionDisconnected) return;

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
    _reconnectTimer = null;
    _reconnectDelayCompleter = null;
    if (_isInBackground) {
      _status.add(ConnectionStatus.connectionLost(config: config));
      return;
    }
    if (_status.value is ConnectionDisconnected) return;

    logd("Relay reconnect: refreshing token and reconnecting to ${config.relayHost}");

    try {
      final authToken = await _authTokenProvider.getFreshAccessToken(
        minTtl: const Duration(minutes: 2),
      );

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

      final result = await _connectViaRelay(freshConfig);

      if (_status.value is ConnectionDisconnected) return;

      if (result is ErrorResponse<HealthResponse>) {
        logw("Relay reconnect failed; marking connection as lost");
        _relayReconnectBackoff = Duration(
          milliseconds: min(
            _relayReconnectBackoff.inMilliseconds * 2,
            _maxRelayReconnectBackoff.inMilliseconds,
          ),
        );
        _status.add(ConnectionStatus.connectionLost(config: config));
      }
    } catch (error, stackTrace) {
      loge("Relay reconnect attempt failed unexpectedly", error, stackTrace);
      if (_status.value is ConnectionDisconnected) return;
      _relayReconnectBackoff = Duration(
        milliseconds: min(
          _relayReconnectBackoff.inMilliseconds * 2,
          _maxRelayReconnectBackoff.inMilliseconds,
        ),
      );
      _status.add(ConnectionStatus.connectionLost(config: config));
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
