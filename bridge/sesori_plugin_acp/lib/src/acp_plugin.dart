import "dart:async";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_approval_registry.dart";
import "acp_command_listener.dart";
import "acp_command_tracker.dart";
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
/// [initializeCapabilityMeta], [commandForDispatch], [getAgents],
/// [getProviders].
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
    required AcpCommandTracker commandTracker,
    AcpProcessFactory? processFactory,
  }) : launchDirectory = normalizeProjectDirectory(directory: launchDirectory),
       _processFactory = processFactory,
       _commandTracker = commandTracker,
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

  /// Snapshot of the agent's advertised slash commands, fed by the
  /// notification listener and served by [getCommands].
  final AcpCommandTracker _commandTracker;
  AcpCommandListener? _commandListener;

  /// sessionId -> the canonical directory the session lives in. Populated on
  /// create and on every `session/list` hit, so a turn/history load runs in
  /// the session's own `cwd` (not the launch directory), events attribute to
  /// the right project, and the activity summary groups correctly. In-memory
  /// only: the bridge's stored rows are the durable attribution.
  final Map<String, String> _sessionDirectories = {};

  /// Every canonical directory the bridge has hinted at this run (see
  /// [listAllSessions]). Internal enumerations that have no hints of their own
  /// scan these too, so a never-enumerated prior-run session in a bridge-known
  /// directory is still discoverable when the agent lacks the unfiltered
  /// `session/list` form.
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

  /// Per-session turn-queue state. ACP agents run one turn per session at a
  /// time, so turns are serialized behind each session's chain here; all
  /// decisions live on this class — the state object only holds fields.
  final Map<String, _SessionTurnState> _turnStates = {};

  /// Sessions with a `session/prompt` currently in flight, in dispatch order.
  /// Per-session serialization guarantees a session appears at most once.
  final List<String> _inFlightTurnSessions = [];

  /// The most recently dispatched turn's session. Retained past turn end so a
  /// server request landing on the turn boundary still resolves to the right
  /// conversation.
  String? _lastTurnSessionId;

  /// The session to attribute a mid-turn server request that carries no
  /// `sessionId` of its own (see [AcpApprovalRegistry.resolveSessionId]).
  ///
  /// Precise when exactly one turn is in flight. With concurrent turns on
  /// multiple sessions ACP gives no request→turn correlation, so the most
  /// recent dispatch is used and the ambiguity is logged. With no turn in
  /// flight, the last dispatched turn's session is returned (boundary case).
  String? get activeTurnSessionId {
    if (_inFlightTurnSessions.length == 1) return _inFlightTurnSessions.single;
    if (_inFlightTurnSessions.isNotEmpty) {
      Log.w(
        "[$id] ${_inFlightTurnSessions.length} turns in flight; attributing "
        "sessionId-less server request to the most recent dispatch",
      );
      return _inFlightTurnSessions.last;
    }
    return _lastTurnSessionId;
  }

  /// Sessions resident in the live agent process (created via `session/new` or
  /// resumed via `session/load` this run). ACP agents hold sessions in memory
  /// per process, so a session from a prior bridge run must be re-loaded before
  /// a turn or the agent rejects it ("session not found").
  final Set<String> _residentSessions = {};

  /// Sessions whose `session/update` notifications are currently dropped — a
  /// resume `session/load` is in flight and its history replay must not leak
  /// into the live stream.
  final Set<String> _suppressedSessions = {};

  /// Per-session count of dropped replay notifications, read by the resume
  /// load's drain to detect when the replay stream has gone quiet. Keyed per
  /// session so two sessions resuming concurrently don't reset each other's
  /// quiet-window detection.
  final Map<String, int> _suppressedReplayCounts = {};

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

  /// Maps the user-selected slash command to the command name sent to the ACP
  /// agent. The original name remains authoritative for client-facing events.
  String commandForDispatch({required String command}) => command;

  /// Builds the approval registry. Override to return a harness-specific
  /// subclass (e.g. one that also handles `cursor/ask_question`). The base
  /// registry resolves sessionId-less server requests to the active turn's
  /// session (see [activeTurnSessionId]), same as the Cursor subclass.
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return AcpApprovalRegistry.forClient(
      client: client,
      emit: emitActivityEvent,
      activeSessionResolver: () => activeTurnSessionId,
    );
  }

  /// Captures the model/mode catalog from a `session/new` or `session/load`
  /// result (config-option ids, available models/modes, current values) and
  /// seeds the event mapper's fallback model. When [sessionId] is known, the
  /// session's current model is recorded for per-message stamping.
  ///
  /// [fromNewSession] distinguishes a `session/new` response — the only source
  /// that carries the backend's *new-session default* model/mode — from a
  /// `session/load` (resume or history replay), which replays some existing
  /// session's own model and must never redefine the default. The
  /// `sessionId`'s presence alone can't tell them apart because both new and
  /// load operations can supply one. Base does nothing; Cursor overrides for
  /// its `configOptions` picker.
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {}

  /// Applies the requested [model], [variant], and [agent] for a turn on
  /// [sessionId] before the prompt is dispatched. Called from [createSession]
  /// and from [sendPrompt]/[sendCommand], so a mid-conversation switch takes
  /// effect. Base does nothing (the agent's defaults are used). Cursor overrides
  /// to drive its model / mode / effort `session/set_config_option` calls.
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
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

  /// Approval state participates in the activity summary, so invalidate that
  /// summary after forwarding each approval transition.
  void emitActivityEvent(BridgeSseEvent event) {
    _eventBuffer.add(event);
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

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
        _commandListener = AcpCommandListener(
          notifications: client.notifications,
          tracker: _commandTracker,
        );
        _notificationSubscription = client.notifications.listen((notification) {
          if (notification.method == AcpMethods.sessionUpdate) {
            final sid = notification.params["sessionId"];
            final update = notification.params["update"];
            final isCommandUpdate =
                update is Map && update["sessionUpdate"] == "available_commands_update";
            if (sid is String && _suppressedSessions.contains(sid) && !isCommandUpdate) {
              // Replay from an in-flight resume-load — drop so old history does
              // not re-stream into the live conversation.
              _suppressedReplayCounts[sid] = (_suppressedReplayCounts[sid] ?? 0) + 1;
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
        await _commandListener?.dispose();
        _commandListener = null;
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
    // We only speak ACP v1. The agent echoes the protocol version it will use;
    // if that is not v1 it cannot understand our v1-shaped session/* calls, so
    // fail the handshake (degrading the plugin) rather than driving it with a
    // protocol it rejected. A missing version parses as v1, so agents that omit
    // the field (some cursor-agent builds) still connect.
    if (init.protocolVersion != acpProtocolVersion) {
      throw StateError(
        "ACP agent negotiated protocol version ${init.protocolVersion}, "
        "but this client only speaks v$acpProtocolVersion",
      );
    }
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
    _commandTracker.clear();
    // Let subclasses drop any process-global state cached against the dead agent
    // (e.g. Cursor's applied model/mode) so it is re-applied on the next turn.
    onConnectionReset();
    final sub = _notificationSubscription;
    _notificationSubscription = null;
    final commandListener = _commandListener;
    _commandListener = null;
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
      await commandListener?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel command subscription on reset", e, st);
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
          sessionsById[info.sessionId] = _toPluginSession(
            info,
            fallbackDirectory: launchDirectory,
            fallbackIsAuthoritative: false,
          );
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
            sessionsById[info.sessionId] = _toPluginSession(
              info,
              fallbackDirectory: directory,
              fallbackIsAuthoritative: true,
            );
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
          _toPluginSession(
            info,
            fallbackDirectory: target,
            fallbackIsAuthoritative: true,
          ),
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
  ///
  /// Only a **first-page** failure propagates: it is authoritative for whether
  /// the form is supported (so the caller can memoize `-32601`/`-32602`). A
  /// later-page failure means the form works but pagination hit a snag — the
  /// pages gathered so far are returned rather than discarding a proven-good
  /// first page (and the caller must not memoize a mid-pagination error as
  /// "unsupported").
  Future<List<AcpSessionInfo>> _listSessionPages(
    AcpStdioClient client, {
    required String? cwd,
  }) async {
    const maxPages = 50;
    final infos = <AcpSessionInfo>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final AcpSessionListResult result;
      try {
        final raw = await client.request(
          method: AcpMethods.sessionList,
          params: {
            "cwd": ?cwd,
            "cursor": ?cursor,
          },
        );
        result = AcpSessionListResult.fromJson(
          raw is Map ? raw.cast<String, dynamic>() : const {},
        );
      } on Object catch (error, stack) {
        if (page == 0) rethrow;
        Log.w(
          "[$id] session/list page $page for ${cwd ?? "(all)"} failed; "
          "returning ${infos.length} gathered so far",
          error,
          stack,
        );
        break;
      }
      infos.addAll(result.sessions);
      final next = result.nextCursor;
      if (next == null || next.isEmpty) break;
      cursor = next;
    }
    return infos;
  }

  PluginSession _toPluginSession(
    AcpSessionInfo info, {
    required String fallbackDirectory,
    required bool fallbackIsAuthoritative,
  }) {
    // The session belongs to its own cwd, canonicalized so it matches the
    // project id the bridge derives from the same value. A missing OR blank cwd
    // falls back to the directory that was scanned — the same `trim().isNotEmpty`
    // guard the caller uses to flag fallback attribution, so the two stay
    // consistent (a bare `?? ` would let `""` through to the process cwd).
    final rawCwd = info.cwd;
    final hasCwd = rawCwd != null && rawCwd.trim().isNotEmpty;
    final directory = normalizeProjectDirectory(directory: hasCwd ? rawCwd : fallbackDirectory);
    final directoryIsAuthoritative = hasCwd || fallbackIsAuthoritative;
    final id = info.sessionId;
    // A cwd-scoped response is authoritative even when its item omits cwd. Only
    // the unfiltered launch fallback remains eligible for a stored bridge prime
    // to repair.
    if (id.isNotEmpty) {
      if (directoryIsAuthoritative) _sessionDirectories[id] = directory;
      eventMapper.setSessionProject(id, _sessionDirectories[id] ?? directory);
      eventMapper.setSessionSnapshot(
        sessionId: id,
        title: info.title,
        createdMs: info.updatedAtMs,
        updatedMs: info.updatedAtMs,
      );
    }
    final ts = info.updatedAtMs;
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: info.title,
      time: ts == null ? null : PluginSessionTime(created: ts, updated: ts, archived: null),
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      // Served from the `available_commands_update` snapshot — ACP advertises
      // commands via that notification, not a request endpoint.
      _commandTracker.commands;

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
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    _sessionDirectories[session.sessionId] = canonicalDirectory;
    eventMapper.setSessionProject(session.sessionId, canonicalDirectory);
    // Seed the snapshot so a title event during the creation race (before the
    // bridge has a stored row to enrich from) still carries a sane time.
    eventMapper.setSessionSnapshot(
      sessionId: session.sessionId,
      title: null,
      createdMs: createdAt,
      updatedMs: createdAt,
    );
    // A session/new response is the authoritative source of the backend's
    // new-session default model/mode.
    captureSessionConfig(session, sessionId: session.sessionId, fromNewSession: true);
    // session/new leaves the session resident in the agent process.
    _residentSessions.add(session.sessionId);
    _sessionStatuses[session.sessionId] = const PluginSessionStatus.idle();
    final created = PluginSession(
      id: session.sessionId,
      projectID: canonicalDirectory,
      directory: canonicalDirectory,
      parentID: parentSessionId,
      title: null,
      time: PluginSessionTime(created: createdAt, updated: createdAt, archived: null),
    );
    emitEvent(eventMapper.mapCreatedSession(session: created));
    if (userVisibleText != null && userVisibleText.trim().isNotEmpty) {
      eventMapper
          .mapSentPrompt(
            sessionId: session.sessionId,
            parts: [PluginPromptPart.text(text: userVisibleText)],
          )
          .forEach(emitEvent);
    }
    if (parts.isEmpty) {
      // No first turn to carry the selection: apply it now so the session's
      // model/mode are in place for whichever turn comes first later.
      await applyTurnSelection(
        client: client,
        sessionId: session.sessionId,
        model: model,
        variant: variant,
        agent: agent,
      );
    } else {
      // A fresh session has an empty chain, so this dispatches immediately;
      // the selection is applied inside the turn like every other prompt.
      _enqueueTurn(
        sessionId: session.sessionId,
        parts: parts,
        model: model,
        variant: variant,
        agent: agent,
      );
    }
    return created;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    // Acceptance gate: an unreachable agent fails the send itself; the turn
    // re-resolves the client at dispatch time (see [_runTurn]).
    await _connectedClient();
    eventMapper
        .mapSentPrompt(sessionId: sessionId, parts: parts)
        .forEach(_eventBuffer.add);
    _enqueueTurn(
      sessionId: sessionId,
      parts: parts,
      model: model,
      variant: variant,
      agent: agent,
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
    final backendCommand = commandForDispatch(command: command);
    final body = arguments.isEmpty
        ? "/$backendCommand"
        : "/$backendCommand $arguments";
    final visibleBody = userVisibleArguments == null ? "/$command" : "/$command $userVisibleArguments";
    // Acceptance gate — see [sendPrompt].
    await _connectedClient();
    eventMapper
        .mapSentPrompt(
          sessionId: sessionId,
          parts: [PluginPromptPart.text(text: visibleBody)],
        )
        .forEach(_eventBuffer.add);
    _enqueueTurn(
      sessionId: sessionId,
      parts: [PluginPromptPart.text(text: body)],
      model: model,
      variant: variant,
      agent: agent,
    );
  }

  /// The directory a session should be loaded/operated in — its own canonical
  /// directory when known, else the launch directory.
  String _directoryForSession(String sessionId) =>
      _sessionDirectories[sessionId] ?? launchDirectory;

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {
    if (sessionId.isEmpty || directory.trim().isEmpty) return;
    final canonical = normalizeProjectDirectory(directory: directory);
    // Remember the directory for internal warm-up scans regardless — the hint
    // set widens future enumerations even when this session is already known.
    _hintedDirectories.add(canonical);
    // A hint, not an override: a directory learned from the agent itself
    // (enumeration hit, session/new) stays authoritative.
    if (_sessionDirectories.containsKey(sessionId)) return;
    _sessionDirectories[sessionId] = canonical;
    eventMapper.setSessionProject(sessionId, canonical);
  }

  /// Ensures [sessionId] is resident in the agent process before a turn. A
  /// session created/resumed this run is already resident; one from a prior
  /// bridge run is re-loaded via `session/load` (its history replay suppressed
  /// so it does not re-stream into the live conversation). Called only from
  /// inside a session's serialized turn, so per-session loads never overlap —
  /// each load owns its whole suppression window. Never throws for load
  /// failures — the turn proceeds and surfaces any error itself.
  Future<void> _ensureResident(AcpStdioClient client, String sessionId) async {
    if (_residentSessions.contains(sessionId)) return;
    await _loadResident(client, sessionId);
  }

  /// Performs the resume `session/load` for [_ensureResident]. Marks the
  /// session resident only on success — or on a *permanently unsupported*
  /// load (the no-reload-loop guarantee) — so a transiently failed load
  /// (timeout, RPC hiccup) is retried on the next turn instead of leaving the
  /// conversation unrecoverable until the agent respawns.
  Future<void> _loadResident(AcpStdioClient client, String sessionId) async {
    final loadSupported = _initResult?.agentCapabilities.loadSession ?? false;
    final resumeSupported = _initResult?.agentCapabilities.resumeSession ?? false;
    if (!loadSupported && !resumeSupported) {
      // No way to re-activate a prior-run session — memoize residency so
      // turns proceed without re-checking.
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
    if (!loadSupported) {
      // Resume-only agent: `session/resume` re-activates the session with NO
      // history replay, so no suppression window is needed.
      await _resumeResident(client, sessionId);
      return;
    }
    _suppressedSessions.add(sessionId);
    _suppressedReplayCounts.remove(sessionId);
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
      final result = AcpNewSessionResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      captureSessionConfig(result, sessionId: sessionId);
      // Keep suppressing until the (post-response) replay stream goes quiet.
      await _drainReplay(() => _suppressedReplayCounts[sessionId] ?? 0);
      _residentSessions.add(sessionId);
    } on AcpRpcException catch (error, stack) {
      if (error.code == -32601 || error.code == -32602) {
        // The agent advertised loadSession but rejects the RPC/shape — a retry
        // cannot succeed, so memoize residency to avoid a load loop and let
        // the prompt surface any real error itself.
        Log.w("[$id] session/load unsupported (code ${error.code}); proceeding without resume-load", error, stack);
        _residentSessions.add(sessionId);
      } else {
        // Transient agent error: stay non-resident so the next turn retries
        // the load instead of prompting a session the agent never loaded.
        Log.w("[$id] resume-load of $sessionId failed; will retry on next turn", error, stack);
      }
    } on Object catch (error, stack) {
      // Timeout / process blip: same retry-on-next-turn policy as above.
      Log.w("[$id] resume-load of $sessionId failed; will retry on next turn", error, stack);
    } finally {
      _suppressedSessions.remove(sessionId);
      _suppressedReplayCounts.remove(sessionId);
    }
  }

  /// Re-activates [sessionId] via `session/resume` for an agent that
  /// advertises `sessionCapabilities.resume` but not `loadSession`. Without
  /// this, the session would be marked resident with no RPC at all and the
  /// next `session/prompt` after a bridge restart would hit a session the
  /// fresh agent process never loaded. Same residency policy as the load
  /// path: resident on success or on a permanently unsupported RPC; transient
  /// failures retry on the next turn.
  Future<void> _resumeResident(AcpStdioClient client, String sessionId) async {
    try {
      final raw = await client.request(
        method: AcpMethods.sessionResume,
        params: {
          "sessionId": sessionId,
          "cwd": _directoryForSession(sessionId),
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      // The resume result carries the modes/configOptions catalog (and this
      // session's current selection) — capture it, but never as the
      // new-session default.
      final result = AcpNewSessionResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      captureSessionConfig(result, sessionId: sessionId);
      _residentSessions.add(sessionId);
    } on AcpRpcException catch (error, stack) {
      if (error.code == -32601 || error.code == -32602) {
        Log.w("[$id] session/resume unsupported (code ${error.code}); proceeding without resume", error, stack);
        _residentSessions.add(sessionId);
      } else {
        Log.w("[$id] session/resume of $sessionId failed; will retry on next turn", error, stack);
      }
    } on Object catch (error, stack) {
      Log.w("[$id] session/resume of $sessionId failed; will retry on next turn", error, stack);
    }
  }

  /// Queues a prompt turn on [sessionId]'s serialization chain: marks the
  /// session busy now (the user's send is accepted), dispatches once the
  /// session's previous turn finishes, and flips to idle when the last queued
  /// turn resolves (ACP carries no turn-complete event). Overlapping
  /// `session/prompt` requests for one session are rejected or dropped by ACP
  /// agents, so turns must never interleave per session.
  void _enqueueTurn({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) {
    final blocks = parts
        .map(_promptPartToContentBlock)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (blocks.isEmpty) return;

    final state = _turnStates.putIfAbsent(sessionId, _SessionTurnState.new);
    state.pending++;
    if (state.pending == 1) {
      _sessionStatuses[sessionId] = const PluginSessionStatus.busy();
      _eventBuffer.add(
        BridgeSseSessionStatus(
          sessionID: sessionId,
          status: const shared.SessionStatus.busy().toJson(),
        ),
      );
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
    final expectedGeneration = state.generation;
    // Each link isolates its own failure (_runTurn never throws), so one
    // failed turn cannot poison the chain for the turns queued behind it.
    state.tail = state.tail.then(
      (_) => _runTurn(
        sessionId: sessionId,
        state: state,
        expectedGeneration: expectedGeneration,
        blocks: blocks,
        model: model,
        variant: variant,
        agent: agent,
      ),
    );
  }

  /// Runs one serialized turn: resolves the live client, makes the session
  /// resident, applies the turn's model/mode selection, dispatches
  /// `session/prompt`, and settles the queue accounting. All of it runs here —
  /// inside the chain — so a turn queued behind an in-flight prompt survives
  /// an agent respawn (the client captured at enqueue time may have exited;
  /// re-resolving spawns a replacement and the dispatch-time resume-load makes
  /// the session resident in it), a queued turn retries a transiently failed
  /// resume-load itself, and a selection applied at enqueue time can't flip a
  /// process-global selection (Cursor's) under the previous, still-running
  /// turn. The abort generation is re-checked after every await: an abort
  /// landing mid-connect/mid-load/mid-selection must still drop the
  /// not-yet-dispatched turn instead of starting a fresh agent run right
  /// after the cancel.
  Future<void> _runTurn({
    required String sessionId,
    required _SessionTurnState state,
    required int expectedGeneration,
    required List<Map<String, dynamic>> blocks,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    // Aborted turns were never dispatched, so no per-turn error event — just
    // settle the accounting (idle emission when the count reaches 0).
    if (state.generation != expectedGeneration) {
      _finishTurn(sessionId: sessionId, state: state, failed: false, refused: false);
      return;
    }
    final AcpStdioClient client;
    try {
      client = await _connectedClient();
    } on Object catch (error, stack) {
      // An abort that landed while the reconnect was in flight already
      // discarded this turn — settle it silently instead of surfacing a
      // session error for a prompt the user cancelled.
      if (state.generation != expectedGeneration) {
        Log.d("[$id] queued turn on $sessionId aborted during reconnect: $error");
        _finishTurn(sessionId: sessionId, state: state, failed: false, refused: false);
        return;
      }
      // The send was already accepted, so a dead/unrespawnable agent must
      // surface as a failed turn, not a silent drop.
      Log.w("[$id] could not reach the agent for a queued turn on $sessionId", error, stack);
      _finishTurn(sessionId: sessionId, state: state, failed: true, refused: false);
      return;
    }
    if (state.generation != expectedGeneration) {
      _finishTurn(sessionId: sessionId, state: state, failed: false, refused: false);
      return;
    }
    await _ensureResident(client, sessionId);
    if (state.generation != expectedGeneration) {
      _finishTurn(sessionId: sessionId, state: state, failed: false, refused: false);
      return;
    }
    try {
      await applyTurnSelection(
        client: client,
        sessionId: sessionId,
        model: model,
        variant: variant,
        agent: agent,
      );
    } on Object catch (error, stack) {
      // Selection is best-effort (the Cursor override is already fail-soft):
      // the turn proceeds on the agent's current settings.
      Log.w("[$id] applyTurnSelection for $sessionId failed; prompting with current settings", error, stack);
    }
    if (state.generation != expectedGeneration) {
      _finishTurn(sessionId: sessionId, state: state, failed: false, refused: false);
      return;
    }
    eventMapper.beginTurn(sessionId);
    _inFlightTurnSessions.add(sessionId);
    _lastTurnSessionId = sessionId;
    try {
      final raw = await client.request(
        method: AcpMethods.sessionPrompt,
        params: {"sessionId": sessionId, "prompt": blocks},
        timeout: const Duration(minutes: 30),
      );
      final result = AcpPromptResult.fromJson(
        (raw as Map?)?.cast<String, dynamic>() ?? const {},
      );
      _finishTurn(
        sessionId: sessionId,
        state: state,
        failed: false,
        refused: result.stopReason == AcpStopReason.refusal,
      );
    } on Object catch (error, stack) {
      // The frame was already accepted (the phone's send returned success),
      // so a later rejection (auth expiry, stale session, bad payload) would
      // otherwise stop the run with no signal. Log and surface it as a
      // session error, not a silent idle.
      Log.w("[$id] session/prompt for $sessionId failed after dispatch", error, stack);
      _finishTurn(sessionId: sessionId, state: state, failed: true, refused: false);
    }
  }

  /// Settles one finished (or dropped) turn: removes the in-flight marker,
  /// decrements the session's pending count, emits idle when the last queued
  /// turn is done, and surfaces a session error for a failed/refused turn.
  void _finishTurn({
    required String sessionId,
    required _SessionTurnState state,
    required bool failed,
    required bool refused,
  }) {
    _inFlightTurnSessions.remove(sessionId);
    if (state.pending > 0) state.pending--;
    // A session deleted mid-turn already dropped this state object from
    // [_turnStates]; its detached accounting above must still settle, but it
    // must not resurrect the deleted session's status entry or emit
    // idle/error events for it.
    if (!identical(_turnStates[sessionId], state)) return;
    if (state.pending == 0) {
      _sessionStatuses[sessionId] = const PluginSessionStatus.idle();
      _eventBuffer.add(BridgeSseSessionIdle(sessionID: sessionId));
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
    if (failed || refused) {
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
    // Aborting means "stop this conversation now": drop the queued-but-
    // undispatched turns first so they don't dispatch after the cancel. The
    // in-flight turn (if any) ends via the agent's cancellation, which
    // resolves its `session/prompt` future and settles the accounting.
    _turnStates[sessionId]?.generation++;
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
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if ((_turnStates[sessionId]?.pending ?? 0) > 0) {
      await abortSession(sessionId: sessionId);
    }
    // The state object is dropped here; a still-settling cancelled turn holds
    // its own reference, so its accounting completes harmlessly off-map.
    _turnStates.remove(sessionId);
    _inFlightTurnSessions.remove(sessionId);
    if (_lastTurnSessionId == sessionId) _lastTurnSessionId = null;
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
      // Reclassify a halt notice (e.g. Cursor's account/plan gate) the same way
      // the live stream does, so reloaded history renders it identically.
      haltClassifier: eventMapper.classifyHaltNotice,
    );
    StreamSubscription<AcpNotification>? sub;
    AcpCommandListener? commandListener;
    try {
      await replayClient.connect();
      final replayInit = await _initialize(replayClient);
      if (!replayInit.agentCapabilities.loadSession) {
        // History is genuinely unavailable on this agent — an empty thread,
        // not a failure: the session must stay usable for new prompts.
        return const [];
      }
      if (!replayClient.isConnected) {
        // The replay agent died right after the handshake — a failure, not an
        // empty thread (wrapped into the typed failure below).
        throw StateError("replay agent exited during initialization");
      }
      var received = 0;
      BridgeSseSessionsUpdated? deferredCommandRefresh;
      commandListener = AcpCommandListener(
        notifications: replayClient.notifications,
        tracker: _commandTracker,
      );
      sub = replayClient.notifications.listen((notification) {
        if (notification.method == AcpMethods.sessionUpdate) {
          received++;
          collector.consume(notification.params);
          final update = notification.params["update"];
          if (update is Map && update["sessionUpdate"] == "available_commands_update") {
            final refreshes = eventMapper.map(notification).whereType<BridgeSseSessionsUpdated>();
            if (refreshes.isNotEmpty) deferredCommandRefresh = refreshes.last;
          }
        }
      });
      final Object? raw;
      try {
        raw = await replayClient.request(
          method: AcpMethods.sessionLoad,
          params: {
            "sessionId": sessionId,
            "cwd": _directoryForSession(sessionId),
            "mcpServers": const <Object?>[],
          },
          timeout: const Duration(minutes: 2),
        );
      } on AcpRpcException catch (error, stackTrace) {
        if (error.code == -32601 || error.code == -32602) {
          // cursor-agent rejects `session/load` for some stored sessions with
          // method-not-found / invalid-params (e.g. a session created by a
          // prior agent process, or whose worktree was moved/removed). That is
          // not a transport failure, so degrade to whatever history replayed
          // before the rejection — fail-soft like the no-loadSession branch
          // above — keeping the session openable and promptable instead of
          // 502ing the whole detail view. Nothing is memoized: every open
          // retries the load, so a rejection caused by a stale cwd recovers
          // once a later enumeration repairs the session's directory. This
          // catch is scoped to the load request alone — a rejected handshake
          // (initialize/authenticate) must keep surfacing as the typed
          // failure below, per the getSessionMessages contract.
          Log.w(
            "[$id] session/load rejected for $sessionId (code ${error.code}); "
            "showing collected history",
            error,
            stackTrace,
          );
          // A command snapshot replayed before the rejection already mutated
          // the process-global tracker, so consumers still need the refresh
          // nudge — same flush as the success path below.
          final commandRefresh = deferredCommandRefresh;
          if (commandRefresh != null) _eventBuffer.add(commandRefresh);
          return collector.build();
        }
        // Any other RPC error is a genuine load failure — wrapped typed below.
        rethrow;
      }
      // The load result also carries the model/mode catalog (and the loaded
      // session's current model) — capture it so the picker is populated and
      // replayed messages are stamped with the session's real model.
      final result = AcpNewSessionResult.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      );
      captureSessionConfig(result, sessionId: sessionId);
      // The ACP spec replays the whole thread via `session/update` BEFORE the
      // `session/load` response resolves, but cursor-agent streams later turns
      // AFTER it. Drain until the replay stream goes quiet so multi-turn history
      // is captured in full, bounded so a chatty agent can't hang the request.
      await _drainReplay(() => received);
      final commandRefresh = deferredCommandRefresh;
      if (commandRefresh != null) _eventBuffer.add(commandRefresh);
      collector.modelId = eventMapper.modelForSession(sessionId);
      collector.providerId = eventMapper.providerForSession(sessionId);
      return collector.build();
    } on Object catch (error, stackTrace) {
      // A broken replay (connect/init/auth/load failure) must stay
      // distinguishable from a genuinely empty thread: surface it as a typed
      // failure (the bridge router maps it to a 502 and the phone renders a
      // retry state) instead of swallowing it into an empty list.
      Error.throwWithStackTrace(
        PluginOperationException(
          "session/load history replay",
          message: "history replay for $sessionId failed",
          cause: error,
        ),
        stackTrace,
      );
    } finally {
      try {
        await sub?.cancel();
      } on Object catch (e, st) {
        Log.w("[$id] failed to cancel replay subscription", e, st);
      }
      try {
        await commandListener?.dispose();
      } on Object catch (e, st) {
        Log.w("[$id] failed to cancel replay command subscription", e, st);
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
      // A session with any unfinished turn (running or queued behind one)
      // counts as running, so it stays active until its last turn settles.
      final running = (_turnStates[sessionId]?.pending ?? 0) > 0;
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
      await _commandListener?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel command subscription", e, st);
    } finally {
      _commandListener = null;
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

/// Mutable per-session turn-queue fields. [AcpPlugin] owns all the logic —
/// this only carries the chain tail the session's turns serialize behind, the
/// count of unfinished turns, and the abort generation used to drop
/// queued-but-undispatched turns.
class _SessionTurnState {
  /// Completion of the session's most recently queued turn.
  Future<void> tail = Future<void>.value();

  /// Turns enqueued but not yet finished (including the running one).
  int pending = 0;

  /// Bumped by abort/delete; a queued turn dispatches only if the generation
  /// it captured at enqueue time is still current.
  int generation = 0;
}
