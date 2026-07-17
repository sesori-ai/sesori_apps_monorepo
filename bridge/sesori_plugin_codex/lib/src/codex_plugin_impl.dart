import "dart:async";
import "dart:io" show Directory;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/codex_app_server_api.dart";
import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_config_reader.dart";
import "codex_event_mapper.dart";
import "codex_metadata_repository.dart";
import "codex_skill_reader.dart";
import "dispatchers/codex_command_event_dispatcher.dart";
import "listeners/codex_keepalive_listener.dart";
import "repositories/codex_app_server_repository.dart";
import "repositories/codex_message_repository.dart";
import "repositories/models/codex_app_server_repository_models.dart";
import "runtime/codex_managed_api.dart";
import "services/codex_history_service.dart";
import "services/codex_turn_service.dart";
import "session_rollout_reader.dart";
import "trackers/codex_command_invocation_tracker.dart";
import "trackers/codex_context_tracker.dart";
import "trackers/codex_thread_residency_tracker.dart";

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
  final CodexMessageRepository _messageRepository;
  final CodexMetadataRepository _metadataRepository;
  final CodexContextTracker _contextTracker;
  final CodexCommandInvocationTracker _commandTracker;
  final CodexCommandEventDispatcher _commandEventDispatcher;
  final CodexEventMapper _eventMapper;
  final CodexHistoryService _historyService;
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
  CodexKeepaliveListener? _keepaliveListener;
  CodexTurnService? _turnService;
  Future<bool>? _connectFuture;
  StreamSubscription<CodexEventRecord>? _notificationSubscription;
  ApprovalRegistry? _approvalRegistry;

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
    final resolvedMetadataRepository =
        metadataRepository ??
        CodexMetadataRepository(
          skillReader: CodexSkillReader(),
          rolloutReader: resolvedRolloutReader,
          configReader: resolvedConfigReader,
          launchDirectory: resolvedProjectCwd,
        );
    final resolvedEventMapper = eventMapper ?? const CodexEventMapper();
    final contextTracker = CodexContextTracker(
      pluginId: pluginId,
      launchDirectory: resolvedProjectCwd,
      defaults: resolvedConfigReader.readDefaults(),
    );
    final commandTracker = CodexCommandInvocationTracker();
    final commandEventDispatcher = CodexCommandEventDispatcher(
      tracker: commandTracker,
    );
    final messageRepository = CodexMessageRepository(
      rolloutReader: resolvedRolloutReader,
      configReader: resolvedConfigReader,
    );
    return CodexPlugin._(
      serverUrl: serverUrl,
      capabilityToken: capabilityToken,
      // When null, [_ensureConnected] builds the default client so it can wire
      // the client's `onDisconnected` through [_handleClientDisconnected].
      clientFactory: clientFactory,
      rolloutReader: resolvedRolloutReader,
      messageRepository: messageRepository,
      metadataRepository: resolvedMetadataRepository,
      contextTracker: contextTracker,
      commandTracker: commandTracker,
      commandEventDispatcher: commandEventDispatcher,
      eventMapper: resolvedEventMapper,
      historyService: CodexHistoryService(
        messageRepository: messageRepository,
        metadataRepository: resolvedMetadataRepository,
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
    required CodexMessageRepository messageRepository,
    required CodexMetadataRepository metadataRepository,
    required CodexContextTracker contextTracker,
    required CodexCommandInvocationTracker commandTracker,
    required CodexCommandEventDispatcher commandEventDispatcher,
    required CodexEventMapper eventMapper,
    required CodexHistoryService historyService,
    required String projectCwd,
    void Function()? onConnected,
    void Function()? onDisconnected,
    Duration keepaliveInterval = const Duration(seconds: 30),
  }) : _serverUrl = serverUrl,
       _keepaliveInterval = keepaliveInterval,
       _capabilityToken = capabilityToken,
       _clientFactory = clientFactory,
       _rolloutReader = rolloutReader,
       _messageRepository = messageRepository,
       _metadataRepository = metadataRepository,
       _contextTracker = contextTracker,
       _commandTracker = commandTracker,
       _commandEventDispatcher = commandEventDispatcher,
       _eventMapper = eventMapper,
       _historyService = historyService,
       _projectCwd = projectCwd,
       _onConnected = onConnected,
       _onDisconnected = onDisconnected,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  String get serverUrl => _serverUrl;

  @override
  String get id => pluginId;

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

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
        final api = CodexAppServerApi(client: client);
        final repository = CodexAppServerRepository(
          api: api,
        );
        final turnService = CodexTurnService(
          repository: repository,
          contextTracker: _contextTracker,
          commandTracker: _commandTracker,
          residencyTracker: CodexThreadResidencyTracker(),
          messageRepository: _messageRepository,
          launchDirectory: _projectCwd,
        );
        final keepaliveListener = CodexKeepaliveListener(
          turnService: turnService,
          interval: _keepaliveInterval,
        );
        _keepaliveListener = keepaliveListener;
        _turnService = turnService;
        await _subscribeToNotifications(repository);
        _attachApprovalRegistry(client);
        keepaliveListener.start();
        _onConnected?.call();
        return true;
      } catch (error) {
        _keepaliveListener?.stop();
        _keepaliveListener = null;
        await client.dispose();
        _client = null;
        _turnService = null;
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
    _keepaliveListener?.stop();
    _keepaliveListener = null;
    _commandTracker.reset();
    _commandEventDispatcher.reset();
    _turnService = null;
    _onDisconnected?.call();
  }

  /// Wires the codex notification stream into the bridge event buffer,
  /// while side-effecting on a few notifications to keep session-status
  /// and turn-id bookkeeping current.
  Future<void> _subscribeToNotifications(
    CodexAppServerRepository repository,
  ) async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = repository.events.listen((event) {
      final contextFacts = event.context;
      if (contextFacts != null) _contextTracker.recordFacts(contextFacts);
      _turnService?.observe(event);
      final context = _contextTracker.snapshot(
        threadId: event.threadId,
        notificationDirectory: contextFacts?.directory,
      );
      final ordinaryEvents = _eventMapper.map(event, context: context);
      _commandEventDispatcher.handleEvent(event: event, ordinaryEvents: ordinaryEvents).forEach(_eventBuffer.add);
      if (event is CodexThreadClosedEventRecord) {
        final threadId = event.threadId;
        if (threadId != null) {
          _commandEventDispatcher.forgetThread(threadId: threadId);
          _contextTracker.forgetThread(threadId: threadId);
        }
      }
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
      _rolloutReader.listSessions().map(_toPluginSession).toList(growable: false);

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
  }) async {
    final records = _rolloutReader.listSessions();
    // Match on the normalized directory (not exact cwd) so the canonical project
    // id the bridge derives keeps matching a session's own cwd spelling. A
    // record with no cwd falls back to the launch cwd — the same fallback
    // [_toPluginSession] uses — so it stays listed under the project it derives
    // into instead of vanishing from that project's session list.
    final target = normalizeProjectDirectory(directory: projectId);
    final filtered = records.where((r) {
      final cwd = r.cwd ?? _projectCwd;
      return normalizeProjectDirectory(directory: cwd) == target;
    });
    final mapped = filtered.map(_toPluginSession).toList(growable: false);
    final from = start ?? 0;
    final until = limit == null ? mapped.length : (from + limit).clamp(0, mapped.length);
    if (from >= mapped.length) return const [];
    return mapped.sublist(from, until);
  }

  PluginSession _toPluginSession(CodexSessionRecord record) {
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    // The session belongs to the project for its own cwd — never the launch cwd
    // — so the bridge groups it under the right directory. Normalized so it
    // matches the canonical project id the bridge derives from the same value.
    final directory = normalizeProjectDirectory(directory: record.cwd ?? _projectCwd);
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: record.threadName,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

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
  }) async => (await _connectedTurnService()).createSession(
    directory: directory,
    parentSessionId: parentSessionId,
    parts: parts,
    variant: variant,
    model: _toCodexModel(model),
  );

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    await (await _connectedTurnService()).sendPrompt(
      sessionId: sessionId,
      parts: parts,
      variant: variant,
      model: _toCodexModel(model),
    );
  }

  @override
  Future<PluginCommandDispatch> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final service = await _connectedTurnService();
    try {
      final acceptance = await service.sendCommand(
        sessionId: sessionId,
        invocationId: invocationId,
        command: command,
        arguments: arguments,
        model: _toCodexModel(model),
        variant: variant,
      );
      _commandEventDispatcher.eventsForReturnedInvocation(invocation: acceptance.invocation).forEach(_eventBuffer.add);
      return acceptance.dispatch;
    } on CodexCommandAlreadyOutstandingException {
      rethrow;
    } on Object {
      _commandEventDispatcher.eventsForRejectedInvocation(threadId: sessionId).forEach(_eventBuffer.add);
      rethrow;
    }
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    await _turnService?.abort(sessionId: sessionId);
  }

  Future<CodexTurnService> _connectedTurnService() async {
    final ok = await _ensureConnected();
    final service = _turnService;
    if (!ok || service == null) {
      throw StateError("codex app-server turn service is not connected");
    }
    return service;
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    final service = await _connectedTurnService();
    await service.renameThread(threadId: sessionId, name: title);
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
    final known = _contextTracker.knownDirectory(threadId: sessionId);
    if (known != null) return known;
    for (final record in _rolloutReader.listSessions()) {
      if (record.id == sessionId) return normalizeProjectDirectory(directory: record.cwd ?? _projectCwd);
    }
    return normalizeProjectDirectory(directory: _projectCwd);
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
    final turnService = _turnService;
    if (turnService?.hasActiveTurn(threadId: sessionId) ?? false) {
      try {
        await abortSession(sessionId: sessionId);
      } catch (_) {
        // Continue with delete even if the abort raced.
      }
    }
    _rolloutReader.deleteSession(sessionId);
    turnService?.forgetThread(threadId: sessionId);
    _commandEventDispatcher.forgetThread(threadId: sessionId);
    _contextTracker.forgetThread(threadId: sessionId);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    try {
      final service = await _connectedTurnService();
      await service.archiveThread(threadId: sessionId);
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
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => _turnService?.statuses ?? const {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId, {
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) async {
    return _historyService.getMessages(
      sessionId: sessionId,
      projectId: _directoryForSession(sessionId),
      acceptedCommands: acceptedCommands,
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
    final sessionIds = (_turnService?.statuses.keys ?? const <String>[])
        .where((id) => _directoryForSession(id) == target)
        .toList(growable: false);
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
        if (model.hidden) continue;
        final id = model.id;
        if (id == null || id.isEmpty) continue;
        if (model.isDefault) defaultId = id;
        final displayName = model.displayName;
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
  List<String> _reasoningEffortVariants(CodexModelRecord model) {
    final efforts = <String>[];
    for (final token in model.supportedReasoningEfforts) {
      if (token.isNotEmpty && !efforts.contains(token)) {
        efforts.add(token);
      }
    }
    final defaultEffort = model.defaultReasoningEffort;
    if (defaultEffort != null && efforts.remove(defaultEffort)) {
      efforts.insert(0, defaultEffort);
    }
    return efforts;
  }

  /// Fetches codex's model catalog via the `model/list` RPC. Returns an empty
  /// list when the transport isn't connected or the call fails, so callers can
  /// fall back to the locally-derived default.
  Future<List<CodexModelRecord>> _listModels() async {
    final service = _turnService;
    if (service == null) return const [];
    return service.listModels();
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => const [];

  @override
  Future<void> dispose() async {
    _keepaliveListener?.stop();
    _keepaliveListener = null;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _approvalRegistry?.dispose();
    _approvalRegistry = null;
    await _client?.dispose();
    _client = null;
    _commandEventDispatcher.dispose();
    await _eventBuffer.close();
  }

  static CodexModelSelection? _toCodexModel(
    ({String providerID, String modelID})? model,
  ) {
    if (model == null || model.providerID.isEmpty || model.modelID.isEmpty) {
      return null;
    }
    return CodexModelSelection(
      providerId: model.providerID,
      modelId: model.modelID,
    );
  }
}
