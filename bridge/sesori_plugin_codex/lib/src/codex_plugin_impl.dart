import "dart:async";
import "dart:io" show Directory;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "api/codex_app_server_api.dart";
import "api/codex_rollout_api.dart";
import "api/parsers/codex_image_bearing_item_parser.dart";
import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "codex_event_mapper.dart";
import "codex_metadata_repository.dart";
import "models/codex_collaboration_mode.dart";
import "repositories/codex_catalog_repository.dart";
import "repositories/codex_message_repository.dart";
import "repositories/codex_model_repository.dart";
import "repositories/codex_skill_repository.dart";
import "repositories/codex_thread_repository.dart";
import "repositories/codex_tool_correlation_tracker.dart";
import "repositories/mappers/codex_image_attachment_mapper.dart";
import "repositories/mappers/codex_rollout_tool_mapper.dart";
import "repositories/models/codex_thread_record.dart";
import "runtime/codex_managed_api.dart";
import "services/codex_rollout_tailer.dart";
import "services/codex_session_service.dart";

/// Phase 4 of the Codex backend plugin.
///
/// Phases 2/3 brought up the WebSocket client, the `initialize` handshake,
/// and the read path via `~/.codex/session_index.jsonl` and rollout files.
/// Phase 4 adds the live write path:
///
///   - [createSession] → `thread/start` (+ first `turn/start` if parts are
///     supplied) so users can start a new codex conversation from mobile.
///   - [sendPrompt]    → `turn/start` on an existing thread.
///   - [abortSession]  → `turn/interrupt` against the active turn.
///   - The server notification stream is pumped through [CodexEventMapper]
///     into [events] so mobile UI gets live streaming output.
///   - Live session status (running/idle) is tracked from `turn/started`
///     and `turn/completed` notifications so [getSessionStatuses] returns
///     non-empty data while sessions are alive.
///
/// Approval/permission flows still throw — those land in Phase 5.
class CodexPlugin implements CodexManagedApi {
  static final String pluginId = Harness.codex.name;
  static const Duration _renameRetryDelay = Duration(milliseconds: 100);
  static const Duration _renameRetryTimeout = Duration(seconds: 2);

  final String _serverUrl;
  // Passed to the default client built in [_createClient]; retained for future
  // non-loopback (`--ws-auth`) support.
  final String? _capabilityToken;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.unknown);
  // Nullable: when the caller injects a factory (tests) we use it verbatim;
  // otherwise [_ensureConnected] builds the default client itself so it can
  // wire the client's disconnect signal into [_handleClientDisconnected].
  final CodexAppServerClient Function()? _clientFactory;
  final CodexSessionService _sessionService;
  final CodexEventMapper _eventMapper;
  final CodexRolloutTailer _rolloutTailer;
  final CodexToolCorrelationTracker _toolCorrelationTracker;
  final String _projectCwd;
  final Duration _keepaliveInterval;

  /// Fires once the WebSocket transport has completed its `initialize`
  /// handshake; the runtime descriptor wires this into its status reporter.
  /// (The disconnect signal is wired directly into the app-server client by the
  /// default client factory below.)
  final void Function()? _onConnected;

  /// Forwarded to the runtime descriptor's status reporter when the transport
  /// drops. Wrapped by [_handleClientDisconnected] so cached connection state
  /// is reset before the reporter is told.
  final void Function()? _onDisconnected;

  CodexAppServerClient? _client;
  Future<bool>? _connectFuture;
  StreamSubscription<CodexServerNotification>? _notificationSubscription;
  Future<void> _notificationWork = Future<void>.value();
  StreamSubscription<CodexRolloutAppend>? _rolloutSubscription;
  ApprovalRegistry? _approvalRegistry;

  /// Periodic no-op RPC timer. codex `app-server` closes a connection that goes
  /// idle (no JSON-RPC traffic) after a few minutes and then exits the process;
  /// with the bridge waiting between prompts that would tear down the whole
  /// session. A cheap read RPC on this cadence keeps the connection live.
  Timer? _keepaliveTimer;

  /// Most recent turn id observed per thread, used to target
  /// `turn/interrupt`. Cleared on `turn/completed` / `error`.
  final Map<String, String> _activeTurnByThread = {};

  /// Running session status keyed by thread id — fed by `turn/started`,
  /// `turn/completed`, `error` notifications.
  final Map<String, PluginSessionStatus> _sessionStatuses = {};

  /// Successful `turn/start` calls not yet corroborated by a server
  /// notification. This closes the response-to-notification gap without
  /// exposing codex turn identifiers outside the plugin.
  final Set<String> _provisionalAcceptedTurnThreadIds = {};

  /// Advances whenever authoritative turn evidence wins a `turn/start`
  /// response race, preventing that response from restoring stale busy state.
  final Map<String, int> _turnEvidenceRevisionByThread = {};

  /// Deleted thread identities cannot accept new provisional turn evidence
  /// until codex supplies an authoritative new thread lifecycle.
  final Set<String> _deletedThreadIds = {};

  /// Normalized project directory per thread, learned the moment a thread is
  /// started or resumed — before its rollout is flushed to disk. codex reports
  /// a session under its own cwd, and the bridge derives one project per cwd, so
  /// a fresh non-launch session must be attributed to its real directory
  /// immediately (rename responses and live rename events) rather than falling
  /// back to the launch cwd until the rollout appears on disk.
  final Map<String, String> _threadDirectory = {};

  factory CodexPlugin({
    required String serverUrl,
    String? capabilityToken,
    String? projectCwd,
    void Function()? onConnected,
    void Function()? onDisconnected,
    Duration keepaliveInterval = const Duration(seconds: 30),
  }) {
    final resolvedProjectCwd = projectCwd ?? Directory.current.path;
    final configReader = CodexConfigReader();
    final rolloutApi = CodexRolloutApi();
    const imageAttachmentMapper = CodexImageAttachmentMapper();
    const imageBearingItemParser = CodexImageBearingItemParser();
    const rolloutToolMapper = CodexRolloutToolMapper(
      imageAttachmentMapper: imageAttachmentMapper,
    );
    final catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
    final rolloutTailer = CodexRolloutTailer(
      rolloutApi: rolloutApi,
      catalogRepository: catalogRepository,
      pollInterval: const Duration(milliseconds: 50),
    );
    final metadataRepository = CodexMetadataRepository(
      configReader: configReader,
    );
    return CodexPlugin._(
      serverUrl: serverUrl,
      capabilityToken: capabilityToken,
      // When null, [_ensureConnected] builds the default client so it can wire
      // the client's `onDisconnected` through [_handleClientDisconnected].
      clientFactory: null,
      sessionService: CodexSessionService(
        catalogRepository: catalogRepository,
        messageRepository: CodexMessageRepository(
          rolloutApi: rolloutApi,
          rolloutToolMapper: rolloutToolMapper,
        ),
        metadataRepository: metadataRepository,
        launchDirectory: resolvedProjectCwd,
      ),
      eventMapper: CodexEventMapper(
        pluginId: pluginId,
        projectCwd: resolvedProjectCwd,
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
        config: configReader.readDefaults(),
      ),
      rolloutTailer: rolloutTailer,
      toolCorrelationTracker: CodexToolCorrelationTracker(
        rolloutToolMapper: rolloutToolMapper,
      ),
      projectCwd: resolvedProjectCwd,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
      keepaliveInterval: keepaliveInterval,
    );
  }

  CodexPlugin.injected({
    required String serverUrl,
    required String? capabilityToken,
    required CodexAppServerClient Function() clientFactory,
    required CodexSessionService sessionService,
    required CodexEventMapper eventMapper,
    required CodexRolloutTailer rolloutTailer,
    required CodexToolCorrelationTracker toolCorrelationTracker,
    required String projectCwd,
    required void Function()? onConnected,
    required void Function()? onDisconnected,
    required Duration keepaliveInterval,
  }) : this._(
         serverUrl: serverUrl,
         capabilityToken: capabilityToken,
         clientFactory: clientFactory,
         sessionService: sessionService,
         eventMapper: eventMapper,
         rolloutTailer: rolloutTailer,
         toolCorrelationTracker: toolCorrelationTracker,
         projectCwd: projectCwd,
         onConnected: onConnected,
         onDisconnected: onDisconnected,
         keepaliveInterval: keepaliveInterval,
       );

  CodexPlugin._({
    required String serverUrl,
    required String? capabilityToken,
    required CodexAppServerClient Function()? clientFactory,
    required CodexSessionService sessionService,
    required CodexEventMapper eventMapper,
    required CodexRolloutTailer rolloutTailer,
    required CodexToolCorrelationTracker toolCorrelationTracker,
    required String projectCwd,
    required void Function()? onConnected,
    required void Function()? onDisconnected,
    required Duration keepaliveInterval,
  }) : _serverUrl = serverUrl,
       _keepaliveInterval = keepaliveInterval,
       _capabilityToken = capabilityToken,
       _clientFactory = clientFactory,
       _sessionService = sessionService,
       _eventMapper = eventMapper,
       _rolloutTailer = rolloutTailer,
       _toolCorrelationTracker = toolCorrelationTracker,
       _projectCwd = projectCwd,
       _onConnected = onConnected,
       _onDisconnected = onDisconnected,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>() {
    _rolloutSubscription = _rolloutTailer.appends.listen(
      _handleRolloutAppend,
    );
  }

  String get serverUrl => _serverUrl;

  @override
  String get id => pluginId;

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  @override
  Stream<PluginWorkState> get workState => _workState.stream;

  @override
  PluginWorkState get currentWorkState => _workState.current;

  /// Lazily opens the WS connection, performs `initialize`, and starts
  /// piping server notifications into the bridge event buffer.
  ///
  /// Memoises the in-flight future so concurrent callers share one
  /// connection attempt; subsequent calls return the cached result.
  Future<bool> _ensureConnected() {
    final existing = _connectFuture;
    if (existing != null) return existing;
    final future = () async {
      final client = _createClient();
      _client = client;
      try {
        await client.connect();
        final appServerApi = CodexAppServerApi(client: client);
        _sessionService.attachAppServerRepositories(
          threadRepository: CodexThreadRepository(appServerApi: appServerApi),
          modelRepository: CodexModelRepository(appServerApi: appServerApi),
          skillRepository: CodexSkillRepository(appServerApi: appServerApi),
        );
        _subscribeToNotifications(client);
        _attachApprovalRegistry(client);
        _startKeepalive();
        _onConnected?.call();
        return true;
      } catch (error) {
        await client.dispose();
        _client = null;
        _sessionService.detachAppServerRepositories();
        _connectFuture = null;
        return Future<bool>.error(error);
      }
    }();
    _connectFuture = future.catchError((Object _) => false);
    return _connectFuture!;
  }

  /// Builds the app-server client: the injected factory verbatim (tests), or
  /// the default client with its disconnect signal wired into
  /// [_handleClientDisconnected].
  CodexAppServerClient _createClient() {
    final injected = _clientFactory;
    if (injected != null) return injected();
    return CodexAppServerClient(
      serverUrl: _serverUrl,
      capabilityToken: _capabilityToken,
      onDisconnected: _handleClientDisconnected,
    );
  }

  /// Invoked when the underlying transport drops unexpectedly. Resets the
  /// cached connection state (so [healthCheck]/[_ensureConnected] no longer
  /// hand back a stale successful future for a dead socket and instead
  /// re-establish on the next call), clears connection-scoped activity, then
  /// forwards the signal to the runtime descriptor's status reporter.
  void _handleClientDisconnected() {
    final registry = _approvalRegistry;
    final activeSessionIds = [
      for (final entry in _sessionStatuses.entries)
        if (_isActiveStatus(entry.value)) entry.key,
    ];
    final hadVisibleActivity =
        activeSessionIds.isNotEmpty ||
        _sessionStatuses.keys.any(
          (sessionId) => registry?.hasPendingInput(sessionId) ?? false,
        );
    _connectFuture = null;
    _client = null;
    _sessionService.detachAppServerRepositories();
    _rolloutTailer.stopAll();
    _toolCorrelationTracker.clear();
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _approvalRegistry = null;
    unawaited(registry?.dispose());
    _sessionStatuses.clear();
    _activeTurnByThread.clear();
    for (final sessionId in activeSessionIds) {
      _eventBuffer.add(BridgeSseSessionIdle(sessionID: sessionId));
    }
    if (hadVisibleActivity) {
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
    _provisionalAcceptedTurnThreadIds.clear();
    _turnEvidenceRevisionByThread.keys.toList().forEach(_advanceTurnEvidenceRevision);
    _workState.set(PluginWorkState.unknown);
    _onDisconnected?.call();
  }

  /// Wires the codex notification stream into the bridge event buffer,
  /// while side-effecting on a few notifications to keep session-status
  /// and turn-id bookkeeping current.
  void _subscribeToNotifications(CodexAppServerClient client) {
    _notificationSubscription = client.notifications.listen((notification) {
      // Serialize notification side effects so a terminal rollout drain cannot
      // let session.idle overtake its final tool update.
      _notificationWork = _notificationWork.then((_) => _handleNotification(notification)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        Log.e(
          "[codex] failed to map app-server notification",
          error,
          stackTrace,
        );
      });
    });
  }

  Future<void> _handleNotification(
    CodexServerNotification notification,
  ) async {
    if (notification.method == "thread/started") {
      final thread = _sessionService.decodeStartedNotificationParams(
        params: notification.params,
      );
      if (thread == null) return;
      _maintainThreadStarted(thread);
      _eventMapper.mapThreadStarted(thread).forEach(_eventBuffer.add);
      return;
    }
    if (_isSupersededTurnLifecycleNotification(notification)) return;
    final threadId = notification.params["threadId"] as String?;
    if (notification.method == "turn/started" && threadId != null) {
      // Calls initiated through this plugin start tailing before turn/start.
      // This fallback covers a turn started by another app-server client.
      _rolloutTailer.start(sessionId: threadId);
    }
    if (threadId != null && (notification.method == "item/started" || notification.method == "item/completed")) {
      // Codex persists the response item before emitting its stable lifecycle
      // event. Drain now so polling latency cannot split one command identity.
      _rolloutTailer.drain(sessionId: threadId);
    }
    final terminalHistory =
        notification.method == "turn/completed" ||
        notification.method == "error" ||
        notification.method == "thread/closed" ||
        (notification.method == "thread/status/changed" &&
            _eventMapper.isIdleThreadStatus(notification.params["status"]));
    if (terminalHistory && threadId != null) {
      await _rolloutTailer.finish(sessionId: threadId);
      if (_isSupersededTurnLifecycleNotification(notification)) return;
    }
    // Keep work state busy until the terminal rollout drain has emitted its
    // final tool updates. Forced runtime teardown waits for this transition
    // before disconnecting the generation's event stream.
    final activityChanged = _maintainBookkeeping(notification);
    final commandProjection = _toolCorrelationTracker.correlateAppServerCommand(
      notification: notification,
    );
    _eventMapper
        .mapCommand(
          notification: notification,
          commandProjection: commandProjection,
        )
        .forEach(_eventBuffer.add);
    if (threadId != null &&
        (notification.method == "turn/completed" ||
            notification.method == "error" ||
            notification.method == "thread/closed")) {
      _eventMapper.clearRolloutTurn(threadId: threadId);
    }
    if (threadId != null && terminalHistory) {
      _toolCorrelationTracker.clearThread(threadId: threadId);
    }
    if (activityChanged) {
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
  }

  void _handleRolloutAppend(CodexRolloutAppend append) {
    _toolCorrelationTracker.observeRolloutLine(
      threadId: append.sessionId,
      line: append.line,
    );
    _eventMapper.mapRolloutLine(threadId: append.sessionId, line: append.line).forEach(_eventBuffer.add);
  }

  void _maintainThreadStarted(CodexThreadRecord thread) {
    _recordAuthoritativeThreadCreation(thread.id);
    _sessionStatuses[thread.id] = const PluginSessionStatus.idle();
    final directory = thread.directory;
    if (directory != null) _recordThreadDirectory(thread.id, directory);
    _syncWorkState();
  }

  /// Wires codex server-originated requests (approval prompts and
  /// elicitations) through the [ApprovalRegistry] so they surface as
  /// bridge permission/question events.
  void _attachApprovalRegistry(CodexAppServerClient client) {
    final registry = ApprovalRegistry(
      emit: _emitApprovalEvent,
      respond: (id, result) => client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) => client.respondToServerRequestWithError(
        id: id,
        code: code,
        message: message,
      ),
    );
    _approvalRegistry = registry;
    registry.attach(client.serverRequests);
  }

  void _emitApprovalEvent(BridgeSseEvent event) {
    _syncWorkState();
    _eventBuffer.add(event);
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  /// Starts (or restarts) the idle-keepalive timer. Sends a cheap read RPC on
  /// the connection every [_keepaliveInterval] so codex `app-server` never sees
  /// the connection as idle long enough to close it and exit (verified: a
  /// connection with no traffic is closed within a few minutes, whereas one
  /// kept warm with periodic RPCs survives indefinitely).
  void _startKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) => _sendKeepalive());
  }

  void _sendKeepalive() {
    final client = _client;
    if (client == null) return;
    // `model/list` is a cheap local capability query (no model inference, so no
    // usage cost). The response is irrelevant — the point is the traffic; a
    // failure (e.g. transport already gone) is swallowed.
    unawaited(
      client.request(method: "model/list", timeout: _keepaliveInterval).catchError((Object _) => null),
    );
  }

  bool _isSupersededTurnLifecycleNotification(
    CodexServerNotification notification,
  ) {
    final threadId = notification.params["threadId"] as String?;
    if (threadId == null) return false;
    final tracksTurnIdentity = switch (notification.method) {
      "turn/started" || "turn/completed" || "error" || "thread/status/changed" => true,
      _ => false,
    };
    if (!tracksTurnIdentity) return false;

    final activeTurnId = _activeTurnByThread[threadId];
    final notificationTurnId = _notificationTurnId(notification.params);
    if (activeTurnId != null && notificationTurnId != null && activeTurnId != notificationTurnId) {
      return true;
    }
    return notification.method == "thread/status/changed" &&
        _eventMapper.isIdleThreadStatus(notification.params["status"]) &&
        notificationTurnId == null &&
        (activeTurnId != null || _provisionalAcceptedTurnThreadIds.contains(threadId));
  }

  String? _notificationTurnId(Map<String, dynamic> params) {
    final turn = params["turn"];
    Object? value = turn is Map ? turn["id"] : null;
    value ??= params["turnId"];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _maintainBookkeeping(CodexServerNotification notification) {
    final params = notification.params;
    final threadId = params["threadId"] as String?;
    switch (notification.method) {
      case "turn/started":
        if (threadId == null) return false;
        if (!_recordAuthoritativeTurnEvidence(threadId)) return false;
        final turnId = _notificationTurnId(params);
        if (turnId != null) _activeTurnByThread[threadId] = turnId;
        return _setSessionStatus(threadId, const PluginSessionStatus.busy());
      case "turn/completed":
        if (threadId == null) return false;
        if (!_recordAuthoritativeTurnEvidence(threadId)) return false;
        _activeTurnByThread.remove(threadId);
        return _setSessionStatus(threadId, const PluginSessionStatus.idle());
      case "error":
        if (threadId == null) return false;
        if (!_recordAuthoritativeTurnEvidence(threadId)) return false;
        _activeTurnByThread.remove(threadId);
        // PluginSessionStatus has no explicit "error" — surfacing as idle
        // and letting the mapped BridgeSseSessionError carry the signal.
        return _setSessionStatus(threadId, const PluginSessionStatus.idle());
      case "thread/status/changed":
        if (threadId == null) return false;
        if (!_recordAuthoritativeTurnEvidence(threadId)) return false;
        final idle = _eventMapper.isIdleThreadStatus(params["status"]);
        if (idle) _activeTurnByThread.remove(threadId);
        return _setSessionStatus(
          threadId,
          idle ? const PluginSessionStatus.idle() : const PluginSessionStatus.busy(),
        );
      case "thread/closed":
        if (threadId == null) return false;
        if (!_deletedThreadIds.contains(threadId)) {
          _recordAuthoritativeTurnEvidence(threadId);
        }
        _approvalRegistry?.cancelForSession(threadId);
        _activeTurnByThread.remove(threadId);
        final wasActive = _isActiveStatus(_sessionStatuses.remove(threadId));
        // The app-server unloaded this thread; a later turn must resume it.
        _sessionService.markThreadUnloaded(threadId: threadId);
        _syncWorkState();
        return wasActive;
    }
    return false;
  }

  bool _setSessionStatus(String threadId, PluginSessionStatus status) {
    final wasActive = _isActiveStatus(_sessionStatuses[threadId]);
    _sessionStatuses[threadId] = status;
    _syncWorkState();
    return wasActive != _isActiveStatus(status);
  }

  bool _isActiveStatus(PluginSessionStatus? status) =>
      status is PluginSessionStatusBusy || status is PluginSessionStatusRetry;

  /// Cold-start hook the runtime descriptor awaits before reporting the
  /// plugin ready: opens the WebSocket, performs the `initialize` handshake,
  /// and starts pumping notifications. Idempotent — concurrent and repeat
  /// callers share the single in-flight connection. Throws when the cold-start
  /// fails so the descriptor can surface a degraded status.
  @override
  Future<void> initialize() async {
    final connected = await _ensureConnected();
    if (!connected) {
      throw StateError("codex app-server cold-start failed for $_serverUrl");
    }
    _syncWorkState();
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return await _ensureConnected();
    } catch (_) {
      return false;
    }
  }

  /// codex is a [BridgeDerivedProjectsPluginApi], so the bridge derives the
  /// project list from these sessions. Each carries its real rollout cwd as its
  /// directory so the bridge groups it under the right project.
  ///
  /// [knownDirectories] preserves sessions already attributed to stored
  /// projects while discovery excludes new Codex Desktop projectless chats.
  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async =>
      _sessionService.listAllSessions(knownDirectories: knownDirectories);

  @override
  String get launchDirectory => _projectCwd;

  /// No-op: codex's global rollout index self-resolves every session's cwd,
  /// so the bridge's stored-directory hint adds nothing. (Spelled out because
  /// this class `implements` the plugin interface rather than extending it,
  /// so the interface's no-op default does not apply.)
  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {}

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async => _sessionService.getSessions(
    projectId: projectId,
    start: start,
    limit: limit,
  );

  @override
  Future<List<PluginCommand>> getCommands({
    required String? projectId,
  }) async {
    await _connectedClient();
    return _sessionService.getCommands(projectId: projectId);
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    await _connectedClient();
    return _sessionService.getSessionOptions(projectId: projectId);
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    await _connectedClient();
    final thread = await _sessionService.startThread(
      cwd: directory,
      model: model?.modelID,
      modelProvider: model?.providerID,
    );
    _eventMapper.setThreadTime(thread);
    final threadId = thread.id;
    _recordAuthoritativeThreadCreation(threadId);
    // codex's ThreadStartResponse carries the resolved model alongside the
    // thread; record it so live-streamed assistant messages are stamped with
    // the model the user actually chose, not the global config default.
    _eventMapper.setThreadModel(
      threadId,
      thread.model ?? model?.modelID,
    );
    final resolvedDirectory = thread.directory ?? normalizeProjectDirectory(directory: directory);
    // Record the thread's directory BEFORE the first turn: turn/start can emit
    // notifications (e.g. a cwd-less thread/name/updated) while the rollout is
    // still unwritten, and without this the mapper would attribute those
    // events to the launch cwd — making a non-launch project's client drop
    // them as a project mismatch. Also covers lookups before the rollout is
    // flushed (rename response, live rename event).
    _recordThreadDirectory(threadId, resolvedDirectory);
    if (parts.isNotEmpty) {
      // thread/start has no `effort` field, so the chosen reasoning effort is
      // applied on this first turn (and sticks for subsequent ones).
      await _startTurn(
        threadId: threadId,
        parts: parts,
        variant: variant,
        collaborationMode: CodexCollaborationMode.fromAgent(agent: agent),
      );
    }
    return _sessionService.toPluginSession(
      thread: thread,
      fallbackDirectory: resolvedDirectory,
      parentSessionId: parentSessionId,
    );
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    await _connectedClient();
    await _startTurn(
      threadId: sessionId,
      parts: parts,
      model: model,
      variant: variant,
      collaborationMode: CodexCollaborationMode.fromAgent(agent: agent),
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    await _connectedClient();
    if (model != null) {
      _eventMapper.setThreadModel(sessionId, model.modelID);
    }
    _rolloutTailer.start(sessionId: sessionId);
    final evidenceRevision = _turnEvidenceRevisionByThread[sessionId] ?? 0;
    try {
      final dispatch = await _sessionService.sendCommand(
        threadId: sessionId,
        command: command,
        arguments: arguments,
        model: model?.modelID,
        effort: variant?.id,
        collaborationMode: CodexCollaborationMode.fromAgent(agent: agent),
      );
      _applyResumedThread(
        threadId: sessionId,
        response: dispatch.resumedThread,
      );
      final resolvedModel = dispatch.resolvedModel;
      if (resolvedModel != null) {
        _eventMapper.setThreadModel(sessionId, resolvedModel);
      }
      final turnId = dispatch.turnId;
      if (turnId != null) {
        _recordAcceptedTurn(
          threadId: sessionId,
          turnId: turnId,
          evidenceRevision: evidenceRevision,
        );
      }
      _syncWorkState();
    } on Object {
      _rolloutTailer.stop(sessionId: sessionId);
      rethrow;
    }
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    _approvalRegistry?.cancelForSession(sessionId);
    final turnId = _activeTurnByThread[sessionId];
    if (turnId == null) {
      _syncWorkState();
      return;
    }
    final client = _client;
    if (client == null) {
      _syncWorkState();
      return;
    }
    try {
      await client.request(
        method: "turn/interrupt",
        params: {"threadId": sessionId, "turnId": turnId},
      );
    } on CodexRpcException catch (error) {
      // If the turn already completed before our interrupt arrived,
      // codex returns a "not found" — treat as already-aborted.
      if (error.code != -32602) rethrow;
    } finally {
      _activeTurnByThread.remove(sessionId);
      _syncWorkState();
    }
  }

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        ..._provisionalAcceptedTurnThreadIds,
        ..._activeTurnByThread.keys,
        for (final entry in _sessionStatuses.entries)
          if (_isActiveStatus(entry.value)) entry.key,
        ...?_approvalRegistry?.pendingSessionIds,
      };
      if (activeSessionIds.isEmpty) return const <String>{};

      await Future.wait([
        for (final sessionId in activeSessionIds) abortSession(sessionId: sessionId),
      ]);
      await _notificationWork;
      if (currentWorkState != PluginWorkState.idle) {
        await workState.firstWhere((state) => state == PluginWorkState.idle);
      }
      return Set<String>.unmodifiable(activeSessionIds);
    }().timeout(budget);
  }

  Future<void> _startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    ({String providerID, String modelID})? model,
    PluginSessionVariant? variant,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    if (model != null) {
      // A turn/start model override applies to this turn and subsequent ones,
      // so update the per-thread model used to stamp live assistant messages.
      _eventMapper.setThreadModel(threadId, model.modelID);
    }
    // The bridge carries codex's reasoning effort as the session "variant": the
    // id is a codex ReasoningEffort token (low/medium/high/xhigh) that maps
    // straight onto turn/start's `effort` override (applies to this turn and
    // subsequent ones). A null/empty variant lets the selected collaboration
    // mode supply its own default (Plan uses medium), or Codex use the model's
    // defaultReasoningEffort when no collaboration mode was selected.
    final effort = variant?.id;
    // Capture the current EOF before Codex can append this turn's response
    // items. `start` is idempotent when turn/started arrives afterwards.
    _rolloutTailer.start(sessionId: threadId);
    final evidenceRevision = _turnEvidenceRevisionByThread[threadId] ?? 0;
    try {
      final dispatch = await _sessionService.startTurn(
        threadId: threadId,
        parts: parts,
        model: model?.modelID,
        effort: effort == null || effort.isEmpty ? null : effort,
        collaborationMode: collaborationMode,
      );
      if (!dispatch.started) {
        _rolloutTailer.stop(sessionId: threadId);
        return;
      }
      _applyResumedThread(
        threadId: threadId,
        response: dispatch.resumedThread,
      );
      final resolvedModel = dispatch.resolvedModel;
      if (resolvedModel != null) {
        _eventMapper.setThreadModel(threadId, resolvedModel);
      }
      final turnId = dispatch.turnId;
      if (turnId != null) {
        _recordAcceptedTurn(
          threadId: threadId,
          turnId: turnId,
          evidenceRevision: evidenceRevision,
        );
      }
      _syncWorkState();
    } on Object {
      _rolloutTailer.stop(sessionId: threadId);
      rethrow;
    }
  }

  void _recordAcceptedTurn({
    required String threadId,
    required String turnId,
    required int evidenceRevision,
  }) {
    if (_deletedThreadIds.contains(threadId) || (_turnEvidenceRevisionByThread[threadId] ?? 0) != evidenceRevision) {
      return;
    }
    _activeTurnByThread[threadId] = turnId;
    _provisionalAcceptedTurnThreadIds.add(threadId);
  }

  bool _recordAuthoritativeTurnEvidence(String threadId) {
    if (_deletedThreadIds.contains(threadId)) return false;
    _provisionalAcceptedTurnThreadIds.remove(threadId);
    _advanceTurnEvidenceRevision(threadId);
    return true;
  }

  void _recordAuthoritativeThreadCreation(String threadId) {
    _deletedThreadIds.remove(threadId);
    _provisionalAcceptedTurnThreadIds.remove(threadId);
    _advanceTurnEvidenceRevision(threadId);
  }

  void _advanceTurnEvidenceRevision(String threadId) {
    _turnEvidenceRevisionByThread[threadId] = (_turnEvidenceRevisionByThread[threadId] ?? 0) + 1;
  }

  void _applyResumedThread({
    required String threadId,
    required CodexThreadRecord? response,
  }) {
    if (response == null) return;
    _eventMapper.setThreadTime(response);
    _eventMapper.setThreadModel(threadId, response.model);
    _eventMapper.setThreadProvider(threadId, response.modelProvider);
    // A thread resumed from a prior bridge run never re-emits `thread/started`,
    // so learn its directory here (from the resume payload, else its rollout)
    // to keep live rename events attributed to its real project.
    _recordThreadDirectory(
      threadId,
      response.directory ?? _directoryForSession(threadId),
    );
  }

  bool _isEmptyRollout(CodexRpcException error) {
    final message = error.message.toLowerCase();
    return error.code == -32603 &&
        message.contains("failed to read session metadata") &&
        message.contains("rollout") &&
        message.contains(" is empty");
  }

  Future<CodexAppServerClient> _connectedClient() async {
    final ok = await _ensureConnected();
    final client = _client;
    if (!ok || client == null) {
      throw StateError("codex app-server is not connected");
    }
    return client;
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    final client = await _connectedClient();
    Stopwatch? retryClock;
    for (var attempt = 1; ; attempt++) {
      final requestTimeout = retryClock == null
          ? const Duration(seconds: 30)
          : _renameRetryTimeout - retryClock.elapsed;
      if (requestTimeout <= Duration.zero) {
        throw TimeoutException("Codex session rename retry deadline elapsed");
      }
      try {
        await client.request(
          method: "thread/name/set",
          params: {"threadId": sessionId, "name": title},
          timeout: requestTimeout,
        );
        break;
      } on CodexRpcException catch (error) {
        // thread/start can return after creating the rollout but before its
        // initial session metadata has been flushed. Retry only that transient
        // app-server failure; unrelated rename failures remain immediate.
        if (!_isEmptyRollout(error)) rethrow;
        retryClock ??= Stopwatch()..start();
        if (retryClock.elapsed + _renameRetryDelay > _renameRetryTimeout) rethrow;
        Log.d(
          "Codex rollout metadata is not ready for session $sessionId; "
          "retrying rename after attempt $attempt",
        );
        await Future<void>.delayed(_renameRetryDelay);
      }
    }
    final directory = _directoryForSession(sessionId);
    return PluginSession(
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: title,
      time: null,
    );
  }

  /// The normalized project directory for [sessionId]: the in-memory directory
  /// learned when the thread was started/resumed (authoritative before the
  /// rollout is flushed), then the session's rollout cwd, then the launch cwd —
  /// so a session is attributed to its real project even in the flush window.
  String _directoryForSession(String sessionId) {
    final known = _threadDirectory[sessionId];
    if (known != null) return known;
    return _sessionService.directoryForSession(sessionId: sessionId);
  }

  /// Records [directory] as [threadId]'s normalized project directory and feeds
  /// it to the event mapper so live session events carry the same cwd-derived
  /// project id the bridge derives (otherwise the mobile session list drops
  /// them as a project mismatch for a non-launch session).
  void _recordThreadDirectory(String threadId, String directory) {
    final normalized = normalizeProjectDirectory(directory: directory);
    _threadDirectory[threadId] = normalized;
    _eventMapper.setThreadDirectory(threadId, normalized);
  }

  /// Removes a codex session by deleting its rollout JSONL and dropping
  /// the matching entry from `session_index.jsonl`.
  ///
  /// If the session is currently running, the active turn is interrupted
  /// first so codex isn't left writing to a file the bridge just deleted.
  /// Errors during cleanup are logged and swallowed — mobile expects
  /// best-effort delete semantics.
  @override
  Future<void> deleteSession(String sessionId) async {
    _deletedThreadIds.add(sessionId);
    _provisionalAcceptedTurnThreadIds.remove(sessionId);
    _advanceTurnEvidenceRevision(sessionId);
    if (_activeTurnByThread.containsKey(sessionId)) {
      try {
        await abortSession(sessionId: sessionId);
      } catch (_) {
        // Continue with delete even if the abort raced.
      }
    }
    _approvalRegistry?.cancelForSession(sessionId);
    _sessionService.deleteSession(sessionId: sessionId);
    _activeTurnByThread.remove(sessionId);
    _sessionStatuses.remove(sessionId);
    _threadDirectory.remove(sessionId);
    _rolloutTailer.stop(sessionId: sessionId);
    _eventMapper.clearRolloutTurn(threadId: sessionId);
    _toolCorrelationTracker.clearThread(threadId: sessionId);
    _eventMapper.forgetThread(sessionId);
    _syncWorkState();
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    try {
      final client = await _connectedClient();
      await client.request(
        method: "thread/archive",
        params: {"threadId": sessionId},
      );
    } catch (_) {
      // Best-effort — mobile DB archive state is authoritative.
    }
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    // Codex does not manage worktrees.
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    // codex-cli 0.142.0's rollout headers do not record a parent/`forked_from`
    // link, so we have no way to reconstruct the parent→child relationship from
    // disk. Until codex surfaces it, return empty — the bridge contract
    // treats this as "no children known", not as an error.
    return const [];
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => Map.unmodifiable(_sessionStatuses);

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) => _sessionService.getSessionMessages(sessionId: sessionId);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => _sessionService.getAgents(projectId: projectId);

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async => _approvalRegistry?.pendingForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async => _approvalRegistry?.pendingPermissionsForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return const [];
    // Scope to the sessions whose directory belongs to this project so a pending
    // approval in one codex project doesn't surface under every other. Resolves
    // each session's directory via [_directoryForSession] so a freshly-created
    // session (not yet flushed to its rollout) is still scoped correctly.
    final target = normalizeProjectDirectory(directory: projectId);
    final sessionIds = _sessionStatuses.keys.where((id) => _directoryForSession(id) == target).toList(growable: false);
    return registry.pendingForProject(sessionIds);
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return;
    registry.replyQuestion(questionId, answers);
  }

  @override
  Future<void> rejectQuestion({
    required String questionId,
    required String? sessionId,
  }) async {
    // sessionId is unused: the approval registry keys pending requests by their
    // bridge request id alone (codex requests are globally unique per session).
    _approvalRegistry?.rejectQuestion(questionId);
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    _approvalRegistry?.replyPermission(requestId, reply);
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) =>
      _sessionService.getProviders(projectId: projectId);

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final registry = _approvalRegistry;
    final byProject = <String, List<PluginActiveSession>>{};
    for (final entry in _sessionStatuses.entries) {
      final running = _isActiveStatus(entry.value);
      final awaitingInput = registry?.hasPendingInput(entry.key) ?? false;
      if (!running && !awaitingInput) continue;
      (byProject[_directoryForSession(entry.key)] ??= []).add(
        PluginActiveSession(
          id: entry.key,
          mainAgentRunning: running,
          awaitingInput: awaitingInput,
          isRetrying: false,
          childSessionIds: const [],
        ),
      );
    }
    return [
      for (final entry in byProject.entries)
        PluginProjectActivitySummary(
          id: entry.key,
          activeSessions: entry.value,
        ),
    ];
  }

  @override
  Future<void> dispose() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> capture(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await capture(() => _notificationSubscription?.cancel() ?? Future<void>.value());
    _notificationSubscription = null;
    await capture(() => _notificationWork);
    await capture(() => _rolloutSubscription?.cancel() ?? Future<void>.value());
    _rolloutSubscription = null;
    await capture(_rolloutTailer.dispose);
    await capture(() => _approvalRegistry?.dispose() ?? Future<void>.value());
    _approvalRegistry = null;
    await capture(() => _client?.dispose() ?? Future<void>.value());
    _client = null;
    _sessionService.detachAppServerRepositories();
    await capture(_eventBuffer.close);
    await capture(_workState.close);
    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStackTrace!);
  }

  void _syncWorkState() {
    final busy =
        _provisionalAcceptedTurnThreadIds.isNotEmpty ||
        _activeTurnByThread.isNotEmpty ||
        (_approvalRegistry?.hasAnyPendingInput ?? false) ||
        _sessionStatuses.values.any(
          (status) => status is PluginSessionStatusBusy || status is PluginSessionStatusRetry,
        );
    _workState.set(busy ? PluginWorkState.busy : PluginWorkState.idle);
  }
}
