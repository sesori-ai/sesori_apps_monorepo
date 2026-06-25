import "dart:async";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_approval_registry.dart";
import "acp_event_mapper.dart";
import "acp_process_factory.dart";
import "acp_project_registry.dart";
import "acp_protocol.dart";
import "acp_session_loader.dart";
import "acp_stdio_client.dart";

/// Base [BridgePluginApi] implementation for any ACP (Agent Client Protocol)
/// agent driven over stdio.
///
/// Concrete so a vanilla ACP harness needs only an [id] + [agentDisplayName]
/// (the "config row" case). Harnesses with quirks (e.g. Cursor's model
/// selection and `cursor/*` extensions) subclass and override the hooks:
/// [buildApprovalRegistry], [applyModelSelection], [authMethodId],
/// [initializeCapabilityMeta], [getAgents], [getProviders].
///
/// Unlike the codex plugin (which connects to a process listening on a ws
/// port), this owns the agent subprocess: it spawns lazily on first use and
/// reaps it on [dispose].
class AcpPlugin implements BridgePluginApi {
  AcpPlugin({
    required this.id,
    required this.agentDisplayName,
    required this.launchSpec,
    required this.projectCwd,
    required this.eventMapper,
    AcpProcessFactory? processFactory,
    HostJsonStore? projectStore,
  }) : _processFactory = processFactory,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>(),
       _projects = AcpProjectRegistry(cwd: projectCwd, store: projectStore);

  @override
  final String id;

  /// Human-facing agent name used for synthesized agents/providers.
  final String agentDisplayName;

  final AcpLaunchSpec launchSpec;

  /// Bridge launch CWD — the implicit default project (always present in the
  /// [_projects] registry, even before any directory is explicitly opened).
  final String projectCwd;

  /// The live event mapper (subclasses may pass a specialized one).
  final AcpEventMapper eventMapper;

  final AcpProcessFactory? _processFactory;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;

  /// Persistent set of directories opened as projects (seeded with
  /// [projectCwd]). ACP agents have no project list of their own — each session
  /// just carries a `cwd` — so the plugin tracks them here and persists across
  /// restarts via the host JSON store.
  final AcpProjectRegistry _projects;

  /// sessionId -> the canonical project id (directory) the session belongs to.
  /// Populated on create, on `session/list`, and lets a turn/history load use
  /// the session's own `cwd` (not the launch CWD) and the activity summary be
  /// grouped under the right project.
  final Map<String, String> _sessionProjects = {};

  AcpStdioClient? _client;
  Future<bool>? _connectFuture;
  StreamSubscription<AcpNotification>? _notificationSubscription;
  AcpApprovalRegistry? _approvalRegistry;
  AcpInitializeResult? _initResult;

  /// Emits after each successful (re)connect — including a lazy reconnect that
  /// follows [resetConnectionAfterExit] — so the lifecycle wrapper can re-arm
  /// its exit watch on the new client and flip back to ready. Broadcast (no
  /// buffering): the initial connect, driven by the wrapper directly, is not a
  /// subscriber so it is not double-handled.
  final StreamController<void> _connected = StreamController<void>.broadcast();
  Stream<void> get onConnected => _connected.stream;

  final Map<String, PluginSessionStatus> _sessionStatuses = {};
  final Set<String> _activeSessions = {};

  /// The session whose turn was most recently dispatched. Used to attribute a
  /// mid-turn server request that carries no `sessionId` of its own (see
  /// [AcpApprovalRegistry.resolveSessionId]). Kept as last-known rather than
  /// cleared at turn end so a request landing on the turn boundary still
  /// resolves to the right conversation.
  String? _activeTurnSessionId;

  /// The session whose turn was most recently dispatched, or null before the
  /// first turn. Exposed so an approval registry can resolve a sessionId-less
  /// server request to the active conversation.
  String? get activeTurnSessionId => _activeTurnSessionId;

  /// Sessions resident in the live agent process (created via `session/new` or
  /// resumed via `session/load` this run). ACP agents hold sessions in memory
  /// per process, so a session from a prior bridge run must be re-loaded before
  /// a turn or the agent rejects it ("session not found").
  final Set<String> _residentSessions = {};

  /// Sessions whose `session/update` notifications are currently dropped — a
  /// resume `session/load` is in flight and its history replay must not leak
  /// into the live stream.
  final Set<String> _suppressedSessions = {};
  int _suppressedReplayCount = 0;

  // --- Overridable hooks ---

  String get clientName => "sesori-bridge";
  String get clientVersion => "0.0.0";

  /// Auth method id to call if the agent reports it requires auth. `null`
  /// uses the first advertised method.
  String? get authMethodId => null;

  /// Non-standard capability hints sent under `clientCapabilities._meta`
  /// (e.g. Cursor's `parameterizedModelPicker`).
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  /// Builds the approval registry. Override to return a harness-specific
  /// subclass (e.g. one that also handles `cursor/ask_question`).
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return AcpApprovalRegistry.forClient(client: client, emit: _eventBuffer.add);
  }

  /// Captures the model/mode catalog from a `session/new` or `session/load`
  /// result (config-option ids, available models/modes, current values) and
  /// seeds the event mapper's fallback model. When [sessionId] is known, the
  /// session's current model is recorded for per-message stamping. Base does
  /// nothing; Cursor overrides for its `configOptions` picker.
  void captureSessionConfig(Map<String, dynamic> result, {String? sessionId}) {}

  /// Applies the requested [model] and [variant] for a turn on [sessionId]
  /// before the prompt is dispatched. Called from [createSession] and from
  /// [sendPrompt]/[sendCommand], so a mid-conversation switch takes effect.
  /// Base does nothing (the agent's defaults are used). Cursor overrides to
  /// drive its model + mode `session/set_config_option` calls.
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {}

  // --- Protected accessors for subclasses ---

  AcpStdioClient? get client => _client;
  AcpInitializeResult? get initializeResult => _initResult;
  void emitEvent(BridgeSseEvent event) => _eventBuffer.add(event);

  // --- BridgePluginApi ---

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  Future<bool> ensureConnected() {
    final existing = _connectFuture;
    if (existing != null) return existing;
    final future = () async {
      final client = AcpStdioClient(
        launchSpec: launchSpec,
        processFactory: _processFactory,
        logTag: id,
      );
      _client = client;
      try {
        await client.connect();
        _notificationSubscription = client.notifications.listen((notification) {
          if (notification.method == AcpMethods.sessionUpdate) {
            final sid = notification.params["sessionId"];
            if (sid is String && _suppressedSessions.contains(sid)) {
              // Replay from an in-flight resume-load — drop so old history does
              // not re-stream into the live conversation.
              _suppressedReplayCount++;
              return;
            }
          }
          eventMapper.map(notification).forEach(_eventBuffer.add);
        });
        final registry = buildApprovalRegistry(client);
        _approvalRegistry = registry;
        registry.attach(client.serverRequests);
        _initResult = await _initialize(client);
        if (!_connected.isClosed) _connected.add(null);
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

  /// Runs the ACP `initialize` handshake (and `authenticate` if the agent
  /// advertises an auth method) on [client], returning the parsed result. Does
  /// not store it — the caller decides (the live connect persists it as
  /// [_initResult]; the replay client in [getSessionMessages] keeps it local so
  /// it never clobbers the live capabilities).
  Future<AcpInitializeResult> _initialize(AcpStdioClient client) async {
    final raw = await client.request(
      method: AcpMethods.initialize,
      params: buildInitializeParams(
        clientName: clientName,
        clientVersion: clientVersion,
        capabilityMeta: initializeCapabilityMeta,
      ),
    );
    final init = AcpInitializeResult.fromJson(
      (raw as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (init.requiresAuth) {
      final methodId = authMethodId ??
          (init.authMethods.isNotEmpty ? init.authMethods.first.id : null);
      if (methodId != null) {
        await client.request(
          method: AcpMethods.authenticate,
          params: {"methodId": methodId},
        );
      }
    }
    return init;
  }

  Future<AcpStdioClient> _connectedClient() async {
    final ok = await ensureConnected();
    final client = _client;
    if (!ok || client == null) {
      throw StateError("$id agent is not connected");
    }
    return client;
  }

  /// Tears down the cached ACP connection after the agent subprocess exits, so
  /// the next [ensureConnected] spawns a fresh agent instead of writing to the
  /// dead process. The lifecycle wrapper calls this from its exit watch when an
  /// unexpected exit flips the plugin to degraded; without it the cached
  /// `_connectFuture`/`_client` keep reporting a successful connection and
  /// requests are written to the exited process until they fail or time out.
  ///
  /// Resident sessions are forgotten: the replacement process holds no sessions
  /// until they are re-created or resumed via `session/load`. The event channel
  /// and project registry are left intact — the plugin stays alive, only the
  /// connection is reset. Never throws.
  Future<void> resetConnectionAfterExit() async {
    _connectFuture = null;
    _initResult = null;
    _residentSessions.clear();
    final sub = _notificationSubscription;
    _notificationSubscription = null;
    final registry = _approvalRegistry;
    _approvalRegistry = null;
    final client = _client;
    _client = null;
    try {
      await sub?.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel notification subscription on reset", e, st);
    }
    try {
      await registry?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose approval registry on reset", e, st);
    }
    try {
      await client?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose client on reset", e, st);
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return await ensureConnected();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PluginProject>> getProjects() async {
    await _projects.ensureLoaded();
    return _projects.list();
  }

  /// Returns the project for [projectId], registering it as a known project.
  ///
  /// This is the `POST /project/open` ("open a directory as a project") path as
  /// well as the per-project metadata lookup, so opening a new directory adds it
  /// to [getProjects]. Registration is idempotent for an already-known project.
  @override
  Future<PluginProject> getProject(String projectId) async {
    final id = await _projects.register(projectId);
    return _projects.projectFor(id);
  }

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final client = await _connectedClient();
    if (!(_initResult?.agentCapabilities.listSessions ?? false)) return const [];
    try {
      final raw = await client.request(
        method: "session/list",
        params: {"cwd": projectId},
      );
      final map = (raw as Map?)?.cast<String, dynamic>() ?? const {};
      final sessions = (map["sessions"] as List?) ?? const [];
      final mapped = sessions
          .whereType<Map<dynamic, dynamic>>()
          .map((s) => _toPluginSession(s.cast<String, dynamic>(), projectId))
          .toList(growable: false);
      final from = start ?? 0;
      if (from >= mapped.length) return const [];
      final until =
          limit == null ? mapped.length : (from + limit).clamp(0, mapped.length);
      return mapped.sublist(from, until);
    } catch (_) {
      return const [];
    }
  }

  PluginSession _toPluginSession(Map<String, dynamic> raw, String projectId) {
    final updated = raw["updatedAt"];
    final ts = updated is num ? updated.round() : null;
    final id = (raw["sessionId"] ?? "") as String;
    // Remember which project this session belongs to so a later turn/history
    // load uses its own cwd and the activity badge lands on the right project.
    if (id.isNotEmpty) {
      _sessionProjects[id] = projectId;
      eventMapper.setSessionProject(id, projectId);
    }
    return PluginSession(
      id: id,
      projectID: projectId,
      directory: (raw["cwd"] as String?) ?? projectId,
      parentID: null,
      title: raw["title"] as String?,
      time: ts == null
          ? null
          : PluginSessionTime(created: ts, updated: ts, archived: null),
      summary: null,
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      const [];

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
    // The directory is a project the session lives in — make sure it is a known
    // project (the app normally creates sessions in an already-opened project,
    // but a session created directly should still surface its directory).
    final projectId = await _projects.register(directory);
    final raw = await client.request(
      method: AcpMethods.sessionNew,
      params: {"cwd": directory, "mcpServers": const <Object?>[]},
    );
    final session = AcpNewSessionResult.fromJson(
      (raw as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (session.sessionId.isEmpty) {
      throw StateError("session/new response missing sessionId");
    }
    _sessionProjects[session.sessionId] = projectId;
    eventMapper.setSessionProject(session.sessionId, projectId);
    captureSessionConfig(session.raw, sessionId: session.sessionId);
    // session/new leaves the session resident in the agent process.
    _residentSessions.add(session.sessionId);
    await applyTurnSelection(
      client: client,
      sessionId: session.sessionId,
      model: model,
      variant: variant,
    );
    _sessionStatuses[session.sessionId] = const PluginSessionStatus.idle();
    if (parts.isNotEmpty) {
      _dispatchPrompt(client, session.sessionId, parts);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return PluginSession(
      id: session.sessionId,
      projectID: projectId,
      directory: directory,
      parentID: parentSessionId,
      title: null,
      time: PluginSessionTime(created: now, updated: now, archived: null),
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
    await _ensureResident(client, sessionId);
    await applyTurnSelection(
      client: client,
      sessionId: sessionId,
      model: model,
      variant: variant,
    );
    _dispatchPrompt(client, sessionId, parts);
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
    final body = arguments.isEmpty ? "/$command" : "/$command $arguments";
    final client = await _connectedClient();
    await _ensureResident(client, sessionId);
    await applyTurnSelection(
      client: client,
      sessionId: sessionId,
      model: model,
      variant: variant,
    );
    _dispatchPrompt(client, sessionId, [PluginPromptPart.text(text: body)]);
  }

  /// Ensures [sessionId] is resident in the agent process before a turn. A
  /// session created/resumed this run is already resident; one from a prior
  /// bridge run is re-loaded via `session/load` (its history replay suppressed
  /// so it does not re-stream into the live conversation). Best-effort: on a
  /// failed/unsupported load the session is still marked resident so the turn
  /// proceeds and surfaces any error itself, rather than looping.
  /// The directory a session should be loaded/operated in — its own project's
  /// cwd when known, else the launch CWD.
  String _sessionCwd(String sessionId) => _sessionProjects[sessionId] ?? projectCwd;

  Future<void> _ensureResident(AcpStdioClient client, String sessionId) async {
    if (_residentSessions.contains(sessionId)) return;
    if (!(_initResult?.agentCapabilities.loadSession ?? false)) {
      _residentSessions.add(sessionId);
      return;
    }
    _suppressedSessions.add(sessionId);
    try {
      final raw = await client.request(
        method: AcpMethods.sessionLoad,
        params: {
          "sessionId": sessionId,
          "cwd": _sessionCwd(sessionId),
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      captureSessionConfig(
        (raw as Map?)?.cast<String, dynamic>() ?? const {},
        sessionId: sessionId,
      );
      // Keep suppressing until the (post-response) replay stream goes quiet.
      await _drainReplay(() => _suppressedReplayCount);
    } catch (error, stack) {
      Log.w("[$id] resume-load of $sessionId failed; proceeding", error, stack);
    } finally {
      _suppressedSessions.remove(sessionId);
      _residentSessions.add(sessionId);
    }
  }

  /// Sends a prompt turn fire-and-forget: marks the session busy now, streams
  /// events via the notification listener, and flips to idle when the
  /// `session/prompt` future resolves (ACP carries no turn-complete event).
  void _dispatchPrompt(
    AcpStdioClient client,
    String sessionId,
    List<PluginPromptPart> parts,
  ) {
    final blocks = parts
        .map(_promptPartToContentBlock)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (blocks.isEmpty) return;

    // Remember the session whose turn is now in flight. Server requests that
    // arrive mid-turn without their own sessionId (e.g. Cursor's
    // `cursor/create_plan`) are attributed to it via [activeTurnSessionId].
    _activeTurnSessionId = sessionId;
    eventMapper.beginTurn(sessionId);
    _sessionStatuses[sessionId] = const PluginSessionStatus.busy();
    _eventBuffer.add(
      BridgeSseSessionStatus(
        sessionID: sessionId,
        status: const shared.SessionStatus.busy().toJson(),
      ),
    );

    final future = client.request(
      method: AcpMethods.sessionPrompt,
      params: {"sessionId": sessionId, "prompt": blocks},
      timeout: const Duration(minutes: 30),
    );
    _activeSessions.add(sessionId);
    unawaited(
      future.then((raw) {
        final result = AcpPromptResult.fromJson(
          (raw as Map?)?.cast<String, dynamic>() ?? const {},
        );
        _onTurnEnd(sessionId, result.stopReason);
      }).catchError((Object _) {
        _onTurnEnd(sessionId, AcpStopReason.unknown);
      }),
    );
  }

  void _onTurnEnd(String sessionId, AcpStopReason reason) {
    _activeSessions.remove(sessionId);
    _sessionStatuses[sessionId] = const PluginSessionStatus.idle();
    _eventBuffer.add(BridgeSseSessionIdle(sessionID: sessionId));
    if (reason == AcpStopReason.refusal) {
      _eventBuffer.add(BridgeSseSessionError(sessionID: sessionId));
    }
  }

  Map<String, dynamic>? _promptPartToContentBlock(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => textContentBlock(text),
      PluginPromptPartFilePath(:final path, :final filename) => {
        "type": "resource_link",
        "uri": "file://$path",
        "name": filename ?? p.basename(path),
      },
      PluginPromptPartFileUrl(:final url, :final filename) => {
        "type": "resource_link",
        "uri": url,
        "name": filename ?? url,
      },
      // Inline base64 has no clean ACP ContentBlock without a mime contract;
      // dropped until a real trace shows the expected shape.
      PluginPromptPartFileData() => null,
    };
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    final client = _client;
    if (client == null) return;
    client.notify(
      method: AcpMethods.sessionCancel,
      params: {"sessionId": sessionId},
    );
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    // ACP has no standard rename; honour the contract optimistically so any
    // local UI cache stays consistent. The mobile DB is authoritative.
    final cwd = _sessionCwd(sessionId);
    return PluginSession(
      id: sessionId,
      projectID: cwd,
      directory: cwd,
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
    await _projects.rename(path: projectId, name: name);
    return _projects.projectFor(projectId);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (_activeSessions.contains(sessionId)) {
      await abortSession(sessionId: sessionId);
    }
    _activeSessions.remove(sessionId);
    _sessionStatuses.remove(sessionId);
    _residentSessions.remove(sessionId);
    _sessionProjects.remove(sessionId);
    eventMapper.setSessionProject(sessionId, null);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    // Best-effort — mobile DB archive state is authoritative.
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    // ACP agents don't manage worktrees.
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async =>
      const [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async =>
      Map.unmodifiable(_sessionStatuses);

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async {
    // History via `session/load` replay on a dedicated short-lived client so
    // replayed updates don't interleave with the live session's stream.
    final replayClient = AcpStdioClient(
      launchSpec: launchSpec,
      processFactory: _processFactory,
      logTag: "$id-replay",
    );
    final collector = AcpReplayCollector(
      sessionId: sessionId,
      agentId: agentDisplayName,
      modelId: eventMapper.modelForSession(sessionId),
      providerId: eventMapper.providerForSession(sessionId),
    );
    StreamSubscription<AcpNotification>? sub;
    try {
      await replayClient.connect();
      final replayInit = await _initialize(replayClient);
      if (!replayClient.isConnected || !replayInit.agentCapabilities.loadSession) {
        return const [];
      }
      var received = 0;
      sub = replayClient.notifications.listen((notification) {
        if (notification.method == AcpMethods.sessionUpdate) {
          received++;
          collector.consume(notification.params);
        }
      });
      final raw = await replayClient.request(
        method: AcpMethods.sessionLoad,
        params: {
          "sessionId": sessionId,
          "cwd": _sessionCwd(sessionId),
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      // The load result also carries the model/mode catalog (and the loaded
      // session's current model) — capture it so the picker is populated and
      // replayed messages are stamped with the session's real model.
      captureSessionConfig(
        (raw as Map?)?.cast<String, dynamic>() ?? const {},
        sessionId: sessionId,
      );
      // The ACP spec replays the whole thread via `session/update` BEFORE the
      // `session/load` response resolves, but cursor-agent streams later turns
      // AFTER it. Drain until the replay stream goes quiet so multi-turn history
      // is captured in full, bounded so a chatty agent can't hang the request.
      await _drainReplay(() => received);
      collector.modelId = eventMapper.modelForSession(sessionId);
      collector.providerId = eventMapper.providerForSession(sessionId);
      return collector.build();
    } catch (_) {
      return const [];
    } finally {
      try {
        await sub?.cancel();
      } on Object catch (e, st) {
        Log.w("[$id] failed to cancel replay subscription", e, st);
      }
      try {
        await replayClient.dispose();
      } on Object catch (e, st) {
        Log.w("[$id] failed to dispose replay client", e, st);
      }
    }
  }

  /// Waits until the replay `session/update` stream goes quiet — no new
  /// notification within one [quiet] window — bounded by [max]. [count] returns
  /// the running number of replay notifications seen so far.
  Future<void> _drainReplay(
    int Function() count, {
    Duration quiet = const Duration(milliseconds: 250),
    Duration max = const Duration(seconds: 6),
  }) async {
    var elapsed = Duration.zero;
    var last = -1;
    while (elapsed < max) {
      final snapshot = count();
      if (snapshot == last) return;
      last = snapshot;
      await Future<void>.delayed(quiet);
      elapsed += quiet;
    }
  }

  /// Populates the config catalog (models/modes) by `session/load`-ing the most
  /// recent existing session on a short-lived client and feeding the result to
  /// [captureSessionConfig]. Reads the catalog from the load *result*, so it
  /// never pollutes the live event stream with replayed history, and — unlike
  /// a `session/new` probe — creates no throwaway session (the ACP agents this
  /// drives have no session-delete). No-op when there are no existing sessions
  /// (a brand-new account's first `session/new` populates the catalog instead).
  Future<void> probeCatalogFromExistingSession() async {
    if (_client == null) return;
    // The catalog (models/modes) is account-global, so ANY existing session is a
    // valid source. `session/list` is cwd-scoped, and the launch cwd is often a
    // fresh directory with no history while other opened projects do have
    // sessions — so scan every known project's cwd and load the newest session
    // found (using its own cwd). Scanning the launch cwd alone would leave the
    // catalog empty, and the model picker blank, whenever the bridge starts in a
    // directory that has never hosted a session.
    await _projects.ensureLoaded();
    final cwds = <String>{
      projectCwd,
      for (final project in _projects.list()) project.id,
    };
    PluginSession? newest;
    for (final cwd in cwds) {
      final List<PluginSession> sessions;
      try {
        sessions = await getSessions(cwd);
      } catch (_) {
        continue;
      }
      for (final session in sessions) {
        if (session.id.isEmpty) continue;
        if (newest == null || _sessionRecency(session) > _sessionRecency(newest)) {
          newest = session;
        }
      }
    }
    if (newest == null) return;
    final probe = AcpStdioClient(
      launchSpec: launchSpec,
      processFactory: _processFactory,
      logTag: "$id-probe",
    );
    try {
      await probe.connect();
      final init = await _initialize(probe);
      if (!init.agentCapabilities.loadSession) return;
      final raw = await probe.request(
        method: AcpMethods.sessionLoad,
        params: {
          "sessionId": newest.id,
          "cwd": newest.directory,
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 1),
      );
      captureSessionConfig((raw as Map?)?.cast<String, dynamic>() ?? const {});
    } catch (error, stack) {
      Log.d("[$id] catalog probe failed: $error\n$stack");
    } finally {
      await probe.dispose();
    }
  }

  /// Recency key for picking the freshest session as the catalog source. A
  /// missing timestamp sorts oldest — any session is a valid catalog source, so
  /// falling back to 0 just means "no better candidate than first-seen".
  static int _sessionRecency(PluginSession session) =>
      session.time?.updated ?? session.time?.created ?? 0;

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    final modelId = eventMapper.currentModelId;
    return [
      PluginAgent(
        name: id,
        description: "$agentDisplayName session",
        model: modelId == null
            ? null
            : PluginAgentModel(
                modelID: modelId,
                providerID: eventMapper.currentProviderId ?? id,
                variant: null,
              ),
        mode: PluginAgentMode.primary,
        hidden: false,
      ),
    ];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    final modelId = eventMapper.currentModelId;
    if (modelId == null) return const PluginProvidersResult(providers: []);
    final providerId = eventMapper.currentProviderId ?? id;
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: providerId,
          name: agentDisplayName,
          authType: PluginProviderAuthType.unknown,
          models: [
            PluginModel(
              id: modelId,
              name: modelId,
              variants: const [],
              family: null,
              isAvailable: true,
              releaseDate: null,
            ),
          ],
          defaultModelID: modelId,
        ),
      ],
    );
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async =>
      _approvalRegistry?.pendingForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async =>
      _approvalRegistry?.pendingPermissionsForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return const [];
    return registry.pendingForProject(_sessionStatuses.keys);
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    _approvalRegistry?.replyQuestion(questionId, answers);
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    // The registry is keyed by the bridge question id; it already knows the
    // session (and clears the pending entry, so awaiting-input drops), so the
    // sessionId argument is not needed here.
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
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final registry = _approvalRegistry;

    // Surface a session only when it has live activity: the agent is running
    // (a `session/prompt` turn is in flight) or it is blocked awaiting a user
    // answer/permission. Idle sessions are not "active" and are dropped, which
    // also means a fully idle agent yields an empty summary (no project row) —
    // matching the OpenCode plugin's "only active worktrees" contract.
    //
    // ACP sessions are flat: this plugin tracks no parent/child relationships,
    // so `childSessionIds` is always empty, and it has no retry concept, so
    // `isRetrying` is always false.
    // Group active sessions under the project (directory) each belongs to, so
    // the per-project activity badge lands on the right project — sessions can
    // live in different opened directories, not just the launch CWD.
    final byProject = <String, List<PluginActiveSession>>{};
    for (final sessionId in _sessionStatuses.keys) {
      final running = _activeSessions.contains(sessionId);
      final awaiting = registry?.hasPendingInput(sessionId) ?? false;
      if (!running && !awaiting) continue;
      (byProject[_sessionCwd(sessionId)] ??= []).add(
        PluginActiveSession(
          id: sessionId,
          mainAgentRunning: running,
          awaitingInput: awaiting,
          isRetrying: false,
          childSessionIds: const [],
        ),
      );
    }
    if (byProject.isEmpty) return const [];

    return [
      for (final entry in byProject.entries)
        PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  @override
  Future<void> dispose() async {
    // Each teardown step is isolated so a failure in one (e.g. a hung
    // subscription) cannot skip a later one (e.g. reaping the agent
    // subprocess). dispose() must not throw — log and continue.
    try {
      await _notificationSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel notification subscription", e, st);
    } finally {
      _notificationSubscription = null;
    }
    try {
      await _approvalRegistry?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose approval registry", e, st);
    } finally {
      _approvalRegistry = null;
    }
    try {
      await _client?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose client", e, st);
    } finally {
      _client = null;
    }
    try {
      await _eventBuffer.close();
    } on Object catch (e, st) {
      Log.w("[$id] failed to close event buffer", e, st);
    }
    try {
      await _connected.close();
    } on Object catch (e, st) {
      Log.w("[$id] failed to close connected stream", e, st);
    }
  }
}
