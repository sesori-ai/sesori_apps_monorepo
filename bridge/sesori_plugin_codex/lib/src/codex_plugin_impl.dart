import "dart:async";
import "dart:io" show Directory;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/codex_thread_dto.dart";
import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "codex_event_mapper.dart";
import "codex_metadata_repository.dart";
import "codex_skill_reader.dart";
import "repositories/codex_catalog_repository.dart";
import "runtime/codex_managed_api.dart";
import "session_rollout_reader.dart";

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

  final String _serverUrl;
  // Passed to the default client built in [_createClient]; retained for future
  // non-loopback (`--ws-auth`) support.
  final String? _capabilityToken;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  // Nullable: when the caller injects a factory (tests) we use it verbatim;
  // otherwise [_ensureConnected] builds the default client itself so it can
  // wire the client's disconnect signal into [_handleClientDisconnected].
  final CodexAppServerClient Function()? _clientFactory;
  final SessionRolloutReader _rolloutReader;
  final CodexConfigReader _configReader;
  final CodexCatalogRepository _catalogRepository;
  final CodexMetadataRepository _metadataRepository;
  final CodexEventMapper _eventMapper;
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

  /// Threads the current `app-server` process has loaded into memory — i.e.
  /// started (`thread/start`) or resumed (`thread/resume`) during this plugin
  /// instance's lifetime. codex keeps threads in memory per process, so a
  /// session created in a *previous* bridge run (and only present on disk as a
  /// rollout) is unknown to a freshly-spawned app-server: a `turn/start`
  /// against it fails with "thread not found". This set lets [_startTurn]
  /// resume such threads on demand before the first turn. The codex transport
  /// never reconnects within one instance (a drop tears the plugin down), so
  /// this never goes stale against a live connection.
  final Set<String> _loadedThreads = {};

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
    CodexAppServerClient Function()? clientFactory,
    SessionRolloutReader? rolloutReader,
    CodexConfigReader? configReader,
    CodexMetadataRepository? metadataRepository,
    CodexEventMapper? eventMapper,
    String? projectCwd,
    void Function()? onConnected,
    void Function()? onDisconnected,
    Duration keepaliveInterval = const Duration(seconds: 30),
  }) {
    final resolvedProjectCwd = projectCwd ?? Directory.current.path;
    final resolvedConfigReader = configReader ?? CodexConfigReader();
    final resolvedRolloutReader = rolloutReader ?? SessionRolloutReader();
    return CodexPlugin._(
      serverUrl: serverUrl,
      capabilityToken: capabilityToken,
      // When null, [_ensureConnected] builds the default client so it can wire
      // the client's `onDisconnected` through [_handleClientDisconnected].
      clientFactory: clientFactory,
      rolloutReader: resolvedRolloutReader,
      configReader: resolvedConfigReader,
      catalogRepository: CodexCatalogRepository(
        rolloutReader: resolvedRolloutReader,
      ),
      // Shares the plugin's own rollout/config readers so both resolve project
      // metadata from the same codex home.
      metadataRepository:
          metadataRepository ??
          CodexMetadataRepository(
            skillReader: CodexSkillReader(),
            rolloutReader: resolvedRolloutReader,
            configReader: resolvedConfigReader,
            launchDirectory: resolvedProjectCwd,
          ),
      eventMapper:
          eventMapper ??
          CodexEventMapper(
            pluginId: pluginId,
            projectCwd: resolvedProjectCwd,
            config: resolvedConfigReader.readDefaults(),
          ),
      projectCwd: resolvedProjectCwd,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
      keepaliveInterval: keepaliveInterval,
    );
  }

  CodexPlugin._({
    required String serverUrl,
    required String? capabilityToken,
    required CodexAppServerClient Function()? clientFactory,
    required SessionRolloutReader rolloutReader,
    required CodexConfigReader configReader,
    required CodexCatalogRepository catalogRepository,
    required CodexMetadataRepository metadataRepository,
    required CodexEventMapper eventMapper,
    required String projectCwd,
    void Function()? onConnected,
    void Function()? onDisconnected,
    Duration keepaliveInterval = const Duration(seconds: 30),
  }) : _serverUrl = serverUrl,
       _keepaliveInterval = keepaliveInterval,
       _capabilityToken = capabilityToken,
       _clientFactory = clientFactory,
       _rolloutReader = rolloutReader,
       _configReader = configReader,
       _catalogRepository = catalogRepository,
       _metadataRepository = metadataRepository,
       _eventMapper = eventMapper,
       _projectCwd = projectCwd,
       _onConnected = onConnected,
       _onDisconnected = onDisconnected,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  String get serverUrl => _serverUrl;

  @override
  String get id => pluginId;

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

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
        _subscribeToNotifications(client);
        _attachApprovalRegistry(client);
        _startKeepalive();
        _onConnected?.call();
        return true;
      } catch (error) {
        await client.dispose();
        _client = null;
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
  /// re-establish on the next call), then forwards the signal to the runtime
  /// descriptor's status reporter.
  void _handleClientDisconnected() {
    _connectFuture = null;
    _client = null;
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _onDisconnected?.call();
  }

  /// Wires the codex notification stream into the bridge event buffer,
  /// while side-effecting on a few notifications to keep session-status
  /// and turn-id bookkeeping current.
  void _subscribeToNotifications(CodexAppServerClient client) {
    _notificationSubscription = client.notifications.listen((notification) {
      _maintainBookkeeping(notification);
      _eventMapper.map(notification).forEach(_eventBuffer.add);
    });
  }

  /// Wires codex server-originated requests (approval prompts and
  /// elicitations) through the [ApprovalRegistry] so they surface as
  /// bridge permission/question events.
  void _attachApprovalRegistry(CodexAppServerClient client) {
    final registry = ApprovalRegistry(
      emit: _eventBuffer.add,
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

  void _maintainBookkeeping(CodexServerNotification notification) {
    final params = notification.params;
    final threadId = params["threadId"] as String?;
    switch (notification.method) {
      case "turn/started":
        if (threadId == null) return;
        final turn = (params["turn"] as Map?)?.cast<String, dynamic>();
        final turnId = turn?["id"] as String?;
        if (turnId != null) _activeTurnByThread[threadId] = turnId;
        _sessionStatuses[threadId] = const PluginSessionStatus.busy();
      case "turn/completed":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _sessionStatuses[threadId] = const PluginSessionStatus.idle();
      case "error":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        // PluginSessionStatus has no explicit "error" — surfacing as idle
        // and letting the mapped BridgeSseSessionError carry the signal.
        _sessionStatuses[threadId] = const PluginSessionStatus.idle();
      case "thread/closed":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _sessionStatuses.remove(threadId);
        // The app-server unloaded this thread; a later turn must resume it.
        _loadedThreads.remove(threadId);
      case "thread/started":
        final thread = (params["thread"] as Map?)?.cast<String, dynamic>();
        final id = thread?["id"] as String?;
        if (id == null) return;
        _sessionStatuses[id] = const PluginSessionStatus.idle();
        final cwd = thread?["cwd"] as String?;
        if (cwd != null && cwd.isNotEmpty) _recordThreadDirectory(id, cwd);
    }
  }

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
      _catalogRepository.listAllSessions();

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
  }) async => _catalogRepository.getSessions(
    projectId: projectId,
    start: start,
    limit: limit,
  );

  @override
  Future<List<PluginCommand>> getCommands({
    required String? projectId,
  }) async => _metadataRepository.getCommands(projectId: projectId);

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final client = await _connectedClient();
    final params = <String, dynamic>{"cwd": directory};
    if (model != null) {
      params["model"] = model.modelID;
      params["modelProvider"] = model.providerID;
    }
    final result = await client.request(method: "thread/start", params: params);
    final response = _threadEnvelopeFrom(result);
    final thread = response.thread;
    final threadId = thread?.id;
    if (threadId == null) {
      throw StateError("thread/start response missing thread.id");
    }
    // The app-server now holds this thread in memory; record it so a later
    // turn against it does not trigger a redundant resume.
    _loadedThreads.add(threadId);
    // codex's ThreadStartResponse carries the resolved model alongside the
    // thread; record it so live-streamed assistant messages are stamped with
    // the model the user actually chose, not the global config default.
    _eventMapper.setThreadModel(
      threadId,
      response.model ?? model?.modelID,
    );
    final resolvedDirectory = normalizeProjectDirectory(directory: thread?.cwd ?? directory);
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
        client: client,
        threadId: threadId,
        parts: parts,
        variant: variant,
      );
    }
    return PluginSession(
      branchName: _usefulText(thread?.gitInfo?.branch),
      id: threadId,
      projectID: resolvedDirectory,
      directory: resolvedDirectory,
      parentID: parentSessionId,
      title: thread?.name,
      time: _timeFromThread(thread),
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
    final client = await _connectedClient();
    await _startTurn(
      client: client,
      threadId: sessionId,
      parts: parts,
      model: model,
      variant: variant,
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    // Codex doesn't have a generic third-party-extensible slash-command
    // API; we encode the invocation as plain user text so codex's TUI-style
    // slash handlers (e.g. `/plan`) can pick it up if they're registered.
    final body = arguments.isEmpty ? "/$command" : "/$command $arguments";
    await _startTurn(
      client: await _connectedClient(),
      threadId: sessionId,
      parts: [PluginPromptPart.text(text: body)],
      model: model,
      variant: variant,
    );
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
    required CodexAppServerClient client,
    required String threadId,
    required List<PluginPromptPart> parts,
    ({String providerID, String modelID})? model,
    PluginSessionVariant? variant,
  }) async {
    final input = parts.map(_promptPartToUserInput).whereType<Map<String, dynamic>>().toList();
    if (input.isEmpty) return;
    // A session created in a previous bridge run is only on disk; the current
    // app-server has not loaded it, so resume it on demand before the turn.
    await _ensureThreadLoaded(client, threadId);
    final params = <String, dynamic>{"threadId": threadId, "input": input};
    if (model != null) {
      params["model"] = model.modelID;
      // A turn/start model override applies to this turn and subsequent ones,
      // so update the per-thread model used to stamp live assistant messages.
      _eventMapper.setThreadModel(threadId, model.modelID);
    }
    // The bridge carries codex's reasoning effort as the session "variant": the
    // id is a codex ReasoningEffort token (low/medium/high/xhigh) that maps
    // straight onto turn/start's `effort` override (applies to this turn and
    // subsequent ones). A null/empty variant is the "default" selection — we
    // send no `effort` so codex falls back to the model's defaultReasoningEffort.
    final effort = variant?.id;
    if (effort != null && effort.isNotEmpty) {
      params["effort"] = effort;
    }
    try {
      await client.request(method: "turn/start", params: params);
    } on CodexRpcException catch (error) {
      // Defensive: even if we believed the thread was loaded, the app-server
      // may have dropped it (or our tracking is stale). Force a resume and
      // retry the turn exactly once before giving up.
      if (!_isThreadNotFound(error)) rethrow;
      await _ensureThreadLoaded(client, threadId, force: true);
      await client.request(method: "turn/start", params: params);
    }
  }

  /// Ensures [threadId] is loaded in the current `app-server` before a turn.
  ///
  /// codex holds threads in memory per process: a session created in a previous
  /// bridge run exists only as a rollout on disk and is unknown to a freshly
  /// spawned app-server, so a `turn/start` against it fails with "thread not
  /// found". This resumes such a thread on demand and records the
  /// model/provider codex reports for it so live-streamed assistant messages
  /// are stamped correctly (the resume response is the same shape as
  /// `thread/start`'s, carrying the authoritative `model`/`modelProvider`).
  ///
  /// [force] re-resumes even when the thread is believed loaded — used to
  /// recover after a `turn/start` itself reports the thread missing.
  Future<void> _ensureThreadLoaded(
    CodexAppServerClient client,
    String threadId, {
    bool force = false,
  }) async {
    if (!force && _loadedThreads.contains(threadId)) return;
    final result = await client.request(
      method: "thread/resume",
      params: {"threadId": threadId},
    );
    _loadedThreads.add(threadId);
    final response = _threadEnvelopeFrom(result);
    _eventMapper.setThreadModel(threadId, response.model);
    _eventMapper.setThreadProvider(threadId, response.modelProvider);
    // A thread resumed from a prior bridge run never re-emits `thread/started`,
    // so learn its directory here (from the resume payload, else its rollout)
    // to keep live rename events attributed to its real project.
    final resumedCwd = response.thread?.cwd ?? response.cwd;
    _recordThreadDirectory(threadId, resumedCwd ?? _directoryForSession(threadId));
  }

  /// Whether a codex RPC error means the targeted thread is not loaded in the
  /// app-server (as opposed to a genuine bad request). codex reports this as
  /// `-32600` with a "thread not found" message; we match the message
  /// defensively so a wording tweak does not silently break the resume retry.
  bool _isThreadNotFound(CodexRpcException error) {
    final message = error.message.toLowerCase();
    return message.contains("thread not found") ||
        message.contains("no such thread") ||
        (error.code == -32600 && message.contains("not found"));
  }

  Map<String, dynamic>? _promptPartToUserInput(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => {
        "type": "text",
        "text": text,
        "text_elements": const <Object?>[],
      },
      PluginPromptPartFilePath(:final path) => {"type": "localImage", "path": path},
      PluginPromptPartFileUrl(:final url) => {"type": "image", "url": url},
      // Inline base64 isn't a codex UserInput variant; drop with a log
      // hook if/when it shows up in real traffic.
      PluginPromptPartFileData() => null,
    };
  }

  CodexThreadEnvelopeDto _threadEnvelopeFrom(Object? result) {
    if (result is! Map) {
      throw StateError("expected a Codex thread response object, got ${result.runtimeType}");
    }
    return CodexThreadEnvelopeDto.fromJson(result.cast<String, dynamic>());
  }

  PluginSessionTime? _timeFromThread(CodexThreadDto? thread) {
    if (thread == null) return null;
    final createdAtSeconds = thread.createdAt;
    final updatedAtSeconds = thread.updatedAt;
    if (createdAtSeconds == null || updatedAtSeconds == null) return null;
    return PluginSessionTime(
      created: (createdAtSeconds * 1000).round(),
      updated: (updatedAtSeconds * 1000).round(),
      archived: null,
    );
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
    await client.request(
      method: "thread/name/set",
      params: {"threadId": sessionId, "name": title},
    );
    final directory = _directoryForSession(sessionId);
    return PluginSession(
      branchName: null,
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: title,
      time: null,
    );
  }

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The normalized project directory for [sessionId]: the in-memory directory
  /// learned when the thread was started/resumed (authoritative before the
  /// rollout is flushed), then the session's rollout cwd, then the launch cwd —
  /// so a session is attributed to its real project even in the flush window.
  String _directoryForSession(String sessionId) {
    final known = _threadDirectory[sessionId];
    if (known != null) return known;
    for (final record in _rolloutReader.listSessions()) {
      if (record.id == sessionId) return normalizeProjectDirectory(directory: record.cwd ?? _projectCwd);
    }
    return normalizeProjectDirectory(directory: _projectCwd);
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
    if (_activeTurnByThread.containsKey(sessionId)) {
      try {
        await abortSession(sessionId: sessionId);
      } catch (_) {
        // Continue with delete even if the abort raced.
      }
    }
    _rolloutReader.deleteSession(sessionId);
    _activeTurnByThread.remove(sessionId);
    _sessionStatuses.remove(sessionId);
    _loadedThreads.remove(sessionId);
    _threadDirectory.remove(sessionId);
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
  ) async {
    final path = _rolloutReader.findRolloutPath(sessionId);
    if (path == null) return const [];
    return _rolloutReader.readMessages(
      path,
      sessionId,
      config: _configReader.readDefaults(),
    );
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    final (:modelID, :providerID) = _metadataRepository.resolveModelDefaults(projectId: projectId);
    return [
      PluginAgent(
        name: "codex",
        description: "Codex CLI session",
        model: modelID == null
            ? null
            : PluginAgentModel(
                modelID: modelID,
                providerID: providerID,
                variant: null,
              ),
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
    final (:modelID, :providerID) = _metadataRepository.resolveModelDefaults(projectId: projectId);

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
        final defaultModelID = _metadataRepository.selectCatalogDefaultModel(
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
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => const [];

  @override
  Future<void> dispose() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _approvalRegistry?.dispose();
    _approvalRegistry = null;
    await _client?.dispose();
    _client = null;
    await _eventBuffer.close();
  }
}
