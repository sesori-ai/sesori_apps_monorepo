import "dart:async";
import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../auth/access_token_provider.dart";
import "../auth/bridge_registration_service.dart";
import "../auth/token_refresher.dart";
import "../push/completion_push_listener.dart";
import "../push/maintenance_push_listener.dart";
import "../push/push_dispatcher.dart";
import "../server/services/bridge_restart_service.dart";
import "foundation/process_runner.dart";
import "key_exchange.dart";
import "metadata_service.dart";
import "models/bridge_config.dart";
import "relay_client.dart";
import "repositories/agent_repository.dart";
import "repositories/filesystem_repository.dart";
import "repositories/health_repository.dart";
import "repositories/permission_repository.dart";
import "repositories/project_repository.dart";
import "repositories/provider_repository.dart";
import "repositories/question_repository.dart";
import "repositories/session_repository.dart";
import "routing/abort_session_handler.dart";
import "routing/get_commands_handler.dart";
import "routing/get_session_diffs_handler.dart";
import "routing/request_router.dart";
import "routing/send_prompt_handler.dart";
import "services/pr_sync_service.dart";
import "services/project_initialization_service.dart";
import "services/session_abort_service.dart";
import "services/session_archive_service.dart";
import "services/session_creation_service.dart";
import "services/session_event_enrichment_service.dart";
import "services/session_persistence_service.dart";
import "services/session_prompt_service.dart";
import "services/worktree_service.dart";
import "sse/bridge_event_mapper.dart";
import "sse/sse_manager.dart";

/// Factory that creates [OrchestratorSession] instances with all runtime
/// dependencies (room key, SSE manager) properly initialized.
class Orchestrator {
  final BridgeConfig config;
  final RelayClient _client;
  final BridgePluginApi _plugin;
  final MetadataService _metadataService;
  final PushDispatcher _pushDispatcher;
  final CompletionPushListener _completionListener;
  final MaintenancePushListener _maintenanceListener;
  final AccessTokenProvider _accessTokenProvider;
  final TokenRefresher _tokenRefresher;
  final BridgeRegistrationService _bridgeRegistrationService;
  final FailureReporter _failureReporter;
  final PrSyncService _prSyncService;
  final SessionRepository _sessionRepository;
  final ProjectRepository _projectRepository;
  final FilesystemRepository _filesystemRepository;
  final ProjectInitializationService _projectInitializationService;
  final HealthRepository _healthRepository;
  final ProviderRepository _providerRepository;
  final AgentRepository _agentRepository;
  final PermissionRepository _permissionRepository;
  final QuestionRepository _questionRepository;
  final SessionPersistenceService _sessionPersistenceService;
  final WorktreeService _worktreeService;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;
  final BridgeRestartService _restartService;

  Orchestrator({
    required this.config,
    required RelayClient client,
    required BridgePluginApi plugin,
    required MetadataService metadataService,
    required PushDispatcher pushDispatcher,
    required CompletionPushListener completionListener,
    required MaintenancePushListener maintenanceListener,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required FailureReporter failureReporter,
    required PrSyncService prSyncService,
    required SessionRepository sessionRepository,
    required ProjectRepository projectRepository,
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required HealthRepository healthRepository,
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
    required PermissionRepository permissionRepository,
    required QuestionRepository questionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
    required BridgeRestartService restartService,
  }) : _client = client,
       _plugin = plugin,
       _metadataService = metadataService,
       _pushDispatcher = pushDispatcher,
       _completionListener = completionListener,
       _maintenanceListener = maintenanceListener,
       _accessTokenProvider = accessTokenProvider,
       _tokenRefresher = tokenRefresher,
       _bridgeRegistrationService = bridgeRegistrationService,
       _failureReporter = failureReporter,
       _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       _projectRepository = projectRepository,
       _filesystemRepository = filesystemRepository,
       _projectInitializationService = projectInitializationService,
       _healthRepository = healthRepository,
       _providerRepository = providerRepository,
       _agentRepository = agentRepository,
       _permissionRepository = permissionRepository,
       _questionRepository = questionRepository,
       _sessionPersistenceService = sessionPersistenceService,
       _worktreeService = worktreeService,
       _sessionEventEnrichmentService = sessionEventEnrichmentService,
       _restartService = restartService;

  /// Creates a new session with a fresh room key and SSE manager.
  OrchestratorSession create() {
    final roomKey = _generateRoomKey();
    final bytesSentController = StreamController<int>.broadcast();
    final sessionCreationService = SessionCreationService(
      metadataService: _metadataService,
      worktreeService: _worktreeService,
      sessionRepository: _sessionRepository,
    );
    final sessionArchiveService = SessionArchiveService(
      worktreeService: _worktreeService,
      sessionRepository: _sessionRepository,
      sessionPersistenceService: _sessionPersistenceService,
    );
    final sessionAbortService = SessionAbortService(sessionRepository: _sessionRepository);
    final sseManager = SSEManager(
      replayWindow: config.sseReplayWindow,
      onBytesSent: bytesSentController.add,
      failureReporter: _failureReporter,
    );
    sseManager.setRoomKey(roomKey);

    return OrchestratorSession._(
      config: config,
      client: _client,
      plugin: _plugin,
      pushDispatcher: _pushDispatcher,
      completionListener: _completionListener,
      maintenanceListener: _maintenanceListener,
      accessTokenProvider: _accessTokenProvider,
      tokenRefresher: _tokenRefresher,
      bridgeRegistrationService: _bridgeRegistrationService,
      roomKey: roomKey,
      sseManager: sseManager,
      bytesSentController: bytesSentController,
      failureReporter: _failureReporter,
      sessionRepository: _sessionRepository,
      prSyncService: _prSyncService,
      projectRepository: _projectRepository,
      filesystemRepository: _filesystemRepository,
      projectInitializationService: _projectInitializationService,
      healthRepository: _healthRepository,
      providerRepository: _providerRepository,
      agentRepository: _agentRepository,
      permissionRepository: _permissionRepository,
      questionRepository: _questionRepository,
      sessionPersistenceService: _sessionPersistenceService,
      worktreeService: _worktreeService,
      sessionCreationService: sessionCreationService,
      sessionArchiveService: sessionArchiveService,
      sessionAbortService: sessionAbortService,
      sessionEventEnrichmentService: _sessionEventEnrichmentService,
      restartService: _restartService,
    );
  }

  static List<int> _generateRoomKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }
}

/// A running bridge session with immutable runtime state.
///
/// Created by [Orchestrator.create]. Call [run] to start the relay loop
/// and [cancel] to shut down gracefully.
class OrchestratorSession {
  final BridgeConfig config;
  final RelayClient _client;
  final BridgePluginApi _plugin;
  final List<int> _roomKey;
  final SSEManager _sseManager;
  final RequestRouter _router;
  final BridgeEventMapper _mapper;
  final PushDispatcher _pushDispatcher;
  final CompletionPushListener _completionListener;
  final MaintenancePushListener _maintenanceListener;
  final AccessTokenProvider _accessTokenProvider;
  final TokenRefresher _tokenRefresher;
  final BridgeRegistrationService _bridgeRegistrationService;
  final StreamController<int> _bytesSentController;
  final FailureReporter _failureReporter;
  final PrSyncService _prSyncService;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;
  final SessionAbortService _sessionAbortService;
  final BridgeRestartService _restartService;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  bool _cancelled = false;

  /// Guards [handleRestartHandoff] so concurrent relay + debug restart triggers
  /// spawn at most one successor.
  bool _restartHandoffStarted = false;

  /// When the first [cancel] was requested. Used only for shutdown timing
  /// diagnostics (the logger emits no timestamps, so durations are explicit).
  DateTime? _cancelRequestedAt;

  /// Label ("METHOD path") of the relay request currently being routed, or
  /// `null` when the read loop is idle. Surfaces which in-flight request is
  /// blocking the read loop when a shutdown is requested mid-route.
  String? _inFlightRequestLabel;

  /// Completes when [cancel] is first called. Allows in-flight request routing
  /// to abandon a response instead of awaiting an OpenCode HTTP call that has
  /// outlived the relay session.
  final Completer<void> _shutdownCompleter = Completer<void>();

  OrchestratorSession._({
    required this.config,
    required RelayClient client,
    required BridgePluginApi plugin,
    required PushDispatcher pushDispatcher,
    required CompletionPushListener completionListener,
    required MaintenancePushListener maintenanceListener,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required List<int> roomKey,
    required SSEManager sseManager,
    required StreamController<int> bytesSentController,
    required FailureReporter failureReporter,
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required HealthRepository healthRepository,
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
    required PermissionRepository permissionRepository,
    required QuestionRepository questionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required SessionAbortService sessionAbortService,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
    required BridgeRestartService restartService,
  }) : _client = client,
       _plugin = plugin,
       _pushDispatcher = pushDispatcher,
       _completionListener = completionListener,
       _maintenanceListener = maintenanceListener,
       _accessTokenProvider = accessTokenProvider,
       _tokenRefresher = tokenRefresher,
       _bridgeRegistrationService = bridgeRegistrationService,
       _roomKey = roomKey,
       _sseManager = sseManager,
       _bytesSentController = bytesSentController,
       _failureReporter = failureReporter,
       _prSyncService = prSyncService,
       _sessionAbortService = sessionAbortService,
       _restartService = restartService,
       _router = RequestRouter(
         plugin: plugin,
         getCommandsHandler: GetCommandsHandler(
           sessionRepository: sessionRepository,
         ),
         sessionRepository: sessionRepository,
         abortSessionHandler: AbortSessionHandler(sessionAbortService: sessionAbortService),
         sessionCreationService: sessionCreationService,
         sessionArchiveService: sessionArchiveService,
         sendPromptHandler: SendPromptHandler(
           sessionPromptService: SessionPromptService(
             sessionRepository: sessionRepository,
             sseManager: sseManager,
           ),
         ),
          prSyncService: prSyncService,
          projectRepository: projectRepository,
          filesystemRepository: filesystemRepository,
          projectInitializationService: projectInitializationService,
          healthRepository: healthRepository,
          providerRepository: providerRepository,
          agentRepository: agentRepository,
          permissionRepository: permissionRepository,
         questionRepository: questionRepository,
         sessionPersistenceService: sessionPersistenceService,
         worktreeService: worktreeService,
         sessionDiffsHandler: GetSessionDiffsHandler(
           sessionRepository: sessionRepository,
           processRunner: ProcessRunner(),
         ),
         restartService: restartService,
       ),
       _mapper = BridgeEventMapper(
         plugin: plugin,
         failureReporter: failureReporter,
       ),
       _sessionEventEnrichmentService = sessionEventEnrichmentService;

  /// Broadcast stream of byte counts emitted each time data is sent to a phone.
  ///
  /// Includes both API responses and SSE events. Subscribe to this stream to
  /// track bandwidth (e.g. with [BandwidthTracker]).
  Stream<int> get bytesSent => _bytesSentController.stream;
  RequestRouter get router => _router;

  Future<void> run() async {
    final kxManager = KeyExchangeManager(_roomKey);
    final activePhones = <int, bool>{};

    Log.d("registering bridge with auth server...");
    await _bridgeRegistrationService.ensureRegistered();
    Log.d("bridge registered");

    try {
      Log.d("connecting to relay...");
      await _client.connect();
      Log.d("relay connected");

      _sessionAbortService.abortStartedSessions
          .listen(_completionListener.markSessionAbortPending)
          .addTo(_subscriptions);
      _sessionAbortService.abortedSessions.listen(_completionListener.markSessionAborted).addTo(_subscriptions);
      _sessionAbortService.abortFailedSessions.listen(_completionListener.clearPendingAbort).addTo(_subscriptions);
      _completionListener.start();
      _maintenanceListener.start();

      final startupSummary = _mapper.buildProjectsSummaryEvent();
      if (startupSummary != null) {
        _completionListener.handleSseEvent(startupSummary);
      }

      Log.d("subscribing to plugin event stream...");
      _plugin.events
          .asyncMap<BridgeSseEvent>(_sessionEventEnrichmentService.enrich)
          .listen(
            (event) {
              unawaited(_processPluginEvent(event));
            },
            onError: (Object e, StackTrace st) {
              Log.w("plugin event stream error: $e");
              unawaited(
                _failureReporter.recordFailure(
                  error: e,
                  stackTrace: st,
                  uniqueIdentifier: "bridge.plugin.events",
                  fatal: false,
                  reason: "plugin event stream failure",
                  information: const [],
                ),
              );
            },
            onDone: () {
              Log.w("plugin event stream closed");
            },
          )
          .addTo(_subscriptions);
      Log.d("plugin event stream subscribed");
      _prSyncService.prChanges
          .listen((String projectId) {
            _sseManager.enqueueEvent(SesoriSseEvent.sessionsUpdated(projectID: projectId));
          })
          .addTo(_subscriptions);

      // Live re-auth: when the token provider emits a token that differs from the
      // one the relay socket is actually authenticated with (supervised mode, the
      // GUI pushed a token_update), the open WebSocket is still on the previous
      // JWT. Drop the relay so the reconnect loop below re-authenticates on the
      // fresh token — the same path a relay-side disconnect drives, so both
      // triggers stay symmetric.
      //
      // Compare against the token the socket actually used for auth
      // ([RelayClient.lastAuthedToken]) rather than skipping the BehaviorSubject's
      // replayed value. This (a) ignores routine unchanged pulls (e.g. metadata
      // generation) so they don't needlessly drop a live connection, (b) breaks
      // the feedback loop where the reconnect path's own force-pull re-emits the
      // token it just authenticated with, and (c) still re-auths for a push that
      // landed in the gap between connect() and this subscription, since that
      // pushed token differs from the one connect() sent.
      _accessTokenProvider.tokenStream
          .where((token) => token != _client.lastAuthedToken)
          .listen((token) => unawaited(_reauthenticateRelay()))
          .addTo(_subscriptions);
    } catch (e) {
      throw Exception("failed to connect to relay: $e");
    }

    Console.message("Relay:  ${config.relayURL}");
    Console.message("Target: ${config.pluginEndpoint}\n");
    Console.message("Waiting for relay events...");

    try {
      while (!_cancelled) {
        try {
          await _runRelayLoop(_roomKey, kxManager, activePhones);
        } catch (e) {
          if (_cancelled) break;
          Log.w("relay loop ended: $e");
        }

        if (_cancelled) {
          break;
        }

        Log.w("Relay connection lost. Reconnecting...");
        _sseManager.orphanAll();
        activePhones.clear();

        if (_client.closeCode == RelayCloseCodes.bridgeRevoked) {
          Log.w("Relay reports this bridge as revoked — re-registering with a fresh bridge id");
          await _bridgeRegistrationService.handleBridgeRevoked();
        }

        var backoff = const Duration(seconds: 1);
        while (!_cancelled) {
          await Future<void>.delayed(backoff);
          if (_cancelled) {
            return;
          }

          // Don't reconnect without a usable token: in supervised mode a
          // signed-out / mid-login GUI yields no token, and reconnecting would
          // re-authenticate the relay from a stale cached token. Back off and
          // retry — a later refresh (or a token_update push) recovers.
          if (!await _refreshAccessToken()) {
            Log.w("No access token available — deferring reconnect (retrying in $backoff)");
            backoff = _nextBackoff(backoff);
            continue;
          }

          try {
            await _bridgeRegistrationService.ensureRegistered();
            await _client.reconnect();
          } catch (e) {
            Log.w("Reconnect failed: $e (retrying in $backoff)");
            backoff = _nextBackoff(backoff);
            continue;
          }

          backoff = const Duration(seconds: 1);
          Log.i("Reconnected to relay");
          break;
        }
      }
    } finally {
      final teardownSw = Stopwatch()..start();
      final sinceCancelMs = _cancelRequestedAt == null
          ? null
          : DateTime.now().difference(_cancelRequestedAt!).inMilliseconds;
      Log.i("Disconnecting...");
      Log.d(
        "[shutdown] session teardown begin "
        "(${sinceCancelMs == null ? "no cancel timestamp" : "${sinceCancelMs}ms since cancel()"}"
        "${_inFlightRequestLabel == null ? "" : ", in-flight request: $_inFlightRequestLabel"})",
      );
      await _subscriptions.cancel();
      Log.v("[shutdown] subscriptions cancelled (+${teardownSw.elapsedMilliseconds}ms)");
      await _sessionAbortService.dispose();
      Log.v("[shutdown] session abort service disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await _completionListener.dispose();
      Log.v("[shutdown] completion listener disposed (+${teardownSw.elapsedMilliseconds}ms)");
      _maintenanceListener.dispose();
      _prSyncService.dispose();
      Log.v("[shutdown] maintenance + pr-sync listeners disposed (+${teardownSw.elapsedMilliseconds}ms)");
      // Plugin teardown is owned by BridgePlugin.shutdown(), run as the
      // shutdown coordinator's ordered step — the deprecated direct
      // api.dispose() call is gone since the descriptor flip.
      Log.v("stopping sse manager...");
      _sseManager.stop();
      Log.v("sse manager stopped (+${teardownSw.elapsedMilliseconds}ms)");
      Log.v("disposing push notification service...");
      await _pushDispatcher.dispose();
      Log.v("push notification service disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await _bytesSentController.close();
      try {
        Log.v("closing relay client...");
        await _client.close();
        Log.v("relay client closed (+${teardownSw.elapsedMilliseconds}ms)");
      } catch (e) {
        Log.e("error closing relay connection: $e");
      }
      Log.d("[shutdown] session teardown complete (${teardownSw.elapsedMilliseconds}ms total)");
    }
  }

  Future<void> cancel() async {
    if (_cancelRequestedAt == null) {
      _cancelRequestedAt = DateTime.now();
      Log.d(
        "[shutdown] cancel() requested"
        "${_inFlightRequestLabel == null ? "" : " — in-flight request: $_inFlightRequestLabel"}",
      );
    } else {
      Log.v("[shutdown] cancel() again (already shutting down)");
    }
    _cancelled = true;
    if (!_shutdownCompleter.isCompleted) {
      _shutdownCompleter.complete();
    }
    final sw = Stopwatch()..start();
    await _client.close();
    Log.d("[shutdown] cancel(): relay client closed in ${sw.elapsedMilliseconds}ms");
    // Fire-and-forget: closing the plugin's HTTP client is the only way to
    // unblock an in-flight OpenCode request that the read loop is awaiting.
    // Idempotent disposal still runs through the shutdown coordinator later;
    // this call just makes it happen early enough to prevent a 15–30s hang.
    // Future.sync so a synchronously-throwing dispose() (e.g. a test fake) is
    // captured by catchError instead of escaping this method.
    unawaited(
      Future.sync(_plugin.dispose).catchError((Object e) {
        Log.v("[shutdown] early plugin dispose error (ignored): $e");
      }),
    );
  }

  /// Performs the restart handoff after the `{restarting:true}` reply has been
  /// enqueued: spawns the successor, then drives the normal graceful shutdown
  /// ([cancel]) — which flushes the queued reply by closing the relay and lets
  /// this process exit. The successor waits for this pid to exit before it
  /// enforces single-live-bridge, so the handoff is clean.
  ///
  /// Public because both restart triggers drive the same handoff: the relay
  /// request loop (below) and the local [DebugServer], which reuses this
  /// session's [RequestRouter] and so reaches the same `RestartBridgeHandler`.
  Future<void> handleRestartHandoff() async {
    // Single-flight: the relay and debug-server triggers share the same restart
    // flag but run independently, so without this guard two near-simultaneous
    // `POST /global/restart` requests could each spawn a successor. The flag is
    // set synchronously (no await before it), so the check-and-set is atomic on
    // the event loop. It is reset only when the spawn fails and we keep running,
    // so a later restart can retry.
    if (_restartHandoffStarted) {
      Log.v("[restart] handoff already in progress; ignoring duplicate trigger");
      return;
    }
    _restartHandoffStarted = true;
    Log.i("[restart] restart requested; spawning successor bridge");
    final bool spawned = await _restartService.spawnSuccessor();
    if (!spawned) {
      _restartHandoffStarted = false;
      Console.error(
        "Restart requested but a new bridge could not be started; continuing to run. "
        "Re-run the install script if this persists: https://sesori.com/",
      );
      return;
    }
    Log.i("[restart] successor spawned; shutting down for handoff");
    await cancel();
  }

  Future<void> _processPluginEvent(BridgeSseEvent event) async {
    try {
      Log.v("[sse] plugin event arrived: ${event.runtimeType}");
      final sesoriEvent = _mapper.map(event);
      if (sesoriEvent != null) {
        Log.v(
          "[sse] mapped to: ${sesoriEvent.runtimeType} — enqueuing (subscribers: ${_sseManager.subscriberCount})",
        );
        _completionListener.handleSseEvent(sesoriEvent);
        _sseManager.enqueueEvent(sesoriEvent);
      } else {
        Log.v("[sse] mapping returned null — event dropped");
      }
    } catch (e, st) {
      Log.e("[sse] error processing event ${event.runtimeType}: $e\n$st");
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_event_processing:${event.runtimeType}",
              fatal: false,
              reason: "Failed to process SSE event",
              information: [event.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  /// Force-refreshes the access token before a relay reconnect. Returns whether
  /// the reconnect may proceed.
  ///
  /// Returns `false` only when the token is genuinely unavailable
  /// ([ControlTokenUnavailableException] — in supervised mode the GUI reported
  /// signed-out / mid-login, and the service has invalidated its cache): the
  /// caller MUST NOT reconnect, because there is no safe token to authenticate
  /// with. Any other refresh failure (e.g. standalone [TokenManager] hitting a
  /// transiently-down auth-refresh endpoint) returns `true` so the reconnect
  /// still proceeds with the existing, possibly-still-valid cached token —
  /// preserving the pre-existing standalone resilience.
  Future<bool> _refreshAccessToken() async {
    try {
      await _tokenRefresher.getAccessToken(forceRefresh: true);
      Log.i("Access token refreshed successfully");
      return true;
    } on ControlTokenUnavailableException catch (e) {
      Log.w("No access token available for reconnect: $e");
      return false;
    } catch (e) {
      // Transient refresh failure with a cached token still on hand: reconnect
      // with it rather than blocking the relay until refresh recovers.
      Log.w("Token refresh failed; reconnecting with the cached token: $e");
      return true;
    }
  }

  /// Live re-auth trigger: the token provider emitted a fresh token while the
  /// relay was connected, so the open socket is still on the old JWT. Closing the
  /// relay ends the active read loop, after which [run]'s reconnect block force-
  /// pulls the new token and reconnects — the same path a relay-side drop drives.
  /// No-op once cancelled so a token emit during shutdown can't fight teardown.
  Future<void> _reauthenticateRelay() async {
    if (_cancelled) return;
    Log.i("Access token updated while connected — re-authenticating relay");
    try {
      await _client.close();
    } on Object catch (error, stackTrace) {
      // Best-effort: if the close fails the read loop still ends on the broken
      // socket and the reconnect block recovers, so log and continue.
      Log.w("Failed to close relay for token re-auth", error, stackTrace);
    }
  }

  Future<void> _runRelayLoop(
    List<int> roomKey,
    KeyExchangeManager kxManager,
    Map<int, bool> activePhones,
  ) async {
    await for (final msg in _client.read()) {
      if (_cancelled) {
        return;
      }

      Log.v("relay msg: isText=${msg.isText} len=${msg.data.length}");

      if (msg.isText) {
        Map<String, dynamic> control;
        try {
          control = jsonDecodeMap(utf8.decode(msg.data));
        } catch (e) {
          Log.e("failed to parse control message: $e");
          continue;
        }

        final type = control["type"] as String?;
        final connID = control["connId"] as int?;
        Log.v("control: type=$type connID=$connID");
        if (type == null || connID == null) {
          Log.v("dropping control: null type or connID");
          continue;
        }

        switch (type) {
          case "phone_connected":
            Log.v("phone_connected connID=$connID");
            try {
              kxManager.startExchange(connID);
            } catch (e) {
              Log.e("failed to start exchange for connId $connID: $e");
            }
          case "phone_disconnected":
            Log.v("phone_disconnected connID=$connID");
            kxManager.removeExchange(connID);
            activePhones.remove(connID);
            _sseManager.removeSubscriber(connID);
        }
        continue;
      }

      if (msg.data.length < 2) {
        Log.v("binary too short: ${msg.data.length}");
        continue;
      }

      final connID = ByteData.sublistView(msg.data).getUint16(0, Endian.big);
      final payload = msg.data.sublist(2);
      if (payload.isEmpty) {
        Log.v("empty payload for connID=$connID");
        continue;
      }

      Log.v("binary: connID=$connID payloadLen=${payload.length} firstByte=0x${payload[0].toRadixString(16)}");

      if (payload[0] == RelayProtocol.jsonStartByte) {
        Log.v("JSON message (key exchange?)");
        RelayMessage relayMessage;
        try {
          relayMessage = RelayMessage.fromJson(
            jsonDecodeMap(utf8.decode(payload)),
          );
        } catch (e) {
          Log.v("failed to parse relay JSON: $e");
          continue;
        }

        Log.v("parsed: ${relayMessage.runtimeType}");

        if (relayMessage is! RelayKeyExchange) {
          Log.v("not a key exchange, skipping");
          continue;
        }

        List<int> encrypted;
        try {
          encrypted = await kxManager.handleKeyExchange(connID, relayMessage);
          Log.d("key exchange OK, sending ready to connID=$connID");
        } catch (e) {
          Log.e("failed key exchange for connId $connID: $e");
          continue;
        }

        try {
          _client.send(connID, encrypted);
          Log.d("ready sent to connID=$connID");
        } catch (e) {
          if (_cancelled) {
            throw StateError("cancelled");
          }
          throw Exception("send ready for connId $connID: $e");
        }

        activePhones[connID] = true;
        Log.d("phone $connID is now active");
        continue;
      }

      Log.v(
        "checking protocolVersion: payload[0]=0x${payload[0].toRadixString(16)} expected=0x${protocolVersion.toRadixString(16)}",
      );
      if (payload[0] == protocolVersion) {
        final encryptor = RelayCryptoService().createSessionEncryptor(
          SecretKey(List<int>.from(roomKey)),
        );

        List<int>? decrypted;
        Object? decryptError;
        try {
          decrypted = await unframe(payload, encryptor: encryptor);
        } catch (e) {
          decryptError = e;
        }

        if (activePhones[connID] == true) {
          if (decryptError != null || decrypted == null) {
            Log.v(
              "failed to decrypt from connId $connID: $decryptError",
            );
            continue;
          }
          Log.v("decrypted OK from connID=$connID, handling...");
          await _handleDecryptedMessage(connID, decrypted);
          Log.v("handled message from connID=$connID");
          continue;
        }

        if (decryptError != null || decrypted == null) {
          Log.v("not active, decrypt failed for connID=$connID: $decryptError — sending rekeyRequired");
          final rekeyRequired = jsonEncode(
            const RelayMessage.rekeyRequired().toJson(),
          );
          try {
            _client.send(connID, utf8.encode(rekeyRequired));
          } catch (_) {
            if (_cancelled) {
              throw StateError("cancelled");
            }
          }
          continue;
        }

        RelayMessage parsedMessage;
        try {
          parsedMessage = RelayMessage.fromJson(
            jsonDecodeMap(utf8.decode(decrypted)),
          );
        } catch (_) {
          continue;
        }

        if (parsedMessage is! RelayResume) {
          continue;
        }

        final ackJSON = utf8.encode(
          jsonEncode(const RelayMessage.resumeAck().toJson()),
        );
        List<int> encryptedAck;
        try {
          encryptedAck = await frame(ackJSON, encryptor: encryptor);
        } catch (_) {
          continue;
        }

        try {
          _client.send(connID, encryptedAck);
        } catch (e) {
          if (_cancelled) {
            throw StateError("cancelled");
          }
          throw Exception("send resume ack for connId $connID: $e");
        }

        activePhones[connID] = true;
      }
    }
  }

  Future<void> _handleDecryptedMessage(int connID, List<int> decrypted) async {
    RelayMessage msg;
    try {
      msg = RelayMessage.fromJson(
        jsonDecodeMap(utf8.decode(decrypted)),
      );
    } catch (e) {
      Log.v("failed to parse decrypted msg from connID=$connID: $e");
      return;
    }

    Log.v("decrypted msg type: ${msg.runtimeType}");

    switch (msg) {
      case final RelayRequest req:
        Log.v("RelayRequest: ${req.method} ${req.path}");
        _inFlightRequestLabel = "${req.method} ${req.path}";
        final routeSw = Stopwatch()..start();
        // Defensively discard any restart flag left armed before routing this
        // relay request. The local DebugServer reuses this RequestRouter but
        // consumes and acts on its own restart flag synchronously right after it
        // routes, so it should never leak one here; this clear still guarantees
        // that only a restart requested during THIS relay request can trigger a
        // handoff from the relay path.
        _restartService.consumeRestartRequest();
        // If shutdown wins the race below, this future keeps running in the
        // background. ignore() marks any later failure as handled so it can
        // never surface as an unhandled async exception after abandonment.
        final routeFuture = _router.route(req)..ignore();
        try {
          final response = await Future.any<RelayResponse>([
            routeFuture,
            _shutdownCompleter.future.then((_) => throw const _ShutdownInProgressException()),
          ]);
          // Consume the restart flag now — it was set (if at all) by THIS
          // request during routing. Tying consumption to this request means a
          // failed/abandoned response can never leave the flag armed to trigger
          // a delayed, unintended restart on a later request.
          final bool restartRequested = _restartService.consumeRestartRequest();
          if (_cancelled) {
            Log.v(
              "[shutdown] route ${req.method} ${req.path} completed after cancel — "
              "dropping response (status=${response.status})",
            );
            return;
          }
          if (routeSw.elapsedMilliseconds > 1000) {
            Log.d(
              "[shutdown] slow route ${req.method} ${req.path} for connId $connID "
              "took ${routeSw.elapsedMilliseconds}ms (cancelled=$_cancelled)",
            );
          }
          Log.v("response: status=${response.status}");
          await _encryptAndSend(connID: connID, message: response);
          Log.v("response sent to connID=$connID");
          if (restartRequested) {
            await handleRestartHandoff();
          }
        } on _ShutdownInProgressException {
          Log.v(
            "[shutdown] route ${req.method} ${req.path} abandoned because shutdown was requested",
          );
        } catch (e) {
          if (_cancelled) {
            Log.v("[shutdown] route ${req.method} ${req.path} failed during shutdown: $e");
          } else {
            Log.e("request routing failed for connId $connID: $e");
          }
        } finally {
          _inFlightRequestLabel = null;
        }
      case final RelaySseSubscribe subscribe:
        Log.v("SseSubscribe: path=${subscribe.path}");
        try {
          _sseManager.subscribePath(connID, subscribe.path, _client);
          final projSummary = _mapper.buildProjectsSummaryEvent();
          if (projSummary != null) {
            _sseManager.enqueueEvent(projSummary);
            _completionListener.handleSseEvent(projSummary);
          }
          Log.v("initial projectsSummary enqueued");
        } catch (e) {
          Log.e("sse subscribe failed for connId $connID: $e");
        }
      case RelaySseUnsubscribe():
        Log.v("SseUnsubscribe connID=$connID");
        _sseManager.unsubscribe(connID);
      default:
        Log.v("unhandled msg type: ${msg.runtimeType}");
    }
  }

  Duration _nextBackoff(Duration backoff) {
    final next = Duration(microseconds: backoff.inMicroseconds * 2);
    const maxBackoff = Duration(seconds: 30);
    if (next > maxBackoff) {
      return maxBackoff;
    }
    return next;
  }

  Future<void> _encryptAndSend({
    required int connID,
    required RelayMessage message,
  }) async {
    final respJson = jsonEncode(message.toJson());
    final jsonBytes = utf8.encode(respJson);
    Log.v("[response] sending ${jsonBytes.length} bytes to connID=$connID");
    _bytesSentController.add(jsonBytes.length);
    final cryptoService = RelayCryptoService();
    final encryptionKey = SecretKey(List<int>.from(_roomKey));
    final encryptor = cryptoService.createSessionEncryptor(encryptionKey);
    final framed = await frame(jsonBytes, encryptor: encryptor);
    _client.send(connID, framed);
  }
}

/// Thrown when a request is racing against shutdown and shutdown wins.
class _ShutdownInProgressException implements Exception {
  const _ShutdownInProgressException();
}
