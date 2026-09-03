import "dart:async";
import "dart:collection";

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
import "acp_session_options_service.dart";
import "acp_stdio_client.dart";
import "api/acp_agent_api.dart";
import "repositories/acp_session_config_repository.dart";
import "repositories/trackers/acp_child_session_tracker.dart";

/// Base [BridgeDerivedProjectsPluginApi] implementation for any ACP (Agent
/// Client Protocol) agent driven over stdio.
///
/// ACP backends have no project concept — each session just carries a `cwd` —
/// so the bridge derives the project list from [listAllSessions] and owns all
/// project/session persistence itself; the plugin stores nothing on disk.
///
/// Every policy and behavior hook has a bridge-safe default, so a compliant agent
/// needs only identity, launch spec, and trackers. A harness overrides what
/// differs: protocol policies ([authMethodId], [authMethodAllowlist], [initializeCapabilityMeta],
/// [supportsFormElicitation], [serializesPromptsProcessWide],
/// [cancelsActiveTurnForQueuedInput], [failsTurnOnSelectionError],
/// [sessionCloseSettlementTimeout]) and behavior hooks ([buildApprovalRegistry],
/// [onConnectionReset], [commandForDispatch]), plus the option/catalog surface
/// ([getSessionOptions], [getAgents], [getProviders], [getCommands]) when the
/// agent exposes a richer model catalog than the neutral process default.
///
/// Unlike the codex plugin (which connects to a process listening on a ws
/// port), this owns the agent subprocess: it spawns lazily on first use and
/// reaps it on [dispose].
abstract class AcpPlugin({
  @override required final String id,

  /// Human-facing agent name used for synthesized agents/providers.
  required final String agentDisplayName,
  required final AcpLaunchSpec launchSpec,
  required String launchDirectory,

  /// The live event mapper (subclasses may pass a specialized one). Its
  /// `pluginId` is also the `agent` stamped on live and replayed messages.
  required final AcpEventMapper eventMapper,

  /// The composition-owned sub-agent tracker [eventMapper] pushes lifecycle
  /// facts into; the plugin only reads its snapshots and clears it.
  required final AcpChildSessionTracker childSessionTracker,

  /// Snapshot of the agent's advertised slash commands, fed by the
  /// notification listener and served by [getCommands].
  required final AcpCommandTracker _commandTracker,

  /// Neutral process-scoped options (one agent, the process-default model),
  /// served unless a harness overrides the option getters with its catalog;
  /// also forgets a deleted session's model override. Built by the composer
  /// over the same configuration/command trackers as [eventMapper].
  required final AcpSessionOptionsService _sessionOptionsService,
  required final AcpProcessFactory _processFactory,
}) extends BridgeDerivedProjectsPluginApi {
  this : _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  /// Bridge launch CWD (canonicalized) — the directory the bridge seeds as an
  /// always-present project, and the fallback attribution for sessions whose
  /// own directory is unknown.
  @override
  final String launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;

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
  PluginAuthenticationRequiredException? _authenticationFailure;
  StreamSubscription<AcpNotification>? _notificationSubscription;
  StreamSubscription<AcpServerRequest>? _serverRequestSubscription;
  AcpApprovalRegistry? _approvalRegistry;
  AcpInitializeResult? _initResult;

  /// Emits after each successful (re)connect — including a lazy reconnect that
  /// follows [resetConnectionAfterExit] — so the lifecycle wrapper can re-arm
  /// its exit watch on the new client and flip back to ready. Broadcast (no
  /// buffering): the initial connect, driven by the wrapper directly, is not a
  /// subscriber so it is not double-handled.
  final StreamController<void> _connected = StreamController<void>.broadcast();
  Stream<void> get onConnected => _connected.stream;
  final StreamController<String?> _authenticationFailures = StreamController<String?>.broadcast();
  Stream<String?> get onAuthenticationFailure => _authenticationFailures.stream;
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.unknown);

  Stream<PluginWorkState> get workState => _workState.stream;
  PluginWorkState get currentWorkState => _workState.current;

  final Map<String, PluginSessionStatus> _sessionStatuses = {};

  /// Sessions whose initial user message was synthesized by this bridge
  /// process. History replay reuses that message identity to avoid a load/SSE
  /// race rendering the same prompt twice.
  final Set<String> _syntheticInitialPromptSessions = {};

  /// Per-session turn-queue state. ACP agents run one turn per session at a
  /// time, so turns are serialized behind each session's chain here; all
  /// decisions live on this class — the state object only holds fields.
  final Map<String, _SessionTurnState> _turnStates = {};

  /// Agent updates and server requests that raced the stdin flush for an
  /// accepted existing-session prompt. The user message cannot publish before
  /// the flush succeeds, so hold both until that message and any preceding tool
  /// update have entered the event stream.
  final Map<String, List<AcpNotification>> _promptWriteNotifications = {};
  final Map<String, List<AcpServerRequest>> _promptWriteServerRequests = {};
  final Set<String> _cancelledPromptWriteSessions = {};

  /// Shared tail used only by agents that cannot correlate sessionless server
  /// requests while multiple prompts are in flight.
  Future<void> _processTurnTail = Future<void>.value();

  /// Exact selection retained when an already-created empty session cannot be
  /// configured yet. Its first prompt retries before dispatch.
  final Map<String, _TurnSelection> _pendingSelections = {};

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

  // --- Protocol policies (bridge-safe defaults; override what differs) ---

  /// Auth method id to call if the agent reports it requires auth. `null`
  /// picks the first advertised non-terminal method — the headless bridge can
  /// never complete an interactive terminal flow (see [AcpAgentApi.initialize]).
  String? get authMethodId => null;

  /// Optional allowlist applied when [authMethodId] is `null`. The stock
  /// behavior accepts every advertised non-terminal method.
  Set<String>? get authMethodAllowlist => null;

  /// Non-standard capability hints sent under `clientCapabilities._meta`
  /// (e.g. Cursor's `parameterizedModelPicker`).
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  /// Whether this agent should be told the client supports standard ACP forms
  /// (`elicitation/create`).
  bool get supportsFormElicitation => false;

  /// Whether prompts across all sessions share one dispatch lane. Stock ACP
  /// serializes per session only.
  bool get serializesPromptsProcessWide => false;

  /// Whether accepting another input should cancel this session's active turn.
  ///
  /// Every production harness must deliver busy-session follow-ups immediately,
  /// either through native steering or this stop-and-send fallback. ACP v1 has
  /// no standard steering method, so the shared default queues the new input,
  /// sends the standard ACP cancel, and dispatches only after cancellation
  /// settles. Override with `false` only when the concrete plugin supplies a
  /// different immediate active-turn delivery path; inheriting the turn queue
  /// while returning `false` is not valid production behavior.
  bool get cancelsActiveTurnForQueuedInput => true;

  /// Whether a turn must stop when its requested selection cannot be applied.
  /// Fail closed by default: a prompt should not silently run on a model/mode
  /// the user did not pick. Only matters when [applyTurnSelection] can throw.
  bool get failsTurnOnSelectionError => true;

  /// Maximum time deletion waits for a cancelled target turn before close.
  Duration get sessionCloseSettlementTimeout => const Duration(seconds: 5);

  // --- Behavior hooks ---

  /// Maps the user-selected slash command to the command name sent to the ACP
  /// agent. The original name remains authoritative for client-facing events.
  String commandForDispatch({required String command}) => command;

  /// Optional top-level metadata for an outbound `session/prompt` request.
  Map<String, dynamic>? outboundPromptMeta({
    required String sessionId,
    required String messageId,
  }) => null;

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
  /// seeds the configuration tracker's process fallback. When [sessionId] is
  /// known, the session's current model is recorded for per-message stamping.
  ///
  /// [fromNewSession] distinguishes a `session/new` response — the only source
  /// that carries the backend's *new-session default* model/mode — from a
  /// `session/load` (resume or history replay), which replays some existing
  /// session's own model and must never redefine the default. The
  /// `sessionId`'s presence alone can't tell them apart because both new and
  /// load operations can supply one. Base does nothing; harnesses with a model
  /// catalog (Cursor's `configOptions` picker, OMP, Hermes) override.
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {}

  /// Session-local variant stamped on replayed assistant messages after
  /// [captureSessionConfig] observes the `session/load` result. Base ACP has no
  /// variant state; harnesses with a session-specific variant may override.
  String? replayVariantForSession({required String sessionId}) => null;

  Future<void> validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {}

  /// Applies the requested [model], [variant], and [agent] for a turn on
  /// [sessionId] before the prompt is dispatched. [configRepository] writes
  /// standard `session/set_config_option` on the connection the turn runs on;
  /// a harness extension (Hermes's `session/set_model`) goes through the
  /// harness's own repository over the live [client]. Called from
  /// [createSession] and from [sendPrompt]/[sendCommand], so a
  /// mid-conversation switch takes effect. Base does nothing (the agent's
  /// defaults are used). Cursor overrides to drive its model / mode / effort
  /// config writes.
  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {}

  /// Validates harness-specific initialize metadata for live and replay
  /// connections without mutating live process state.
  void validateInitializeResult(AcpInitializeResult result) {}

  /// Captures initialize-owned state only for the live connection. Replay uses
  /// a separate process and must not replace live process defaults.
  void captureLiveInitializeResult(AcpInitializeResult result) {}

  /// Additional privacy-safe events for a prompt failure. The generic session
  /// error is always emitted separately.
  Iterable<BridgeSseEvent> mapPromptFailure({
    required String sessionId,
    required Object error,
  }) => const [];

  /// Invoked when the agent subprocess is torn down for a respawn (see
  /// [resetConnectionAfterExit]). The replacement process starts with none of
  /// the prior process's applied state, so a subclass that caches process-global
  /// selections (e.g. Cursor's last-applied model/mode) MUST clear that cache
  /// here — otherwise it will skip re-applying them on the fresh agent and run a
  /// turn on the wrong model/mode. Base does nothing.
  void onConnectionReset() {}

  // --- Protected accessors for subclasses ---

  String? get authenticationFailureActionHint => _authenticationFailure?.actionHint;

  AcpStdioClient? get client => _client;
  AcpInitializeResult? get initializeResult => _initResult;
  Future<AcpStdioClient> requireConnectedClient() => _connectedClient();
  void emitEvent(BridgeSseEvent event) => _eventBuffer.add(event);

  /// Returns the normalized directory already attributed to [sessionId].
  /// Unknown sessions use the plugin's launch directory.
  String directoryForSession({required String sessionId}) => _sessionDirectories[sessionId] ?? launchDirectory;

  /// The single handler for agent-originated notifications: replay suppression,
  /// then mapping through [eventMapper] into the event buffer. Also the forward
  /// target for fire-and-forget extension *requests* acknowledged and
  /// re-injected by an approval registry's `handleExtensionRequest` override
  /// (see `CursorApprovalRegistry`), so both wire shapes share one mapping path.
  void handleAgentNotification(AcpNotification notification) {
    if (notification.method == AcpMethods.sessionUpdate) {
      final sid = notification.params["sessionId"];
      final update = notification.params["update"];
      final isCommandUpdate = update is Map && update["sessionUpdate"] == "available_commands_update";
      if (sid is String && _suppressedSessions.contains(sid) && !isCommandUpdate) {
        // Replay from an in-flight resume-load — drop so old history does
        // not re-stream into the live conversation.
        _suppressedReplayCounts[sid] = (_suppressedReplayCounts[sid] ?? 0) + 1;
        return;
      }
      if (sid is String && _isPromptFrameWriting(sessionId: sid)) {
        _promptWriteNotifications.putIfAbsent(sid, () => []).add(notification);
        return;
      }
    }
    eventMapper.map(notification).forEach(_eventBuffer.add);
  }

  void _handleAgentServerRequest({required AcpServerRequest request}) {
    final registry = _approvalRegistry;
    if (registry == null) return;
    final attribution = _serverRequestAttribution(request: request);
    final sessionId = attribution.sessionId;
    // Pin heuristic sessionless attribution at receipt: another concurrent turn
    // can dispatch before this request leaves the prompt-write buffer. Preserve
    // exact tool correlation so a harness mapper can resolve its owning turn.
    final routedRequest = sessionId == null || attribution.fromTool
        ? request
        : _serverRequestWithSession(request: request, sessionId: sessionId);
    if (sessionId != null && _isPromptFrameWriting(sessionId: sessionId)) {
      _promptWriteServerRequests.putIfAbsent(sessionId, () => []).add(routedRequest);
      return;
    }
    registry.handleServerRequest(request: routedRequest);
  }

  AcpServerRequest _serverRequestWithSession({required AcpServerRequest request, required String sessionId}) {
    final explicitSessionId = request.params["sessionId"];
    if (explicitSessionId is String && explicitSessionId.trim().isNotEmpty) return request;
    return AcpServerRequest(
      id: request.id,
      method: request.method,
      params: {...request.params, "sessionId": sessionId},
    );
  }

  ({String? sessionId, bool fromTool}) _serverRequestAttribution({required AcpServerRequest request}) {
    final rawSessionId = request.params["sessionId"];
    if (rawSessionId != null && rawSessionId is! String) return (sessionId: null, fromTool: false);
    final explicit = rawSessionId is String ? rawSessionId.trim() : null;
    if (explicit != null && explicit.isNotEmpty) return (sessionId: explicit, fromTool: false);
    final toolSessionId = _serverRequestToolSessionId(request: request);
    if (toolSessionId != null) return (sessionId: toolSessionId, fromTool: true);
    return (sessionId: activeTurnSessionId, fromTool: false);
  }

  String? _serverRequestToolSessionId({required AcpServerRequest request}) {
    final rawToolCallId = request.params["toolCallId"];
    if (rawToolCallId is! String || rawToolCallId.isEmpty) return null;
    final mapped = eventMapper.sessionIdForToolCallId(toolCallId: rawToolCallId);
    if (mapped != null) return mapped;
    for (final entry in _promptWriteNotifications.entries) {
      for (final notification in entry.value) {
        final update = notification.params["update"];
        if (update is Map && update["toolCallId"] == rawToolCallId) return entry.key;
      }
    }
    return null;
  }

  bool _isPromptFrameWriting({required String sessionId}) =>
      _turnStates[sessionId]?.queue.any((entry) => entry.phase == _QueuedAcpPromptPhase.writing) ?? false;

  void _flushPromptWriteEvents({required String sessionId}) {
    final notifications = _promptWriteNotifications.remove(sessionId);
    notifications?.forEach(handleAgentNotification);
    final requests = _promptWriteServerRequests.remove(sessionId);
    final registry = _approvalRegistry;
    if (requests != null && registry != null) {
      for (final request in requests) {
        registry.handleServerRequest(request: request);
      }
    }
    if (_cancelledPromptWriteSessions.remove(sessionId)) {
      registry?.cancelForSession(sessionId: sessionId);
    }
  }

  void _dropPromptWriteEvents({required String sessionId}) {
    _promptWriteNotifications.remove(sessionId);
    _promptWriteServerRequests.remove(sessionId);
    _cancelledPromptWriteSessions.remove(sessionId);
  }

  /// Approval state participates in the activity summary, so invalidate that
  /// summary after forwarding each approval transition.
  void emitActivityEvent(BridgeSseEvent event) {
    if (_client != null) _syncWorkState();
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
      _authenticationFailure = null;
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
        _notificationSubscription = client.notifications.listen(handleAgentNotification);
        final registry = buildApprovalRegistry(client);
        _approvalRegistry = registry;
        _serverRequestSubscription = client.serverRequests.listen(
          (request) => _handleAgentServerRequest(request: request),
        );
        final initResult = await _initialize(client);
        captureLiveInitializeResult(initResult);
        _initResult = initResult;
        _syncWorkState();
        if (!_connected.isClosed) _connected.add(null);
        return true;
      } catch (error) {
        await _commandListener?.dispose();
        _commandListener = null;
        if (error is PluginAuthenticationRequiredException) {
          _authenticationFailure = error;
          if (!_authenticationFailures.isClosed) _authenticationFailures.add(authenticationFailureActionHint);
        }
        _workState.set(PluginWorkState.unknown);
        await client.dispose();
        if (identical(_client, client)) {
          _client = null;
          _connectFuture = null;
        }
        return await Future<bool>.error(error);
      }
    }();
    _connectFuture = future.catchError((Object _) => false);
    return _connectFuture!;
  }

  /// Runs the ACP `initialize` handshake (and `authenticate` if the agent
  /// advertises an auth method) on [client] with this plugin's policies,
  /// returning the parsed result. Does not store it — the caller decides (the
  /// live connect persists it as [_initResult]; the replay client in
  /// [getSessionMessages] keeps it local so it never clobbers the live
  /// capabilities). A non-v1 negotiation fails the handshake (degrading the
  /// plugin) rather than driving the agent with a protocol it rejected.
  Future<AcpInitializeResult> _initialize(AcpStdioClient client) async {
    final result = await AcpAgentApi(client: client).initialize(
      formElicitation: supportsFormElicitation,
      capabilityMeta: initializeCapabilityMeta,
      authMethodId: authMethodId,
      authMethodAllowlist: authMethodAllowlist,
      timeout: AcpAgentApi.defaultRequestTimeout,
    );
    validateInitializeResult(result);
    return result;
  }

  Future<AcpStdioClient> _connectedClient() async {
    final ok = await ensureConnected();
    final client = _client;
    if (!ok || client == null) {
      if (_authenticationFailure case final failure?) throw failure;
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
    _workState.set(PluginWorkState.unknown);
    _connectFuture = null;
    _authenticationFailure = null;
    _initResult = null;
    _residentSessions.clear();
    _bareSessionListUnsupported = false;
    _commandTracker.clear();
    // Let subclasses drop any process-global state cached against the dead agent
    // (e.g. Cursor's applied model/mode) so it is re-applied on the next turn.
    onConnectionReset();
    await _teardownConnection();
  }

  /// Detaches and disposes the live connection's collaborators (notification
  /// and server-request subscriptions, command listener, approval registry,
  /// client). The fields are cleared before the first await so a concurrent
  /// [ensureConnected] never sees a stale connection, and each step is isolated
  /// so a failure in one (e.g. a hung subscription) cannot skip a later one
  /// (e.g. reaping the agent subprocess). Never throws — log and continue.
  Future<void> _teardownConnection() async {
    Future<void>? notificationCancellation;
    try {
      notificationCancellation = _notificationSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel notification subscription", e, st);
    }
    _notificationSubscription = null;
    Future<void>? serverRequestCancellation;
    try {
      serverRequestCancellation = _serverRequestSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel server-request subscription", e, st);
    }
    _serverRequestSubscription = null;
    _promptWriteNotifications.clear();
    _promptWriteServerRequests.clear();
    _cancelledPromptWriteSessions.clear();
    final commandListener = _commandListener;
    _commandListener = null;
    final registry = _approvalRegistry;
    _approvalRegistry = null;
    final client = _client;
    _client = null;
    try {
      await notificationCancellation;
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel notification subscription", e, st);
    }
    try {
      await serverRequestCancellation;
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel server-request subscription", e, st);
    }
    try {
      await commandListener?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel command subscription", e, st);
    }
    try {
      await registry?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose approval registry", e, st);
    }
    try {
      await client?.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose client", e, st);
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
    } on PluginAuthenticationRequiredException {
      rethrow;
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
      } on PluginAuthenticationRequiredException {
        rethrow;
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
      } on PluginAuthenticationRequiredException {
        rethrow;
      } on Object catch (error, stack) {
        Log.w("[$id] session/list failed for $directory; skipping", error, stack);
      }
    }
    return sessionsById.values.toList(growable: false);
  }

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final AcpStdioClient client;
    try {
      client = await _connectedClient();
    } on PluginAuthenticationRequiredException {
      rethrow;
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
    } on PluginAuthenticationRequiredException {
      rethrow;
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
    final api = AcpAgentApi(client: client);
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final AcpSessionListResult result;
      try {
        result = await api.listSessionsPage(
          cwd: cwd,
          cursor: cursor,
          timeout: AcpAgentApi.defaultRequestTimeout,
        );
      } on PluginAuthenticationRequiredException {
        rethrow;
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

  String? sessionParentId(AcpSessionInfo info) => null;

  int? sessionCreatedAtMs(AcpSessionInfo info) => info.updatedAtMs;

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
        createdMs: sessionCreatedAtMs(info) ?? info.updatedAtMs,
        updatedMs: info.updatedAtMs,
      );
    }
    final ts = info.updatedAtMs;
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: sessionParentId(info),
      title: info.title,
      time: ts == null ? null : PluginSessionTime(created: sessionCreatedAtMs(info) ?? ts, updated: ts, archived: null),
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      // Served from the `available_commands_update` snapshot — ACP advertises
      // commands via that notification, not a request endpoint.
      _commandTracker.commands;

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async => PluginSessionOptionsDiscoveryResult.observed(
    options: _sessionOptionsService.getSessionOptions(),
  );

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
    final session = await AcpAgentApi(client: client).newSession(
      cwd: directory,
      timeout: AcpAgentApi.defaultRequestTimeout,
    );
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
    await validateTurnSelection(operation: "createSession", model: model, variant: variant, agent: agent);
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
    final visibleParts = [
      if (userVisibleText != null && userVisibleText.trim().isNotEmpty) PluginPromptPart.text(text: userVisibleText),
      ...parts.whereType<PluginPromptPartFileData>(),
    ];
    final initialPromptEvents = eventMapper.mapInitialPrompt(
      sessionId: session.sessionId,
      parts: visibleParts,
      createdAtMs: createdAt,
    );
    if (initialPromptEvents.isNotEmpty) {
      _syntheticInitialPromptSessions.add(session.sessionId);
      initialPromptEvents.forEach(emitEvent);
    }
    if (parts.isEmpty) {
      // No first turn to carry the selection: apply it now so the session's
      // model/mode are in place for whichever turn comes first later.
      try {
        await _runOnProcessLane(
          () async => await applyTurnSelection(
            configRepository: AcpSessionConfigRepository(
              api: AcpAgentApi(client: await _connectedClient()),
            ),
            sessionId: session.sessionId,
            model: model,
            variant: variant,
            agent: agent,
          ),
        );
      } on Object catch (error, stack) {
        if (!failsTurnOnSelectionError) rethrow;
        _pendingSelections[session.sessionId] = _TurnSelection(
          model: model,
          variant: variant,
          agent: agent,
        );
        Log.w(
          "[$id] initial selection for ${session.sessionId} failed; retrying before first turn",
          error,
          stack,
        );
        _eventBuffer.add(
          BridgeSseTuiToastShow(
            sessionID: session.sessionId,
            title: "Session options not applied",
            message: "The selected options will be retried before the first turn.",
            variant: "warning",
          ),
        );
      }
    } else {
      // A fresh session has an empty chain, so this dispatches immediately;
      // the selection is applied inside the turn like every other prompt.
      final blocks = _contentBlocks(parts);
      if (blocks.isNotEmpty) {
        _enqueueTurn(
          sessionId: session.sessionId,
          turn: _InitialAcpTurn(
            blocks: blocks,
            messageId: AcpEventMapper.initialUserMessageId(session.sessionId),
            model: model,
            variant: variant,
            agent: agent,
          ),
        );
      }
    }
    return created;
  }

  Future<T> _runOnProcessLane<T>(Future<T> Function() operation) {
    if (!serializesPromptsProcessWide) return operation();
    final result = _processTurnTail.then((_) => operation());
    _processTurnTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (_turnStates[sessionId]?.hasAcceptedPrompt(promptId: promptId) ?? false) return;
    // Acceptance gate: an unreachable agent fails the send itself; the turn
    // re-resolves the client at dispatch time (see [_runTurn]).
    await _connectedClient();
    await validateTurnSelection(operation: "sendPrompt", model: model, variant: variant, agent: agent);
    // Another matching send may have been admitted while connection awaited.
    if (_turnStates[sessionId]?.hasAcceptedPrompt(promptId: promptId) ?? false) return;
    _recordSessionActivity(sessionId);
    final text = parts
        .whereType<PluginPromptPartText>()
        .map((part) => part.text)
        .where((part) => part.trim().isNotEmpty)
        .join("\n")
        .trim();
    final blocks = _contentBlocks(parts);
    if (blocks.isEmpty) return;
    _enqueueTurn(
      sessionId: sessionId,
      turn: _QueuedAcpTurn(
        blocks: blocks,
        messageId: AcpEventMapper.sentUserMessageId(promptId: promptId),
        model: model,
        variant: variant,
        agent: agent,
        queuedPrompt: _QueuedAcpPrompt(
          presentation: PluginQueuedPrompt(
            id: promptId,
            text: text.isEmpty ? null : text,
            command: null,
            attachmentCount: parts.where((part) => part is! PluginPromptPartText).length,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          visibleParts: List.unmodifiable(parts),
        ),
      ),
    );
    _cancelActiveTurnForQueuedInput(sessionId: sessionId);
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (_turnStates[sessionId]?.hasAcceptedPrompt(promptId: promptId) ?? false) return;
    await _connectedClient();
    await validateTurnSelection(operation: "sendCommand", model: model, variant: variant, agent: agent);
    final backendCommand = commandForDispatch(command: command);
    final body = arguments.isEmpty ? "/$backendCommand" : "/$backendCommand $arguments";
    final visibleArguments = userVisibleArguments?.trim();
    final visibleBody = visibleArguments == null || visibleArguments.isEmpty
        ? "/$command"
        : "/$command $userVisibleArguments";
    // Another matching send may have been admitted while connection awaited.
    if (_turnStates[sessionId]?.hasAcceptedPrompt(promptId: promptId) ?? false) return;
    _recordSessionActivity(sessionId);
    final blocks = _contentBlocks([PluginPromptPart.text(text: body)]);
    if (blocks.isEmpty) return;
    _enqueueTurn(
      sessionId: sessionId,
      turn: _QueuedAcpTurn(
        blocks: blocks,
        messageId: AcpEventMapper.sentUserMessageId(promptId: promptId),
        model: model,
        variant: variant,
        agent: agent,
        queuedPrompt: _QueuedAcpPrompt(
          presentation: PluginQueuedPrompt(
            id: promptId,
            text: visibleArguments == null || visibleArguments.isEmpty ? null : visibleArguments,
            command: command,
            attachmentCount: 0,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          visibleParts: [PluginPromptPart.text(text: visibleBody)],
        ),
      ),
    );
    _cancelActiveTurnForQueuedInput(sessionId: sessionId);
  }

  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async {
    final state = _turnStates[sessionId];
    if (state == null) return const [];
    return List.unmodifiable(state.queue.map((entry) => entry.presentation));
  }

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async {
    final state = _turnStates[sessionId];
    if (state == null) return false;
    final index = state.queue.indexWhere((entry) => entry.presentation.id == promptId);
    if (index == -1) return false;
    final entry = state.queue[index];
    if (entry.phase != _QueuedAcpPromptPhase.queued) return false;
    state.queue.removeAt(index);
    entry.phase = _QueuedAcpPromptPhase.cancelled;
    _emitQueueUpdate(sessionId: sessionId, state: state);
    return true;
  }

  void _cancelActiveTurnForQueuedInput({required String sessionId}) {
    if (!cancelsActiveTurnForQueuedInput || !_inFlightTurnSessions.contains(sessionId)) return;
    if (_isPromptFrameWriting(sessionId: sessionId)) _cancelledPromptWriteSessions.add(sessionId);
    _client?.notify(
      method: AcpMethods.sessionCancel,
      params: {"sessionId": sessionId},
    );
    _approvalRegistry?.cancelForSession(sessionId: sessionId);
  }

  void _recordSessionActivity(String sessionId) {
    _eventBuffer.add(
      eventMapper.mapSessionActivity(
        sessionId: sessionId,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// The directory a session should be loaded/operated in — its own canonical
  /// directory when known, else the launch directory.
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
      final result = await AcpAgentApi(client: client).loadSession(
        sessionId: sessionId,
        cwd: directoryForSession(sessionId: sessionId),
        timeout: const Duration(minutes: 2),
      );
      // A resume load: capture the catalog + this session's own model, but do
      // not let it redefine the new-session default.
      captureSessionConfig(result, sessionId: sessionId, fromNewSession: false);
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
      final result = await AcpAgentApi(client: client).resumeSession(
        sessionId: sessionId,
        cwd: directoryForSession(sessionId: sessionId),
        timeout: const Duration(minutes: 2),
      );
      // The resume result carries the modes/configOptions catalog (and this
      // session's current selection) — capture it, but never as the
      // new-session default.
      captureSessionConfig(result, sessionId: sessionId, fromNewSession: false);
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

  /// Queues a prompt turn on [sessionId]'s serialization chain. Accepted
  /// existing-session prompts stay in [getQueuedPrompts] until their ACP frame
  /// is written; an initial create turn has no separate queue presentation.
  void _enqueueTurn({
    required String sessionId,
    required _AcpTurn turn,
  }) {
    final state = _turnStates.putIfAbsent(sessionId, _SessionTurnState.new);
    if (turn case _QueuedAcpTurn(:final queuedPrompt)) {
      state.queue.add(queuedPrompt);
    }
    state.pending++;
    if (state.pending == 1) {
      _workState.set(PluginWorkState.busy);
      _sessionStatuses[sessionId] = const PluginSessionStatus.busy();
      _eventBuffer.add(
        BridgeSseSessionStatus(
          sessionID: sessionId,
          status: const shared.SessionStatus.busy().toJson(),
        ),
      );
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
    if (turn is _QueuedAcpTurn) {
      _emitQueueUpdate(sessionId: sessionId, state: state);
    }
    final expectedGeneration = state.generation;
    // Each link isolates its own failure (_runTurn never throws), so one
    // failed turn cannot poison the chain for the turns queued behind it.
    Future<void> operation() => _runTurn(
      sessionId: sessionId,
      state: state,
      expectedGeneration: expectedGeneration,
      turn: turn,
    );
    state.tail = serializesPromptsProcessWide ? _runOnProcessLane(operation) : state.tail.then((_) => operation());
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
    required _AcpTurn turn,
  }) async {
    // Aborted turns were never dispatched, so no per-turn error event — just
    // settle the accounting (idle emission when the count reaches 0).
    if (_turnWasCancelled(state: state, expectedGeneration: expectedGeneration, turn: turn)) {
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: false, refused: false);
      return;
    }
    state.activeSettlement = Completer<void>();
    final AcpStdioClient client;
    try {
      client = await _connectedClient();
    } on Object catch (error, stack) {
      // An abort that landed while the reconnect was in flight already
      // discarded this turn — settle it silently instead of surfacing a
      // session error for a prompt the user cancelled.
      if (_turnWasCancelled(state: state, expectedGeneration: expectedGeneration, turn: turn)) {
        Log.d("[$id] queued turn on $sessionId aborted during reconnect: $error");
        _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: false, refused: false);
        return;
      }
      // The send was already accepted, so a dead/unrespawnable agent must
      // surface as a failed turn, not a silent drop.
      if (error is PluginAuthenticationRequiredException) {
        _eventBuffer.addError(error, stack);
      }
      Log.w("[$id] could not reach the agent for a queued turn on $sessionId", error, stack);
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: true, refused: false);
      return;
    }
    if (_turnWasCancelled(state: state, expectedGeneration: expectedGeneration, turn: turn)) {
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: false, refused: false);
      return;
    }
    await _ensureResident(client, sessionId);
    if (_turnWasCancelled(state: state, expectedGeneration: expectedGeneration, turn: turn)) {
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: false, refused: false);
      return;
    }
    final pendingSelection = _pendingSelections[sessionId];
    final selectedModel = turn.model ?? pendingSelection?.model;
    final selectedVariant = turn.variant ?? pendingSelection?.variant;
    final selectedAgent = turn.agent ?? pendingSelection?.agent;
    try {
      await applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: sessionId,
        model: selectedModel,
        variant: selectedVariant,
        agent: selectedAgent,
      );
      _pendingSelections.remove(sessionId);
    } on Object catch (error, stack) {
      if (failsTurnOnSelectionError) {
        Log.w("[$id] applyTurnSelection for $sessionId failed; dropping turn", error, stack);
        _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: true, refused: false);
        return;
      }
      Log.w(
        "[$id] applyTurnSelection for $sessionId failed; prompting with current settings",
        error,
        stack,
      );
    }
    if (_turnWasCancelled(state: state, expectedGeneration: expectedGeneration, turn: turn)) {
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: false, refused: false);
      return;
    }
    eventMapper.beginTurn(sessionId: sessionId, messageId: turn.messageId);
    _inFlightTurnSessions.add(sessionId);
    _lastTurnSessionId = sessionId;
    try {
      if (turn case _QueuedAcpTurn(:final queuedPrompt)) {
        queuedPrompt.phase = _QueuedAcpPromptPhase.writing;
      }
      final meta = outboundPromptMeta(sessionId: sessionId, messageId: turn.messageId);
      final dispatched = await client.dispatchRequest(
        method: AcpMethods.sessionPrompt,
        params: {
          "sessionId": sessionId,
          "prompt": turn.blocks,
          "_meta": ?meta,
        },
        timeout: const Duration(minutes: 30),
      );
      _markTurnDispatched(sessionId: sessionId, state: state, turn: turn);
      final raw = await dispatched.response;
      final result = AcpPromptResult.fromJson(
        (raw as Map?)?.cast<String, dynamic>() ?? const {},
      );
      _finishTurn(
        sessionId: sessionId,
        state: state,
        turn: turn,
        failed: false,
        refused: result.stopReason == AcpStopReason.refusal,
      );
    } on Object catch (error, stack) {
      _dropPromptWriteEvents(sessionId: sessionId);
      // The phone's send already returned success, so a dispatch or later
      // backend failure must remain observable rather than silently dropping
      // the accepted prompt.
      Log.w("[$id] accepted session/prompt for $sessionId failed", error, stack);
      _eventBuffer.add(
        eventMapper.mapPromptError(
          sessionId: sessionId,
          message: _promptFailureMessage(error: error),
        ),
      );
      _finishTurn(sessionId: sessionId, state: state, turn: turn, failed: true, refused: false);
      mapPromptFailure(sessionId: sessionId, error: error).forEach(_eventBuffer.add);
    }
  }

  String _promptFailureMessage({required Object error}) {
    if (error case AcpRpcException(:final message, :final data)) {
      final Object? details = data is Map<Object?, Object?> ? data["details"] : null;
      if (details case final String details when details.trim().isNotEmpty) return details;
      if (message.trim().isNotEmpty) return message;
    }
    return error.toString();
  }

  bool _turnWasCancelled({
    required _SessionTurnState state,
    required int expectedGeneration,
    required _AcpTurn turn,
  }) =>
      state.generation != expectedGeneration ||
      switch (turn) {
        _InitialAcpTurn() => false,
        _QueuedAcpTurn(:final queuedPrompt) => queuedPrompt.phase == _QueuedAcpPromptPhase.cancelled,
      };

  void _markTurnDispatched({
    required String sessionId,
    required _SessionTurnState state,
    required _AcpTurn turn,
  }) {
    if (!identical(_turnStates[sessionId], state)) {
      _dropPromptWriteEvents(sessionId: sessionId);
      return;
    }
    if (turn is! _QueuedAcpTurn) return;
    final queuedPrompt = turn.queuedPrompt;
    eventMapper
        .mapSentPrompt(
          sessionId: sessionId,
          messageId: turn.messageId,
          promptId: queuedPrompt.presentation.id,
          parts: queuedPrompt.visibleParts,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        )
        .forEach(_eventBuffer.add);
    if (state.queue.remove(queuedPrompt)) {
      state.recordDispatchedPrompt(promptId: queuedPrompt.presentation.id);
      _emitQueueUpdate(sessionId: sessionId, state: state);
    }
    _flushPromptWriteEvents(sessionId: sessionId);
  }

  void _emitQueueUpdate({required String sessionId, required _SessionTurnState state}) {
    _eventBuffer.add(
      BridgeSseQueuedPromptsUpdated(
        sessionID: sessionId,
        prompts: [for (final entry in state.queue) entry.presentation],
      ),
    );
  }

  /// Settles one finished (or dropped) turn: removes the in-flight marker,
  /// decrements the session's pending count, emits idle when the last queued
  /// turn is done, and surfaces a session error for a failed/refused turn.
  void _finishTurn({
    required String sessionId,
    required _SessionTurnState state,
    required _AcpTurn turn,
    required bool failed,
    required bool refused,
  }) {
    _inFlightTurnSessions.remove(sessionId);
    final settlement = state.activeSettlement;
    state.activeSettlement = null;
    if (settlement != null && !settlement.isCompleted) settlement.complete();
    if (state.pending > 0) state.pending--;
    // A session deleted mid-turn already dropped this state object from
    // [_turnStates]; its detached accounting above must still settle, but it
    // must not resurrect the deleted session's status entry or emit
    // idle/error events for it.
    if (!identical(_turnStates[sessionId], state)) {
      _syncWorkState();
      return;
    }
    if (turn case _QueuedAcpTurn(:final queuedPrompt) when state.queue.remove(queuedPrompt)) {
      _emitQueueUpdate(sessionId: sessionId, state: state);
    }
    eventMapper.finalizeTurn(sessionId: sessionId).forEach(_eventBuffer.add);
    if (state.pending == 0) {
      _sessionStatuses[sessionId] = const PluginSessionStatus.idle();
      _eventBuffer.add(BridgeSseSessionIdle(sessionID: sessionId));
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
    _syncWorkState();
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

  List<Map<String, dynamic>> _contentBlocks(List<PluginPromptPart> parts) =>
      parts.map(_promptPartToContentBlock).whereType<Map<String, dynamic>>().toList(growable: false);

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
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async {
    await _abortSession(sessionId: sessionId);
    return const PluginAbortAccepted(workKept: false);
  }

  Future<void> _abortSession({required String sessionId}) async {
    // Aborting means "stop this conversation now": drop the queued-but-
    // undispatched turns first so they don't dispatch after the cancel. The
    // in-flight turn (if any) ends via the agent's cancellation, which
    // resolves its `session/prompt` future and settles the accounting.
    final state = _turnStates[sessionId];
    if (state != null) {
      state.generation++;
      var removedQueuedPrompt = false;
      for (final entry in state.queue) {
        if (entry.phase == _QueuedAcpPromptPhase.queued) {
          entry.phase = _QueuedAcpPromptPhase.cancelled;
          removedQueuedPrompt = true;
        }
      }
      if (removedQueuedPrompt) {
        state.queue.removeWhere((entry) => entry.phase == _QueuedAcpPromptPhase.cancelled);
        _emitQueueUpdate(sessionId: sessionId, state: state);
      }
    }
    if (_isPromptFrameWriting(sessionId: sessionId)) _cancelledPromptWriteSessions.add(sessionId);
    final client = _client;
    if (client == null) return;
    client.notify(
      method: AcpMethods.sessionCancel,
      params: {"sessionId": sessionId},
    );
    // ACP requires the client to resolve any permission/question the cancelled
    // turn was blocked on; otherwise the agent keeps waiting on that JSON-RPC
    // request and the phone shows a stale prompt.
    _approvalRegistry?.cancelForSession(sessionId: sessionId);
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        for (final summary in getActiveSessionsSummary())
          for (final session in summary.activeSessions) ...[session.id, ...session.childSessionIds],
        ...?_approvalRegistry?.pendingSessionIds,
      };
      if (activeSessionIds.isEmpty) return const <String>{};

      await Future.wait([
        for (final sessionId in activeSessionIds) _abortSession(sessionId: sessionId),
      ]);
      if (currentWorkState != PluginWorkState.idle) {
        await workState.firstWhere((state) => state == PluginWorkState.idle);
      }
      return Set<String>.unmodifiable(activeSessionIds);
    }().timeout(budget);
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    // ACP has no standard rename; honour the contract optimistically so any
    // local UI cache stays consistent. The mobile DB is authoritative.
    final directory = directoryForSession(sessionId: sessionId);
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
    final state = _turnStates[sessionId];
    if ((state?.pending ?? 0) > 0) {
      await _abortSession(sessionId: sessionId);
    }
    _approvalRegistry?.cancelForSession(sessionId: sessionId);
    final canClose = _initResult?.agentCapabilities.closeSession ?? false;
    if (canClose && _residentSessions.contains(sessionId)) {
      try {
        await state?.activeSettlement?.future.timeout(
          sessionCloseSettlementTimeout,
        );
        await AcpAgentApi(client: await _connectedClient()).closeSession(
          sessionId: sessionId,
          timeout: AcpAgentApi.defaultRequestTimeout,
        );
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          PluginOperationException(
            "deleteSession",
            message: "ACP session did not settle and close",
            cause: error,
          ),
          stackTrace,
        );
      }
    }
    _turnStates.remove(sessionId);
    _pendingSelections.remove(sessionId);
    _inFlightTurnSessions.remove(sessionId);
    if (_lastTurnSessionId == sessionId) _lastTurnSessionId = null;
    _sessionStatuses.remove(sessionId);
    _syntheticInitialPromptSessions.remove(sessionId);
    _residentSessions.remove(sessionId);
    _sessionDirectories.remove(sessionId);
    _sessionOptionsService.forgetSession(sessionId: sessionId);
    // Drops the session's project attribution plus all other per-session mapper
    // caches (turn counters, started parts, live tools) so nothing accumulates
    // for a deleted session. Provider/model state is cleared from its tracker
    // independently above.
    eventMapper.forgetSession(sessionId);
    childSessionTracker.forgetSession(sessionId: sessionId);
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
  Future<List<PluginSession>> getChildSessions(String sessionId) async => const [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => Map.unmodifiable(_sessionStatuses);

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
      // Replayed messages must carry the same `agent` the live mapper stamps,
      // or a reloaded session reports a different agent than the live one did.
      agentId: eventMapper.pluginId,
      initialUserMessageId: _syntheticInitialPromptSessions.contains(sessionId)
          ? AcpEventMapper.initialUserMessageId(sessionId)
          : null,
      messageIdOverride: null,
      messageTimeResolver: null,
      // Reclassify a halt notice (e.g. Cursor's account/plan gate) the same way
      // the live stream does, so reloaded history renders it identically.
      haltClassifier: eventMapper.classifyHaltNotice,
    );
    List<PluginMessageWithParts> buildReplay() => collector.buildWithAssistantSelection(
      modelId: eventMapper.modelForSession(sessionId: sessionId),
      providerId: eventMapper.providerForSession(sessionId: sessionId),
      variant: replayVariantForSession(sessionId: sessionId),
    );
    StreamSubscription<AcpNotification>? sub;
    AcpCommandListener? commandListener;
    List<BridgeSseEvent>? deferredCommandRefresh;
    void flushDeferredCommandRefresh() {
      final events = deferredCommandRefresh;
      if (events == null) return;
      deferredCommandRefresh = null;
      events.forEach(_eventBuffer.add);
    }

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
            deferredCommandRefresh = eventMapper.map(notification);
          }
        }
      });
      final AcpNewSessionResult result;
      try {
        result = await AcpAgentApi(client: replayClient).loadSession(
          sessionId: sessionId,
          cwd: directoryForSession(sessionId: sessionId),
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
          flushDeferredCommandRefresh();
          return buildReplay();
        }
        // Any other RPC error is a genuine load failure — wrapped typed below.
        rethrow;
      }
      // The load result also carries the model/mode catalog (and the loaded
      // session's current model) — capture it so the picker is populated and
      // replayed messages are stamped with the session's real model.
      captureSessionConfig(result, sessionId: sessionId, fromNewSession: false);
      // The ACP spec replays the whole thread via `session/update` BEFORE the
      // `session/load` response resolves, but cursor-agent streams later turns
      // AFTER it. Drain until the replay stream goes quiet so multi-turn history
      // is captured in full, bounded so a chatty agent can't hang the request.
      await _drainReplay(() => received);
      flushDeferredCommandRefresh();
      return buildReplay();
    } on PluginAuthenticationRequiredException {
      flushDeferredCommandRefresh();
      rethrow;
    } on Object catch (error, stackTrace) {
      flushDeferredCommandRefresh();
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
    return _sessionOptionsService.getSessionOptions().agents;
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    return _sessionOptionsService.getSessionOptions().providers;
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async => _approvalRegistry?.pendingForSession(sessionId: sessionId) ?? const [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async => _approvalRegistry?.pendingPermissionsForSession(sessionId: sessionId) ?? const [];

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
        .where((sessionId) => directoryForSession(sessionId: sessionId) == target)
        .toList(growable: false);
    return registry.pendingForProject(sessionIds: sessionIds);
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    _approvalRegistry?.replyQuestion(requestId: questionId, answers: answers);
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    // The registry is keyed by the bridge question id; it already knows the
    // session (and clears the pending entry, so awaiting-input drops), so the
    // sessionId argument is not needed here.
    _approvalRegistry?.rejectQuestion(requestId: questionId);
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    _approvalRegistry?.replyPermission(requestId: requestId, reply: reply);
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
      final awaiting = registry?.hasPendingInput(sessionId: sessionId) ?? false;
      if (!running && !awaiting) continue;
      (byProject[directoryForSession(sessionId: sessionId)] ??= []).add(
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
      for (final entry in byProject.entries) PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  Future<void> dispose() async {
    // dispose() must not throw — every step below is isolated (see
    // [_teardownConnection]); the stream closes are best-effort too.
    await _teardownConnection();
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
    try {
      await _authenticationFailures.close();
    } on Object catch (e, st) {
      Log.w("[$id] failed to close authentication-failure stream", e, st);
    }
    try {
      await _workState.close();
    } on Object catch (e, st) {
      Log.w("[$id] failed to close work-state stream", e, st);
    }
  }

  void _syncWorkState() {
    final busy =
        _turnStates.values.any((state) => state.pending > 0) || (_approvalRegistry?.hasAnyPendingInput ?? false);
    _workState.set(busy ? PluginWorkState.busy : PluginWorkState.idle);
  }
}

/// Mutable per-session turn-queue fields. [AcpPlugin] owns all the logic —
/// this only carries the chain tail the session's turns serialize behind, the
/// count of unfinished turns, and the abort generation used to drop
/// queued-but-undispatched turns.
class _SessionTurnState() {
  static const int _recentPromptLimit = 64;

  /// Completion of the session's most recently queued turn.
  Future<void> tail = Future<void>.value();

  /// Settlement of this session's currently executing connect/load/selection/
  /// prompt operation. Queued turns blocked on another session's process lane
  /// do not participate in deletion's close deadline.
  Completer<void>? activeSettlement;

  /// Turns enqueued but not yet finished (including the running one).
  int pending = 0;

  /// Existing-session prompts accepted but not yet dispatched to ACP.
  final List<_QueuedAcpPrompt> queue = [];

  final Queue<String> _recentPromptIds = Queue<String>();

  bool hasAcceptedPrompt({required String promptId}) =>
      queue.any((entry) => entry.presentation.id == promptId) || _recentPromptIds.contains(promptId);

  void recordDispatchedPrompt({required String promptId}) {
    _recentPromptIds.addLast(promptId);
    while (_recentPromptIds.length > _recentPromptLimit) {
      _recentPromptIds.removeFirst();
    }
  }

  /// Bumped by abort/delete; a queued turn dispatches only if the generation
  /// it captured at enqueue time is still current.
  int generation = 0;
}

sealed class const _AcpTurn({
  required final List<Map<String, dynamic>> blocks,
  required final String messageId,
  required final ({String providerID, String modelID})? model,
  required final PluginSessionVariant? variant,
  required final String? agent,
});

final class const _InitialAcpTurn({
  required super.blocks,
  required super.messageId,
  required super.model,
  required super.variant,
  required super.agent,
}) extends _AcpTurn;

final class const _QueuedAcpTurn({
  required super.blocks,
  required super.messageId,
  required super.model,
  required super.variant,
  required super.agent,
  required final _QueuedAcpPrompt queuedPrompt,
}) extends _AcpTurn;

class _QueuedAcpPrompt({
  required final PluginQueuedPrompt presentation,
  required final List<PluginPromptPart> visibleParts,
}) {
  _QueuedAcpPromptPhase phase = _QueuedAcpPromptPhase.queued;
}

enum _QueuedAcpPromptPhase() {
  queued,
  writing,
  cancelled,
}

class const _TurnSelection({
  required final ({String providerID, String modelID})? model,
  required final PluginSessionVariant? variant,
  required final String? agent,
});
