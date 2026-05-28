import "dart:async";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_approval_registry.dart";
import "acp_event_mapper.dart";
import "acp_process_factory.dart";
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
  }) : _processFactory = processFactory,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  @override
  final String id;

  /// Human-facing agent name used for synthesized agents/providers.
  final String agentDisplayName;

  final AcpLaunchSpec launchSpec;

  /// Bridge launch CWD — the single synthesized project id.
  final String projectCwd;

  /// The live event mapper (subclasses may pass a specialized one).
  final AcpEventMapper eventMapper;

  final AcpProcessFactory? _processFactory;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;

  AcpStdioClient? _client;
  Future<bool>? _connectFuture;
  StreamSubscription<AcpNotification>? _notificationSubscription;
  AcpApprovalRegistry? _approvalRegistry;
  AcpInitializeResult? _initResult;

  final Map<String, PluginSessionStatus> _sessionStatuses = {};
  final Set<String> _activeSessions = {};

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

  /// Applies model selection after `session/new`. Base does nothing (the
  /// agent's default model is used). Cursor overrides for its config-option
  /// model picker.
  Future<void> applyModelSelection(
    AcpStdioClient client,
    AcpNewSessionResult session,
    ({String providerID, String modelID})? model,
  ) async {}

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
          eventMapper.map(notification).forEach(_eventBuffer.add);
        });
        final registry = buildApprovalRegistry(client);
        _approvalRegistry = registry;
        registry.attach(client.serverRequests);
        await _initialize(client);
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

  Future<void> _initialize(AcpStdioClient client) async {
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
    _initResult = init;
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
  }

  Future<AcpStdioClient> _connectedClient() async {
    final ok = await ensureConnected();
    final client = _client;
    if (!ok || client == null) {
      throw StateError("$id agent is not connected");
    }
    return client;
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return await ensureConnected();
    } catch (_) {
      return false;
    }
  }

  PluginProject _synthesizedProject() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = p.basename(projectCwd);
    return PluginProject(
      id: projectCwd,
      name: base.isEmpty ? projectCwd : base,
      time: PluginProjectTime(created: now, updated: now),
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
          .map((s) => _toPluginSession(s.cast<String, dynamic>()))
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

  PluginSession _toPluginSession(Map<String, dynamic> raw) {
    final updated = raw["updatedAt"];
    final ts = updated is num ? updated.round() : null;
    return PluginSession(
      id: (raw["sessionId"] ?? "") as String,
      projectID: projectCwd,
      directory: (raw["cwd"] as String?) ?? projectCwd,
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
    await applyModelSelection(client, session, model);
    _sessionStatuses[session.sessionId] = const PluginSessionStatus.idle();
    if (parts.isNotEmpty) {
      _dispatchPrompt(client, session.sessionId, parts);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return PluginSession(
      id: session.sessionId,
      projectID: projectCwd,
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
    _dispatchPrompt(client, sessionId, [PluginPromptPart.text(text: body)]);
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
    return PluginSession(
      id: sessionId,
      projectID: projectCwd,
      directory: projectCwd,
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
    final base = _synthesizedProject();
    return PluginProject(id: base.id, name: name, time: base.time);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (_activeSessions.contains(sessionId)) {
      await abortSession(sessionId: sessionId);
    }
    _activeSessions.remove(sessionId);
    _sessionStatuses.remove(sessionId);
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
      modelId: eventMapper.currentModelId,
      providerId: eventMapper.currentProviderId,
    );
    StreamSubscription<AcpNotification>? sub;
    try {
      await replayClient.connect();
      await _initialize(replayClient);
      if (!replayClient.isConnected ||
          !(_initResult?.agentCapabilities.loadSession ?? false)) {
        return const [];
      }
      sub = replayClient.notifications.listen((notification) {
        if (notification.method == AcpMethods.sessionUpdate) {
          collector.consume(notification.params);
        }
      });
      await replayClient.request(
        method: AcpMethods.sessionLoad,
        params: {
          "sessionId": sessionId,
          "cwd": projectCwd,
          "mcpServers": const <Object?>[],
        },
        timeout: const Duration(minutes: 2),
      );
      return collector.build();
    } catch (_) {
      return const [];
    } finally {
      await sub?.cancel();
      await replayClient.dispose();
    }
  }

  @override
  Future<List<PluginAgent>> getAgents() async {
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
  Future<void> rejectQuestion(String questionId) async {
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
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => const [];

  @override
  Future<void> dispose() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _approvalRegistry?.dispose();
    _approvalRegistry = null;
    await _client?.dispose();
    _client = null;
    await _eventBuffer.close();
  }
}
