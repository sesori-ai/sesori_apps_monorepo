import "dart:async";
import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../auth/token_refresher.dart";
import "../push/completion_push_listener.dart";
import "../push/maintenance_push_listener.dart";
import "../push/push_dispatcher.dart";
import "foundation/process_runner.dart";
import "key_exchange.dart";
import "metadata_service.dart";
import "models/bridge_config.dart";
import "relay_client.dart";
import "repositories/agent_repository.dart";
import "repositories/permission_repository.dart";
import "repositories/project_repository.dart";
import "repositories/provider_repository.dart";
import "repositories/session_repository.dart";
import "routing/abort_session_handler.dart";
import "routing/get_agents_handler.dart";
import "routing/get_commands_handler.dart";
import "routing/get_session_diffs_handler.dart";
import "routing/request_router.dart";
import "routing/send_prompt_handler.dart";
import "services/pr_sync_service.dart";
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
  final BridgePlugin _plugin;
  final MetadataService _metadataService;
  final PushDispatcher _pushDispatcher;
  final CompletionPushListener _completionListener;
  final MaintenancePushListener _maintenanceListener;
  final TokenRefresher _tokenRefresher;
  final FailureReporter _failureReporter;
  final PrSyncService _prSyncService;
  final SessionRepository _sessionRepository;
  final ProjectRepository _projectRepository;
  final PermissionRepository _permissionRepository;
  final SessionPersistenceService _sessionPersistenceService;
  final WorktreeService _worktreeService;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;

  Orchestrator({
    required this.config,
    required RelayClient client,
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required PushDispatcher pushDispatcher,
    required CompletionPushListener completionListener,
    required MaintenancePushListener maintenanceListener,
    required TokenRefresher tokenRefresher,
    required FailureReporter failureReporter,
    required PrSyncService prSyncService,
    required SessionRepository sessionRepository,
    required ProjectRepository projectRepository,
    required PermissionRepository permissionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
  }) : _client = client,
       _plugin = plugin,
       _metadataService = metadataService,
       _pushDispatcher = pushDispatcher,
       _completionListener = completionListener,
       _maintenanceListener = maintenanceListener,
       _tokenRefresher = tokenRefresher,
       _failureReporter = failureReporter,
       _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       _projectRepository = projectRepository,
       _permissionRepository = permissionRepository,
       _sessionPersistenceService = sessionPersistenceService,
       _worktreeService = worktreeService,
       _sessionEventEnrichmentService = sessionEventEnrichmentService;

  /// Creates a new session with a fresh room key and SSE manager.
  OrchestratorSession create() {
    final roomKey = _generateRoomKey();
    final bytesSentController = StreamController<int>.broadcast();
    final sessionCreationService = SessionCreationService(
      metadataService: _metadataService,
      worktreeService: _worktreeService,
      sessionRepository: _sessionRepository,
      sessionPersistenceService: _sessionPersistenceService,
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
      tokenRefresher: _tokenRefresher,
      roomKey: roomKey,
      sseManager: sseManager,
      bytesSentController: bytesSentController,
      failureReporter: _failureReporter,
      sessionRepository: _sessionRepository,
      prSyncService: _prSyncService,
      projectRepository: _projectRepository,
      permissionRepository: _permissionRepository,
      sessionPersistenceService: _sessionPersistenceService,
      worktreeService: _worktreeService,
      sessionCreationService: sessionCreationService,
      sessionArchiveService: sessionArchiveService,
      sessionAbortService: sessionAbortService,
      sessionEventEnrichmentService: _sessionEventEnrichmentService,
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
  final BridgePlugin _plugin;
  final List<int> _roomKey;
  final SSEManager _sseManager;
  final RequestRouter _router;
  final BridgeEventMapper _mapper;
  final PushDispatcher _pushDispatcher;
  final CompletionPushListener _completionListener;
  final MaintenancePushListener _maintenanceListener;
  final TokenRefresher _tokenRefresher;
  final StreamController<int> _bytesSentController;
  final FailureReporter _failureReporter;
  final PrSyncService _prSyncService;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;
  final SessionAbortService _sessionAbortService;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  bool _cancelled = false;

  OrchestratorSession._({
    required this.config,
    required RelayClient client,
    required BridgePlugin plugin,
    required PushDispatcher pushDispatcher,
    required CompletionPushListener completionListener,
    required MaintenancePushListener maintenanceListener,
    required TokenRefresher tokenRefresher,
    required List<int> roomKey,
    required SSEManager sseManager,
    required StreamController<int> bytesSentController,
    required FailureReporter failureReporter,
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    required ProjectRepository projectRepository,
    required PermissionRepository permissionRepository,
    required SessionPersistenceService sessionPersistenceService,
    required WorktreeService worktreeService,
    required SessionCreationService sessionCreationService,
    required SessionArchiveService sessionArchiveService,
    required SessionAbortService sessionAbortService,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
  }) : _client = client,
       _plugin = plugin,
       _pushDispatcher = pushDispatcher,
       _completionListener = completionListener,
       _maintenanceListener = maintenanceListener,
       _tokenRefresher = tokenRefresher,
       _roomKey = roomKey,
       _sseManager = sseManager,
       _bytesSentController = bytesSentController,
       _failureReporter = failureReporter,
       _prSyncService = prSyncService,
        _sessionAbortService = sessionAbortService,
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
             sessionPromptService: SessionPromptService(sessionRepository: sessionRepository),
           ),
           prSyncService: prSyncService,
           projectRepository: projectRepository,
           providerRepository: ProviderRepository(plugin: plugin),
            getAgentsHandler: GetAgentsHandler(
              AgentRepository(plugin: plugin),
            ),
           permissionRepository: permissionRepository,
          sessionPersistenceService: sessionPersistenceService,
          worktreeService: worktreeService,
          sessionDiffsHandler: GetSessionDiffsHandler(
            sessionRepository: sessionRepository,
            processRunner: ProcessRunner(),
          ),
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

    try {
      Log.d("[dbg] connecting to relay...");
      await _client.connect();
      Log.d("[dbg] relay connected");

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

      Log.d("[dbg] subscribing to plugin event stream...");
      _plugin.events
          .asyncMap<BridgeSseEvent>(_sessionEventEnrichmentService.enrich)
          .listen(
            (event) {
              unawaited(_processPluginEvent(event));
            },
            onError: (Object e, StackTrace st) {
              Log.w("[dbg] plugin event stream error: $e");
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
              Log.w("[dbg] plugin event stream closed");
            },
          )
          .addTo(_subscriptions);
      Log.d("[dbg] plugin event stream subscribed");
      _prSyncService.prChanges
          .listen((String projectId) {
            _sseManager.enqueueEvent(SesoriSseEvent.sessionsUpdated(projectID: projectId));
          })
          .addTo(_subscriptions);
    } catch (e) {
      throw Exception("failed to connect to relay: $e");
    }

    Log.i("Relay:  ${config.relayURL}");
    Log.i("Target: ${config.serverURL}\n");
    Log.i("Waiting for relay events...");

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

        var backoff = const Duration(seconds: 1);
        while (!_cancelled) {
          await Future<void>.delayed(backoff);
          if (_cancelled) {
            return;
          }

          await _refreshAccessToken();

          try {
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
      Log.i("Disconnecting...");
      await _subscriptions.cancel();
      await _sessionAbortService.dispose();
      await _completionListener.dispose();
      _maintenanceListener.dispose();
      _prSyncService.dispose();
      Log.d("[dbg] disposing plugin...");
      await _plugin.dispose();
      Log.d("[dbg] plugin disposed");
      Log.d("[dbg] stopping sse manager...");
      _sseManager.stop();
      Log.d("[dbg] sse manager stopped");
      Log.d("[dbg] disposing push notification service...");
      await _pushDispatcher.dispose();
      Log.d("[dbg] push notification service disposed");
      await _bytesSentController.close();
      try {
        Log.d("[dbg] closing relay client...");
        await _client.close();
        Log.d("[dbg] relay client closed");
      } catch (e) {
        Log.e("error closing relay connection: $e");
      }
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    await _client.close();
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

  Future<void> _refreshAccessToken() async {
    try {
      await _tokenRefresher.getAccessToken(forceRefresh: true);
      Log.i("Access token refreshed successfully");
    } catch (e) {
      Log.w("Token refresh failed: $e");
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

      Log.v("[dbg] relay msg: isText=${msg.isText} len=${msg.data.length}");

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
        Log.v("[dbg] control: type=$type connID=$connID");
        if (type == null || connID == null) {
          Log.v("[dbg] dropping control: null type or connID");
          continue;
        }

        switch (type) {
          case "phone_connected":
            Log.v("[dbg] phone_connected connID=$connID");
            try {
              kxManager.startExchange(connID);
            } catch (e) {
              Log.e("failed to start exchange for connId $connID: $e");
            }
          case "phone_disconnected":
            Log.v("[dbg] phone_disconnected connID=$connID");
            kxManager.removeExchange(connID);
            activePhones.remove(connID);
            _sseManager.removeSubscriber(connID);
        }
        continue;
      }

      if (msg.data.length < 2) {
        Log.v("[dbg] binary too short: ${msg.data.length}");
        continue;
      }

      final connID = ByteData.sublistView(msg.data).getUint16(0, Endian.big);
      final payload = msg.data.sublist(2);
      if (payload.isEmpty) {
        Log.v("[dbg] empty payload for connID=$connID");
        continue;
      }

      Log.v("[dbg] binary: connID=$connID payloadLen=${payload.length} firstByte=0x${payload[0].toRadixString(16)}");

      if (payload[0] == RelayProtocol.jsonStartByte) {
        Log.v("[dbg] JSON message (key exchange?)");
        RelayMessage relayMessage;
        try {
          relayMessage = RelayMessage.fromJson(
            jsonDecodeMap(utf8.decode(payload)),
          );
        } catch (e) {
          Log.v("[dbg] failed to parse relay JSON: $e");
          continue;
        }

        Log.v("[dbg] parsed: ${relayMessage.runtimeType}");

        if (relayMessage is! RelayKeyExchange) {
          Log.v("[dbg] not a key exchange, skipping");
          continue;
        }

        List<int> encrypted;
        try {
          encrypted = await kxManager.handleKeyExchange(connID, relayMessage);
          Log.d("[dbg] key exchange OK, sending ready to connID=$connID");
        } catch (e) {
          Log.e("failed key exchange for connId $connID: $e");
          continue;
        }

        try {
          _client.send(connID, encrypted);
          Log.d("[dbg] ready sent to connID=$connID");
        } catch (e) {
          if (_cancelled) {
            throw StateError("cancelled");
          }
          throw Exception("send ready for connId $connID: $e");
        }

        activePhones[connID] = true;
        Log.d("[dbg] phone $connID is now active");
        continue;
      }

      Log.v(
        "[dbg] checking protocolVersion: payload[0]=0x${payload[0].toRadixString(16)} expected=0x${protocolVersion.toRadixString(16)}",
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
              "[dbg] failed to decrypt from connId $connID: $decryptError",
            );
            continue;
          }
          Log.v("[dbg] decrypted OK from connID=$connID, handling...");
          await _handleDecryptedMessage(connID, decrypted);
          Log.v("[dbg] handled message from connID=$connID");
          continue;
        }

        if (decryptError != null || decrypted == null) {
          Log.v("[dbg] not active, decrypt failed for connID=$connID: $decryptError — sending rekeyRequired");
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
      Log.v("[dbg] failed to parse decrypted msg from connID=$connID: $e");
      return;
    }

    Log.v("[dbg] decrypted msg type: ${msg.runtimeType}");

    switch (msg) {
      case final RelayRequest req:
        Log.v("[dbg] RelayRequest: ${req.method} ${req.path}");
        try {
          final response = await _router.route(req);
          Log.v("[dbg] response: status=${response.status}");
          await _encryptAndSend(connID: connID, message: response);
          Log.v("[dbg] response sent to connID=$connID");
        } catch (e) {
          Log.e("request routing failed for connId $connID: $e");
        }
      case final RelaySseSubscribe subscribe:
        Log.v("[dbg] SseSubscribe: path=${subscribe.path}");
        try {
          _sseManager.subscribePath(connID, subscribe.path, _client);
          final projSummary = _mapper.buildProjectsSummaryEvent();
          if (projSummary != null) {
            _sseManager.enqueueEvent(projSummary);
            _completionListener.handleSseEvent(projSummary);
          }
          Log.v("[dbg] initial projectsSummary enqueued");
        } catch (e) {
          Log.e("sse subscribe failed for connId $connID: $e");
        }
      case RelaySseUnsubscribe():
        Log.v("[dbg] SseUnsubscribe connID=$connID");
        _sseManager.unsubscribe(connID);
      default:
        Log.v("[dbg] unhandled msg type: ${msg.runtimeType}");
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
    Log.d("[response] sending ${jsonBytes.length} bytes to connID=$connID");
    _bytesSentController.add(jsonBytes.length);
    final cryptoService = RelayCryptoService();
    final encryptionKey = SecretKey(List<int>.from(_roomKey));
    final encryptor = cryptoService.createSessionEncryptor(encryptionKey);
    final framed = await frame(jsonBytes, encryptor: encryptor);
    _client.send(connID, framed);
  }
}
