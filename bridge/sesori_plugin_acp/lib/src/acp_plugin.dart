import "dart:async";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_approval_registry.dart";
import "acp_event_mapper.dart";
import "acp_process_factory.dart";
import "acp_protocol.dart";
import "acp_session_loader.dart";
import "acp_stdio_client.dart";

/// Base [BridgeDerivedProjectsPluginApi] implementation for any ACP (Agent
/// Client Protocol) agent driven over stdio.
///
/// ACP backends have no project concept — each session just carries a `cwd` —
/// so the bridge derives the project list from [listAllSessions] and owns all
/// project/session persistence itself; the plugin stores nothing on disk.
///
/// Concrete so a vanilla ACP harness needs only an [id] + [agentDisplayName]
/// (the "config row" case). Harnesses with quirks (e.g. Cursor's model
/// selection and `cursor/*` extensions) subclass and override the hooks:
/// [buildApprovalRegistry], [applyTurnSelection], [authMethodId],
/// [initializeCapabilityMeta], [getAgents], [getProviders].
///
/// Unlike the codex plugin (which connects to a process listening on a ws
/// port), this owns the agent subprocess: it spawns lazily on first use and
/// reaps it on [dispose].
class AcpPlugin extends BridgeDerivedProjectsPluginApi {
  AcpPlugin({
    required this.id,
    required this.agentDisplayName,
    required this.launchSpec,
    required String launchDirectory,
    required this.eventMapper,
    AcpProcessFactory? processFactory,
  }) : launchDirectory = normalizeProjectDirectory(directory: launchDirectory),
       _processFactory = processFactory,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  @override
  final String id;

  /// Human-facing agent name used for synthesized agents/providers.
  final String agentDisplayName;

  final AcpLaunchSpec launchSpec;

  /// Bridge launch CWD (canonicalized) — the directory the bridge seeds as an
  /// always-present project, and the fallback attribution for sessions whose
  /// own directory is unknown.
  @override
  final String launchDirectory;

  /// The live event mapper (subclasses may pass a specialized one).
  final AcpEventMapper eventMapper;

  final AcpProcessFactory? _processFactory;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;

  /// sessionId -> the canonical directory the session lives in. Populated on
  /// create and on every `session/list` hit, so a turn/history load runs in
  /// the session's own `cwd` (not the launch directory), events attribute to
  /// the right project, and the activity summary groups correctly. In-memory
  /// only: the bridge's stored rows are the durable attribution.
  final Map<String, String> _sessionDirectories = {};

  /// Every canonical directory the bridge has hinted at this run (see
  /// [listAllSessions]). Internal enumerations that have no hints of their own
  /// — the pre-resume warm-up, the catalog probe — scan these too, so a
  /// never-enumerated prior-run session in a bridge-known directory is still
  /// discoverable when the agent lacks the unfiltered `session/list` form.
  final Set<String> _hintedDirectories = {};

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

  /// Whether this connection's agent rejected an *unfiltered* `session/list`
  /// (the ACP spec's global enumeration — `cwd` is only a filter). Remembered
  /// per connection so a non-compliant agent is asked once, not on every
  /// enumeration; reset on respawn since a replacement process may comply.
  bool _bareSessionListUnsupported = false;

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
  /// session's current model is recorded for per-message stamping.
  ///
  /// [fromNewSession] distinguishes a `session/new` response — the only source
  /// that carries the backend's *new-session default* model/mode — from a
  /// `session/load` (resume, history replay, catalog probe), which replays some
  /// existing session's own model and must never redefine the default. The
  /// `sessionId`'s presence alone can't tell them apart: a `session/new`
  /// carries a fresh id, and a catalog probe carries none. Base does nothing;
  /// Cursor overrides for its `configOptions` picker.
  void captureSessionConfig(
    Map<String, dynamic> result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {}

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

  /// Invoked when the agent subprocess is torn down for a respawn (see
  /// [resetConnectionAfterExit]). The replacement process starts with none of
  /// the prior process's applied state, so a subclass that caches process-global
  /// selections (e.g. Cursor's last-applied model/mode) MUST clear that cache
  /// here — otherwise it will skip re-applying them on the fresh agent and run a
  /// turn on the wrong model/mode. Base does nothing.
  void onConnectionReset() {}

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
      raw is Map ? raw.cast<String, dynamic>() : const {},
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
  /// is left intact — the plugin stays alive, only the connection is reset.
  /// Never throws.
  Future<void> resetConnectionAfterExit() async {
    _connectFuture = null;
    _initResult = null;
    _residentSessions.clear();
    _bareSessionListUnsupported = false;
    // Let subclasses drop any process-global state cached against the dead agent
    // (e.g. Cursor's applied model/mode) so it is re-applied on the next turn.
    onConnectionReset();
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

  /// Enumerates every session the agent will report, by unioning:
  ///
  ///  - one *unfiltered* `session/list` (per the ACP spec `cwd` is only a
  ///    filter), so sessions living in directories the bridge never recorded
  ///    (e.g. created via the agent's own CLI) still surface — matching how
  ///    codex's global rollout index behaves; and
  ///  - a `session/list {cwd}` scan per directory — the bridge's
  ///    [knownDirectories] (stored project paths and worktree paths), the
  ///    launch directory, and every directory this run has attributed a
  ///    session to — because the cwd-filtered form is the shape verified
  ///    against live cursor-agent.
  ///
  /// Fail-soft: an agent that rejects the unfiltered form is remembered for
  /// this connection and not asked again; a failed per-directory scan is
  /// logged and skipped so one bad directory cannot empty the enumeration; an
  /// unreachable agent yields `[]` so the bridge still serves its stored
  /// project rows.
  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final AcpStdioClient client;
    try {
      client = await _connectedClient();
    } on Object catch (error) {
      Log.w("[$id] listAllSessions: agent unreachable; serving no sessions", error);
      return const [];
    }
    if (!(_initResult?.agentCapabilities.listSessions ?? false)) return const [];

    _hintedDirectories.addAll({
      for (final directory in knownDirectories)
        if (directory.trim().isNotEmpty) normalizeProjectDirectory(directory: directory),
    });
    final directories = <String>{
      launchDirectory,
      ..._hintedDirectories,
      ..._sessionDirectories.values,
    };

    final sessionsById = <String, PluginSession>{};
    // Session ids whose directory came only from the launch-directory fallback
    // (the unfiltered list returned them without a `cwd`). A later cwd-scoped
    // scan that returns the same session knows its real directory, so it must
    // replace the fallback attribution rather than be dropped by dedup.
    final fallbackAttributed = <String>{};
    if (!_bareSessionListUnsupported) {
      try {
        for (final info in await _listSessionPages(client, cwd: null)) {
          if (info.sessionId.isEmpty) continue;
          sessionsById[info.sessionId] = _toPluginSession(info, fallbackDirectory: launchDirectory);
          final hasCwd = info.cwd != null && info.cwd!.trim().isNotEmpty;
          if (!hasCwd) fallbackAttributed.add(info.sessionId);
        }
      } on Object catch (error) {
        // Only a genuine "unsupported RPC" (method-not-found / invalid-params)
        // means this agent will never serve the unfiltered form — memoize that.
        // A transient failure (timeout, process-exit race, other agent error)
        // must NOT be memoized, or a one-off blip would permanently drop the
        // only path that finds sessions outside the bridge's hinted directories.
        if (error is AcpRpcException && (error.code == -32601 || error.code == -32602)) {
          _bareSessionListUnsupported = true;
          Log.d("[$id] unfiltered session/list unsupported (code ${error.code}); per-directory scans only");
        } else {
          Log.d("[$id] unfiltered session/list failed transiently; will retry next enumeration: $error");
        }
      }
    }
    for (final directory in directories) {
      try {
        for (final info in await _listSessionPages(client, cwd: directory)) {
          if (info.sessionId.isEmpty) continue;
          // A cwd-scoped hit is authoritative for the session's directory, so
          // it fills a session not seen yet AND repairs one the unfiltered
          // pass could only attribute to the launch fallback.
          if (!sessionsById.containsKey(info.sessionId) || fallbackAttributed.remove(info.sessionId)) {
            sessionsById[info.sessionId] = _toPluginSession(info, fallbackDirectory: directory);
          }
        }
      } on Object catch (error, stack) {
        Log.w("[$id] session/list failed for $directory; skipping", error, stack);
      }
    }
    return sessionsById.values.toList(growable: false);
  }

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final AcpStdioClient client;
    try {
      client = await _connectedClient();
    } on Object catch (error) {
      Log.w("[$id] getSessions: agent unreachable; serving no sessions", error);
      return const [];
    }
    if (!(_initResult?.agentCapabilities.listSessions ?? false)) return const [];
    final target = normalizeProjectDirectory(directory: projectId);
    try {
      final mapped = [
        for (final info in await _listSessionPages(client, cwd: target))
          _toPluginSession(info, fallbackDirectory: target),
      ];
      final from = start ?? 0;
      if (from >= mapped.length) return const [];
      final until = limit == null ? mapped.length : (from + limit).clamp(0, mapped.length);
      return mapped.sublist(from, until);
    } on Object catch (error, stack) {
      Log.w("[$id] session/list failed for $target; serving no sessions", error, stack);
      return const [];
    }
  }

  /// Fetches the full `session/list` result for [cwd] (null = unfiltered),
  /// following `nextCursor` pagination. Bounded so an agent that never
  /// exhausts its cursor cannot spin the bridge forever.
  Future<List<AcpSessionInfo>> _listSessionPages(
    AcpStdioClient client, {
    required String? cwd,
  }) async {
    const maxPages = 50;
    final infos = <AcpSessionInfo>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final raw = await client.request(
        method: AcpMethods.sessionList,
        params: {
          "cwd": ?cwd,
          "cursor": ?cursor,
        },
      );
      final result = AcpSessionListResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      infos.addAll(result.sessions);
      final next = result.nextCursor;
      if (next == null || next.isEmpty) break;
      cursor = next;
    }
    return infos;
  }

  PluginSession _toPluginSession(AcpSessionInfo info, {required String fallbackDirectory}) {
    // The session belongs to its own cwd, canonicalized so it matches the
    // project id the bridge derives from the same value. A missing OR blank cwd
    // falls back to the directory that was scanned — the same `trim().isNotEmpty`
    // guard the caller uses to flag fallback attribution, so the two stay
    // consistent (a bare `?? ` would let `""` through to the process cwd).
    final rawCwd = info.cwd;
    final hasCwd = rawCwd != null && rawCwd.trim().isNotEmpty;
    final directory = normalizeProjectDirectory(directory: hasCwd ? rawCwd : fallbackDirectory);
    final id = info.sessionId;
    // Remember the session's directory so a later turn/history load uses its
    // own cwd and events/activity attribute to the right project.
    if (id.isNotEmpty) {
      _sessionDirectories[id] = directory;
      eventMapper.setSessionProject(id, directory);
    }
    final ts = info.updatedAtMs;
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: info.title,
      time: ts == null ? null : PluginSessionTime(created: ts, updated: ts, archived: null),
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
    // The session lives in its own cwd (for a dedicated session that is the
    // worktree path). Canonicalized so it matches the project id the bridge
    // derives from it; the bridge's stored row folds a worktree session back
    // under the project the user opened.
    final canonicalDirectory = normalizeProjectDirectory(directory: directory);
    final raw = await client.request(
      method: AcpMethods.sessionNew,
      params: {"cwd": directory, "mcpServers": const <Object?>[]},
    );
    final session = AcpNewSessionResult.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const {},
    );
    if (session.sessionId.isEmpty) {
      throw StateError("session/new response missing sessionId");
    }
    _sessionDirectories[session.sessionId] = canonicalDirectory;
    eventMapper.setSessionProject(session.sessionId, canonicalDirectory);
    // A session/new response is the authoritative source of the backend's
    // new-session default model/mode.
    captureSessionConfig(session.raw, sessionId: session.sessionId, fromNewSession: true);
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
      projectID: canonicalDirectory,
      directory: canonicalDirectory,
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

  /// The directory a session should be loaded/operated in — its own canonical
  /// directory when known, else the launch directory.
  String _directoryForSession(String sessionId) =>
      _sessionDirectories[sessionId] ?? launchDirectory;

  /// Ensures [sessionId] is resident in the agent process before a turn. A
  /// session created/resumed this run is already resident; one from a prior
  /// bridge run is re-loaded via `session/load` (its history replay suppressed
  /// so it does not re-stream into the live conversation). Best-effort: on a
  /// failed/unsupported load the session is still marked resident so the turn
  /// proceeds and surfaces any error itself, rather than looping.
  Future<void> _ensureResident(AcpStdioClient client, String sessionId) async {
    if (_residentSessions.contains(sessionId)) return;
    if (!(_initResult?.agentCapabilities.loadSession ?? false)) {
      _residentSessions.add(sessionId);
      return;
    }
    // A prior-run session may not have been enumerated yet this run (e.g. a
    // prompt issued straight from a push notification), so its directory is
    // unknown and the load below would run in the launch directory instead of
    // the session's own cwd. Enumerating warms [_sessionDirectories] as a side
    // effect — the scan covers the unfiltered list plus every bridge-hinted
    // directory seen this run ([_hintedDirectories]); fail-soft, so at worst
    // the prior fallback behaviour remains.
    if (!_sessionDirectories.containsKey(sessionId)) {
      await listAllSessions(knownDirectories: const {});
    }
    _suppressedSessions.add(sessionId);
    try {
      final raw = await client.request(
        method: AcpMethods.sessionLoad,
        params: {
          "sessionId": sessionId,
          "cwd": _directoryForSession(sessionId),
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      // A resume load: capture the catalog + this session's own model, but do
      // not let it redefine the new-session default.
      captureSessionConfig(
        raw is Map ? raw.cast<String, dynamic>() : const {},
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
      }).catchError((Object error, StackTrace stack) {
        // The frame was already accepted (the phone's send returned success),
        // so a later rejection (auth expiry, stale session, bad payload) would
        // otherwise stop the run with no signal. Log and surface it as a
        // session error, not a silent idle.
        Log.w("[$id] session/prompt for $sessionId failed after dispatch", error, stack);
        _onTurnEnd(sessionId, AcpStopReason.unknown, failed: true);
      }),
    );
  }

  void _onTurnEnd(String sessionId, AcpStopReason reason, {bool failed = false}) {
    _activeSessions.remove(sessionId);
    _sessionStatuses[sessionId] = const PluginSessionStatus.idle();
    _eventBuffer.add(BridgeSseSessionIdle(sessionID: sessionId));
    if (failed || reason == AcpStopReason.refusal) {
      _eventBuffer.add(BridgeSseSessionError(sessionID: sessionId));
    }
  }

  Map<String, dynamic>? _promptPartToContentBlock(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => textContentBlock(text),
      PluginPromptPartFilePath(:final path, :final filename) => {
        "type": "resource_link",
        // Uri.file encodes spaces and Windows drive/backslash paths; plain
        // "file://$path" interpolation emits an invalid uri (e.g.
        // `file://C:\a b.png`) that the agent rejects or ignores.
        "uri": Uri.file(path).toString(),
        "name": filename ?? p.basename(path),
      },
      PluginPromptPartFileUrl(:final url, :final filename) => {
        "type": "resource_link",
        "uri": url,
        "name": filename ?? url,
      },
      // ACP defines inline image/audio content blocks (base64 `data` +
      // `mimeType`); map those so a phone attachment is not silently lost.
      // Other mime types have no ACP inline block and are dropped.
      PluginPromptPartFileData(:final mime, :final base64) => _inlineContentBlock(mime, base64),
    };
  }

  Map<String, dynamic>? _inlineContentBlock(String mime, String base64) {
    final type = switch (mime.split("/").first.toLowerCase()) {
      "image" => "image",
      "audio" => "audio",
      _ => null,
    };
    if (type == null) return null;
    return {"type": type, "mimeType": mime, "data": base64};
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    final client = _client;
    if (client == null) return;
    client.notify(
      method: AcpMethods.sessionCancel,
      params: {"sessionId": sessionId},
    );
    // ACP requires the client to resolve any permission/question the cancelled
    // turn was blocked on; otherwise the agent keeps waiting on that JSON-RPC
    // request and the phone shows a stale prompt.
    _approvalRegistry?.cancelForSession(sessionId);
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    // ACP has no standard rename; honour the contract optimistically so any
    // local UI cache stays consistent. The mobile DB is authoritative.
    final directory = _directoryForSession(sessionId);
    return PluginSession(
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: title,
      time: null,
      summary: null,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (_activeSessions.contains(sessionId)) {
      await abortSession(sessionId: sessionId);
    }
    _activeSessions.remove(sessionId);
    _sessionStatuses.remove(sessionId);
    _residentSessions.remove(sessionId);
    _sessionDirectories.remove(sessionId);
    // Drops the session's project attribution plus all other per-session mapper
    // caches (model, turn counters, started parts, live tools) so nothing
    // accumulates for a deleted session.
    eventMapper.forgetSession(sessionId);
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
    // After a restart this replay can be the FIRST ACP call for a stored
    // worktree session (session-detail loads messages + detail in parallel,
    // and the messages handler hits the plugin directly), so its directory may
    // be unknown and the load below would run in the launch directory. Warm
    // attribution first — same fail-soft enumeration the resume path uses.
    if (!_sessionDirectories.containsKey(sessionId)) {
      await listAllSessions(knownDirectories: const {});
    }
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
          "cwd": _directoryForSession(sessionId),
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      // The load result also carries the model/mode catalog (and the loaded
      // session's current model) — capture it so the picker is populated and
      // replayed messages are stamped with the session's real model.
      captureSessionConfig(
        raw is Map ? raw.cast<String, dynamic>() : const {},
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
    } on Object catch (error, stack) {
      // A broken replay (connect/init/auth/load failure) returns no messages;
      // the phone can't tell that from a truly empty thread, so at least log
      // it rather than silently swallowing the failure.
      Log.w("[$id] history replay for $sessionId failed; returning no messages", error, stack);
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
  ///
  /// The catalog (models/modes) is account-global, so ANY existing session is
  /// a valid source. Enumeration goes through [listAllSessions] — the launch
  /// directory is often a fresh directory with no history, so callers serving
  /// a specific project pass it via [extraDirectories] to widen the scan
  /// beyond the launch directory and this run's sessions.
  Future<void> probeCatalogFromExistingSession({Set<String> extraDirectories = const {}}) async {
    if (_client == null) return;
    final sessions = await listAllSessions(knownDirectories: extraDirectories);
    PluginSession? newest;
    for (final session in sessions) {
      if (session.id.isEmpty) continue;
      if (newest == null || _sessionRecency(session) > _sessionRecency(newest)) {
        newest = session;
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
      // This loads an EXISTING session purely to populate the model/mode
      // catalog list. It must not be treated as a new-session default source,
      // or the probed session's own (possibly non-default) model would become
      // the new-session default (fromNewSession stays false).
      captureSessionConfig(raw is Map ? raw.cast<String, dynamic>() : const {});
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
    // Scope to the sessions attributed to this project so a pending question
    // in one project doesn't surface under every other. The bridge merges in
    // this plugin's worktree sessions itself via its stored attribution rows.
    final target = normalizeProjectDirectory(directory: projectId);
    final sessionIds = _sessionStatuses.keys
        .where((sessionId) => _directoryForSession(sessionId) == target)
        .toList(growable: false);
    return registry.pendingForProject(sessionIds);
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
      (byProject[_directoryForSession(sessionId)] ??= []).add(
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
