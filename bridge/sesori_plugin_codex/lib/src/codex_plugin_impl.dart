import "dart:async";
import "dart:io" show Directory;

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "codex_event_mapper.dart";
import "codex_skill_reader.dart";
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
  final CodexSkillReader _skillReader;
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

  factory CodexPlugin({
    required String serverUrl,
    String? capabilityToken,
    CodexAppServerClient Function()? clientFactory,
    SessionRolloutReader? rolloutReader,
    CodexConfigReader? configReader,
    CodexSkillReader? skillReader,
    CodexEventMapper? eventMapper,
    String? projectCwd,
    void Function()? onConnected,
    void Function()? onDisconnected,
    Duration keepaliveInterval = const Duration(seconds: 30),
  }) {
    final resolvedProjectCwd = projectCwd ?? Directory.current.path;
    final resolvedConfigReader = configReader ?? CodexConfigReader();
    return CodexPlugin._(
      serverUrl: serverUrl,
      capabilityToken: capabilityToken,
      // When null, [_ensureConnected] builds the default client so it can wire
      // the client's `onDisconnected` through [_handleClientDisconnected].
      clientFactory: clientFactory,
      rolloutReader: rolloutReader ?? SessionRolloutReader(),
      configReader: resolvedConfigReader,
      skillReader:
          skillReader ?? CodexSkillReader(projectCwd: resolvedProjectCwd),
      eventMapper:
          eventMapper ??
          CodexEventMapper(
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
    required CodexSkillReader skillReader,
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
       _skillReader = skillReader,
       _eventMapper = eventMapper,
       _projectCwd = projectCwd,
       _onConnected = onConnected,
       _onDisconnected = onDisconnected,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  String get serverUrl => _serverUrl;

  @override
  String get id => "codex";

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
      respond: (id, result) =>
          client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) =>
          client.respondToServerRequestWithError(
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
      client
          .request(method: "model/list", timeout: _keepaliveInterval)
          .catchError((Object _) => null),
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

  PluginProject _synthesizedProject() {
    final updated = DateTime.now().millisecondsSinceEpoch;
    return PluginProject(
      id: _projectCwd,
      name: p.basename(_projectCwd).isEmpty
          ? _projectCwd
          : p.basename(_projectCwd),
      time: PluginProjectTime(created: updated, updated: updated),
    );
  }

  @override
  Future<List<PluginProject>> getProjects() async => [_synthesizedProject()];

  @override
  Future<PluginProject> getProject(String projectId) async =>
      _synthesizedProject();

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final records = _rolloutReader.listSessions();
    final filtered = records.where((r) => r.cwd == projectId);
    final mapped = filtered.map(_toPluginSession).toList(growable: false);
    final from = start ?? 0;
    final until = limit == null
        ? mapped.length
        : (from + limit).clamp(0, mapped.length);
    if (from >= mapped.length) return const [];
    return mapped.sublist(from, until);
  }

  PluginSession _toPluginSession(CodexSessionRecord record) {
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    return PluginSession(
      id: record.id,
      projectID: _projectCwd,
      directory: record.cwd ?? _projectCwd,
      parentID: null,
      title: record.threadName,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
      summary: null,
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({
    required String? projectId,
  }) async {
    final skills = _skillReader.list();
    return [
      for (final skill in skills)
        PluginCommand(
          name: skill.name,
          description: skill.description.isEmpty ? null : skill.description,
          source: PluginCommandSource.skill,
          provider: null,
        ),
    ];
  }

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
    final thread = _extractThread(result);
    final threadId = thread?["id"] as String?;
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
      (result is Map ? result["model"] as String? : null) ?? model?.modelID,
    );
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
      id: threadId,
      projectID: _projectCwd,
      directory: (thread?["cwd"] as String?) ?? directory,
      parentID: parentSessionId,
      title: thread?["name"] as String?,
      time: _timeFromThread(thread),
      summary: null,
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
    if (result is Map) {
      _eventMapper.setThreadModel(threadId, result["model"] as String?);
      _eventMapper.setThreadProvider(threadId, result["modelProvider"] as String?);
    }
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

  Map<String, dynamic>? _extractThread(Object? result) {
    if (result is! Map) return null;
    final map = result.cast<String, dynamic>();
    final thread = map["thread"];
    if (thread is! Map) return null;
    return thread.cast<String, dynamic>();
  }

  PluginSessionTime? _timeFromThread(Map<String, dynamic>? thread) {
    if (thread == null) return null;
    final createdAtSeconds = thread["createdAt"];
    final updatedAtSeconds = thread["updatedAt"];
    if (createdAtSeconds is! num || updatedAtSeconds is! num) return null;
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
    return PluginSession(
      id: sessionId,
      projectID: _projectCwd,
      directory: _projectCwd,
      parentID: null,
      title: title,
      time: null,
      summary: null,
    );
  }

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    // The codex backend uses a single synthesised project per launch CWD,
    // so there is no per-project name to persist. Honour the contract by
    // returning a project with the requested name applied so any local
    // UI cache stays consistent.
    final base = _synthesizedProject();
    return PluginProject(id: base.id, name: name, time: base.time);
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
    // codex-cli 0.139.0's rollout headers do not record a parent/`forked_from`
    // link, so we have no way to reconstruct the parent→child relationship from
    // disk. Until codex surfaces it, return empty — the bridge contract
    // treats this as "no children known", not as an error.
    return const [];
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async =>
      Map.unmodifiable(_sessionStatuses);

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
    final (:modelID, :providerID) = _resolveModelDefaults();
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

  /// Resolves the configured model/provider for codex.
  ///
  /// Codex exposes no agent/provider API, so we derive it from local state:
  /// the most recent session's rollout (per-session accurate) wins, then the
  /// global `config.toml`, then `openai` as a last-resort provider.
  ({String? modelID, String providerID}) _resolveModelDefaults() {
    final config = _configReader.readDefaults();
    final sessions = _rolloutReader.listSessions();
    final latest = sessions.isEmpty ? null : sessions.first;
    return (
      modelID: latest?.model ?? config.model,
      providerID: latest?.modelProvider ?? config.modelProvider ?? "openai",
    );
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
  }) async =>
      _approvalRegistry?.pendingForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return const [];
    // Single-project model: every codex session belongs to the launch
    // project. Pull every known session id we've seen.
    final sessionIds = _sessionStatuses.keys.toList(growable: false);
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
    final (:modelID, :providerID) = _resolveModelDefaults();

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
        return PluginProvidersResult(
          providers: [
            PluginProvider.custom(
              id: providerID,
              name: _providerDisplayName(providerID),
              authType: PluginProviderAuthType.unknown,
              models: pluginModels,
              defaultModelID: defaultId ?? modelID ?? pluginModels.first.id,
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
