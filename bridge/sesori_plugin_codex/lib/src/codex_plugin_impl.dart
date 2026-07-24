import "dart:async";
import "dart:io" show Directory;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/codex_app_server_api.dart";
import "api/codex_rollout_api.dart";
import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "codex_event_mapper.dart";
import "codex_metadata_repository.dart";
import "models/codex_collaboration_mode.dart";
import "repositories/codex_catalog_repository.dart";
import "repositories/codex_message_repository.dart";
import "repositories/codex_skill_repository.dart";
import "repositories/codex_thread_repository.dart";
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
  static const String pluginId = "codex";
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
        messageRepository: CodexMessageRepository(rolloutApi: rolloutApi),
        metadataRepository: metadataRepository,
        launchDirectory: resolvedProjectCwd,
      ),
      eventMapper: CodexEventMapper(
        pluginId: pluginId,
        projectCwd: resolvedProjectCwd,
        config: configReader.readDefaults(),
      ),
      rolloutTailer: rolloutTailer,
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
    final threadId = notification.params["threadId"] as String?;
    if (notification.method == "turn/started" && threadId != null) {
      // Calls initiated through this plugin start tailing before turn/start.
      // This fallback covers a turn started by another app-server client.
      _rolloutTailer.start(sessionId: threadId);
    }
    final activityChanged = _maintainBookkeeping(notification);
    if (notification.method == "turn/completed" && threadId != null) {
      await _rolloutTailer.finish(sessionId: threadId);
    }
    _eventMapper.map(notification).forEach(_eventBuffer.add);
    if (notification.method == "item/completed" && threadId != null) {
      // The app-server item is provisional; a rollout output written for the
      // same call id immediately enriches it with executor metadata.
      _rolloutTailer.drain(sessionId: threadId);
    }
    if (threadId != null && (notification.method == "error" || notification.method == "thread/closed")) {
      _rolloutTailer.stop(sessionId: threadId);
    }
    if (threadId != null &&
        (notification.method == "turn/completed" ||
            notification.method == "error" ||
            notification.method == "thread/closed")) {
      _eventMapper.clearRolloutTurn(threadId: threadId);
    }
    if (activityChanged) {
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
  }

  void _handleRolloutAppend(CodexRolloutAppend append) {
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

  bool _maintainBookkeeping(CodexServerNotification notification) {
    final params = notification.params;
    final threadId = params["threadId"] as String?;
    switch (notification.method) {
      case "turn/started":
        if (threadId == null) return false;
        if (!_recordAuthoritativeTurnEvidence(threadId)) return false;
        final turn = (params["turn"] as Map?)?.cast<String, dynamic>();
        final turnId = turn?["id"] as String?;
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
        return _setSessionStatus(
          threadId,
          _eventMapper.isIdleThreadStatus(params["status"])
              ? const PluginSessionStatus.idle()
              : const PluginSessionStatus.busy(),
        );
      case "thread/closed":
        if (threadId == null) return false;
        if (!_deletedThreadIds.contains(threadId)) {
          _recordAuthoritativeTurnEvidence(threadId);
        }
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
  /// [knownDirectories] is unused: codex's rollout index already enumerates
  /// every session globally, so the bridge's directory hints add nothing.
  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async =>
      _sessionService.listAllSessions();

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
      if (!_deletedThreadIds.contains(sessionId) &&
          (_turnEvidenceRevisionByThread[sessionId] ?? 0) == evidenceRevision) {
        _provisionalAcceptedTurnThreadIds.add(sessionId);
      }
      _syncWorkState();
    } on Object {
      _rolloutTailer.stop(sessionId: sessionId);
      rethrow;
    }
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    final turnId = _activeTurnByThread[sessionId];
    if (turnId == null) return;
    final client = _client;
    if (client == null) return;
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
    }
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
      if (!_deletedThreadIds.contains(threadId) && (_turnEvidenceRevisionByThread[threadId] ?? 0) == evidenceRevision) {
        _provisionalAcceptedTurnThreadIds.add(threadId);
      }
      _syncWorkState();
    } on Object {
      _rolloutTailer.stop(sessionId: threadId);
      rethrow;
    }
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
    _sessionService.deleteSession(sessionId: sessionId);
    _activeTurnByThread.remove(sessionId);
    _sessionStatuses.remove(sessionId);
    _threadDirectory.remove(sessionId);
    _rolloutTailer.stop(sessionId: sessionId);
    _eventMapper.clearRolloutTurn(threadId: sessionId);
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
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    final (:modelID, :providerID) = _sessionService.resolveModelDefaults(projectId: projectId);
    var resolvedModelID = modelID;
    if (resolvedModelID == null) {
      String? firstVisibleModelID;
      for (final model in await _listModels()) {
        if (model["hidden"] == true) continue;
        final id = model["id"] as String?;
        if (id == null || id.isEmpty) continue;
        firstVisibleModelID ??= id;
        if (model["isDefault"] == true) {
          resolvedModelID = id;
          break;
        }
      }
      resolvedModelID ??= firstVisibleModelID;
    }
    final agentModel = resolvedModelID == null
        ? null
        : PluginAgentModel(
            modelID: resolvedModelID,
            providerID: providerID,
            variant: null,
          );
    return [
      for (final collaborationMode in CodexCollaborationMode.values)
        if (agentModel != null || collaborationMode == CodexCollaborationMode.defaultMode)
          PluginAgent(
            name: collaborationMode.agentName,
            description: collaborationMode.description,
            model: agentModel,
            mode: PluginAgentMode.primary,
            hidden: false,
          ),
    ];
  }

  static String _providerDisplayName(String providerId) {
    return switch (providerId.toLowerCase()) {
      "openai" => "OpenAI",
      "anthropic" => "Anthropic",
      "google" => "Google",
      "mistral" => "Mistral",
      "groq" => "Groq",
      "xai" => "xAI",
      "deepseek" => "DeepSeek",
      "azure" => "Azure OpenAI",
      "amazon-bedrock" || "bedrock" => "Amazon Bedrock",
      _ => providerId,
    };
  }

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
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    final (:modelID, :providerID) = _sessionService.resolveModelDefaults(projectId: projectId);

    // Prefer codex's live catalog (`model/list`) so the mobile picker shows
    // every model the user can switch to, not just the configured default.
    final models = await _listModels();
    if (models.isNotEmpty) {
      String? defaultId;
      final pluginModels = <PluginModel>[];
      for (final model in models) {
        if (model["hidden"] == true) continue;
        final id = model["id"] as String?;
        if (id == null || id.isEmpty) continue;
        if (model["isDefault"] == true) defaultId = id;
        final displayName = model["displayName"] as String?;
        pluginModels.add(
          PluginModel(
            id: id,
            name: displayName == null || displayName.isEmpty ? id : displayName,
            variants: _reasoningEffortVariants(model),
            family: null,
            isAvailable: true,
            releaseDate: null,
          ),
        );
      }
      if (pluginModels.isNotEmpty) {
        final defaultModelID = _sessionService.selectCatalogDefaultModel(
          scopedModelID: modelID,
          catalogModelIds: [for (final model in pluginModels) model.id],
          catalogDefaultId: defaultId,
        );
        return PluginProvidersResult(
          providers: [
            PluginProvider.custom(
              id: providerID,
              name: _providerDisplayName(providerID),
              authType: PluginProviderAuthType.unknown,
              models: pluginModels,
              // Non-null: the catalog is non-empty here, so the repository
              // always resolves at least the first catalog model.
              defaultModelID: defaultModelID ?? pluginModels.first.id,
            ),
          ],
        );
      }
    }

    // Offline / `model/list` unavailable — fall back to the single configured
    // model so the picker still shows something usable.
    if (modelID == null) {
      return const PluginProvidersResult(providers: []);
    }
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: providerID,
          name: _providerDisplayName(providerID),
          authType: PluginProviderAuthType.unknown,
          models: [
            PluginModel(
              id: modelID,
              name: modelID,
              variants: const [],
              family: null,
              isAvailable: true,
              releaseDate: null,
            ),
          ],
          defaultModelID: modelID,
        ),
      ],
    );
  }

  /// Extracts a codex model's reasoning-effort tokens (the mobile "variants")
  /// from its `model/list` entry, ordered the way the variant picker should
  /// present them.
  ///
  /// codex reports `supportedReasoningEfforts` as `{reasoningEffort, description}`
  /// options (e.g. low/medium/high/xhigh) plus a `defaultReasoningEffort`. The
  /// effort tokens are codex's `ReasoningEffort` enum values, which pass straight
  /// through as the `turn/start` `effort` override — no mapping table needed.
  ///
  /// `defaultReasoningEffort` is surfaced FIRST: the mobile picker auto-selects
  /// the first variant when a user switches model (with no prior pick), so
  /// leading with codex's own default keeps a model switch at the model's
  /// intended effort instead of silently dropping to the lowest one. The picker
  /// also offers a synthetic "default" (null) row, and codex applies
  /// `defaultReasoningEffort` whenever no `effort` is sent, so the null
  /// selection and the leading token resolve to the same effort.
  List<String> _reasoningEffortVariants(Map<String, dynamic> model) {
    final supported = model["supportedReasoningEfforts"];
    if (supported is! List) return const [];
    final efforts = <String>[];
    for (final option in supported) {
      String? token;
      if (option is String) {
        token = option;
      } else if (option is Map) {
        final value = option["reasoningEffort"];
        if (value is String) token = value;
      }
      if (token != null && token.isNotEmpty && !efforts.contains(token)) {
        efforts.add(token);
      }
    }
    final defaultEffort = model["defaultReasoningEffort"];
    if (defaultEffort is String && efforts.remove(defaultEffort)) {
      efforts.insert(0, defaultEffort);
    }
    return efforts;
  }

  /// Fetches codex's model catalog via the `model/list` RPC. Returns an empty
  /// list when the transport isn't connected or the call fails, so callers can
  /// fall back to the locally-derived default.
  Future<List<Map<String, dynamic>>> _listModels() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final result = await client.request(
        method: "model/list",
        params: const <String, dynamic>{},
      );
      final data = (result as Map?)?["data"];
      if (data is! List) return const [];
      return [
        for (final entry in data)
          if (entry is Map) entry.cast<String, dynamic>(),
      ];
    } on Object {
      return const [];
    }
  }

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
        _sessionStatuses.values.any(
          (status) => status is PluginSessionStatusBusy || status is PluginSessionStatusRetry,
        );
    _workState.set(busy ? PluginWorkState.busy : PluginWorkState.idle);
  }
}
