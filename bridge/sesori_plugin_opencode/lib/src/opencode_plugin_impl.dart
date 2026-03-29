import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../opencode_plugin.dart";
import "sse/sse_connection.dart";

class OpenCodePlugin implements BridgePlugin {
  final OpenCodeService _service;
  final SseEventParser _parser;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final String _serverUrl;
  final String? _password;
  late final SseConnection _sseConnection;

  OpenCodePlugin({
    required String serverUrl,
    String? password,
  }) : _serverUrl = serverUrl,
       _password = password,
       _service = _createService(serverUrl, password),
       _parser = SseEventParser(),
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>() {
    _sseConnection = SseConnection(
      targetUrl: serverUrl,
      password: password,
      onEvent: _handleRawSseEvent,
      onReconnect: () async {
        _service.reset();
        await _service.coldStart();
        _emitProjectsSummary();
      },
    );
    unawaited(_initialize());
  }

  static OpenCodeService _createService(String serverUrl, String? password) {
    final api = OpenCodeApi(serverURL: serverUrl, password: password);
    final repository = OpenCodeRepository(api);
    final tracker = ActiveSessionTracker(repository);
    return OpenCodeService(repository, tracker);
  }

  Future<void> _initialize() async {
    try {
      await _service.coldStart();
      _emitProjectsSummary();
    } catch (_) {
      // Initialization errors should not crash plugin creation.
    }
    _sseConnection.start();
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on OpenCodeApiException catch (e) {
      throw PluginApiException(e.endpoint, e.statusCode);
    }
  }

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  @override
  Future<String> healthCheck() async {
    final client = http.Client();
    try {
      final headers = <String, String>{};
      if (_password != null) {
        final creds = base64.encode(utf8.encode("opencode:$_password"));
        headers["Authorization"] = "Basic $creds";
      }
      final response = await client
          .get(Uri.parse("$_serverUrl/global/health"), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.body;
    } finally {
      client.close();
    }
  }

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    final response = await _call(_service.repository.api.listProviders);
    final connectedIds = response.connected.toSet();
    final source = connectedOnly ? response.all.where((p) => connectedIds.contains(p.id)).toList() : response.all;
    final providers = source.map((providerInfo) {
      final models = providerInfo.models.values
          .map((m) => PluginModel(id: m.id, name: m.name, family: m.family))
          .toList();
      return _mapProvider(
        id: providerInfo.id,
        name: providerInfo.name,
        models: models,
        defaultModels: response.defaults,
      );
    }).toList();
    return PluginProvidersResult(providers: providers);
  }

  PluginProvider _mapProvider({
    required String id,
    required String name,
    required List<PluginModel> models,
    required Map<String, String> defaultModels,
  }) {
    final defaultModelID = defaultModels[id];

    return switch (id.toLowerCase()) {
      "anthropic" => PluginProvider.anthropic(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "openai" => PluginProvider.openAI(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "google" => PluginProvider.google(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "mistral" => PluginProvider.mistral(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "groq" => PluginProvider.groq(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "xai" => PluginProvider.xAI(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "deepseek" => PluginProvider.deepseek(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "amazon-bedrock" || "bedrock" => PluginProvider.amazonBedrock(
        id: id,
        name: name,
        authType: PluginProviderAuthType.unknown,
        models: models,
        defaultModelID: defaultModelID,
      ),
      "azure" => PluginProvider.azure(
        id: id,
        name: name,
        authType: PluginProviderAuthType.apiKey,
        models: models,
        defaultModelID: defaultModelID,
      ),
      _ => PluginProvider.custom(
        id: id,
        name: name,
        authType: PluginProviderAuthType.unknown,
        models: models,
        defaultModelID: defaultModelID,
      ),
    };
  }

  @override
  Future<void> dispose() async {
    _sseConnection.stop();
    await _eventBuffer.close();
  }

  @override
  Future<List<PluginProject>> getProjects() async {
    return (await _call(_service.getProjects)).map((project) => project.toPlugin()).toList();
  }

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final sessions = await _call(
      () => _service.getSessions(
        worktree: projectId,
        start: start,
        limit: limit,
      ),
    );
    for (final session in sessions) {
      _service.tracker.registerSession(
        sessionId: session.id,
        directory: session.directory,
      );
    }
    return sessions.map((session) => session.toPlugin()).toList();
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    String? parentSessionId,
  }) async {
    final session = await _call(
      () => _service.repository.api.createSession(
        directory: directory,
        parentSessionId: parentSessionId,
      ),
    );
    _service.tracker.registerSession(
      sessionId: session.id,
      directory: session.directory,
    );
    return session.toPlugin();
  }

  @override
  Future<PluginSession> updateSessionArchiveStatus(String sessionId, {required bool archived}) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);

    if (archived) {
      final session = await _call(
        () => _service.repository.api.updateSession(
          sessionId: sessionId,
          directory: directory,
          body: {
            "time": {
              "archived": DateTime.now().millisecondsSinceEpoch,
            },
          },
        ),
      );
      return session.toPlugin();
    }

    final original = await _call(
      () => _service.repository.api.getSession(
        sessionId: sessionId,
        directory: directory,
      ),
    );

    final forked = await _call(
      () => _service.repository.api.forkSession(
        sessionId: sessionId,
        directory: directory,
      ),
    );

    _service.tracker.registerSession(
      sessionId: forked.id,
      directory: forked.directory,
    );

    try {
      await _call(
        () => _service.repository.api.deleteSession(
          sessionId: sessionId,
          directory: directory,
        ),
      );
    } on Object catch (e) {
      Log.w("Unarchive: failed to delete original session $sessionId: $e");
    }

    try {
      final renamed = await _call(
        () => _service.repository.api.updateSession(
          sessionId: forked.id,
          directory: directory,
          body: {"title": original.title},
        ),
      );
      return renamed.toPlugin();
    } on Object catch (e) {
      Log.w("Unarchive: failed to rename forked session ${forked.id}: $e");
      return forked.toPlugin();
    }
  }

  @override
  Future<void> deleteSession(String sessionId) {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    return _call(
      () => _service.repository.api.deleteSession(
        sessionId: sessionId,
        directory: directory,
      ),
    );
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    final sessions = await _call(
      () => _service.repository.api.getChildren(
        sessionId: sessionId,
        directory: directory,
      ),
    );
    return sessions.map((session) => session.toPlugin()).toList();
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async {
    final apiStatuses = await _call(_service.repository.api.getSessionStatuses);

    // Start with the API response as a baseline.
    final merged = apiStatuses.map((key, value) => MapEntry(key, value.toPlugin()));

    // Overlay the tracker's real-time active statuses. The tracker is
    // maintained by SSE events and accurately reflects which sessions are
    // busy/retry. The API response may be scoped by OpenCode's directory
    // context and miss sessions from other projects.
    final activeStatuses = _service.tracker.getActiveStatuses();
    for (final entry in activeStatuses.entries) {
      merged[entry.key] = entry.value.toPlugin();
    }

    return merged;
  }

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    final messages = await _call(
      () => _service.getMessages(
        sessionId: sessionId,
        directory: directory,
      ),
    );
    return messages.map(_mapMessage).toList();
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);

    if (directory == null) {
      Log.w("directory missing for session $sessionId. Defaulting to bridge CWD as directory.");
    }

    final body = <String, dynamic>{
      "parts": parts.map((part) {
        return switch (part) {
          PluginPromptPartText(:final text) => <String, dynamic>{
            "type": "text",
            "text": text,
          },
        };
      }).toList(),
      "agent": ?agent,
      if (model != null)
        "model": {
          "providerID": model.providerID,
          "modelID": model.modelID,
        },
    };

    return _call(
      () => _service.repository.api.sendPrompt(
        sessionId: sessionId,
        directory: directory,
        body: body,
      ),
    );
  }

  @override
  Future<void> abortSession({required String sessionId}) {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    return _call(
      () => _service.repository.api.abortSession(
        sessionId: sessionId,
        directory: directory,
      ),
    );
  }

  @override
  Future<List<PluginAgent>> getAgents() async {
    final agents = await _call(_service.repository.api.listAgents);
    return agents.map((agent) => agent.toPlugin()).toList();
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    final pending = await _call(
      () => _service.repository.api.getPendingQuestions(
        directory: directory,
      ),
    );
    return pending //
        .where((e) => e.sessionID == sessionId)
        .map((question) => question.toPlugin())
        .toList();
  }

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final pending = await _call(
      () => _service.repository.api.getPendingQuestions(
        directory: projectId,
      ),
    );
    return pending.map((question) => question.toPlugin()).toList();
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    return _call(
      () => _service.repository.api.replyToQuestion(
        questionId: questionId,
        directory: directory,
        body: {
          "answers": answers,
        },
      ),
    );
  }

  @override
  Future<void> rejectQuestion(String questionId) {
    return _call(
      () => _service.repository.api.rejectQuestion(
        questionId: questionId,
      ),
    );
  }

  @override
  Future<PluginProject> getProject(String projectId) async {
    final project = await _call(
      () => _service.repository.api.getProject(
        directory: projectId,
      ),
    );
    return project.toPlugin();
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    final session = await _call(
      () => _service.repository.api.updateSession(
        sessionId: sessionId,
        directory: directory,
        body: {"title": title},
      ),
    );
    return session.toPlugin();
  }

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async {
    // CRITICAL: projectId is the worktree path (PluginProject.id = worktree, see project.dart:33)
    // Must resolve the real OpenCode project UUID before calling PATCH
    final project = await _call(
      () => _service.repository.api.getProject(directory: projectId),
    );
    final updated = await _call(
      () => _service.repository.api.updateProject(
        projectId: project.id,
        directory: projectId,
        body: {"name": name},
      ),
    );
    return updated.toPlugin();
  }

  void _handleRawSseEvent(String rawData) {
    try {
      final parseResult = _parser.parse(rawData);
      final event = parseResult.event;
      if (event == null) return;

      final changed = _service.handleSseEvent(event, parseResult.directory);
      if (changed) {
        _emitProjectsSummary();
      }

      final bridgeEvent = _mapSseEvent(event);
      if (bridgeEvent != null) {
        _eventBuffer.add(bridgeEvent);
      }
    } catch (e, st) {
      Log.e("[opencode] SSE event processing error: $e\n$st");
    }
  }

  void _emitProjectsSummary() {
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  PluginMessageWithParts _mapMessage(MessageWithParts raw) {
    final info = raw.info;
    final parts = raw.parts;
    return PluginMessageWithParts(
      info: PluginMessage(
        role: info.role,
        id: info.id,
        sessionID: info.sessionID,
        agent: info.agent,
        modelID: info.modelID,
        providerID: info.providerID,
      ),
      parts: parts.map(_mapMessagePart).where((p) => p.type.isVisible).toList(),
    );
  }

  /// Maps an OpenCode part type string to [PluginMessagePartType].
  /// Unknown types are mapped to [PluginMessagePartType.unknown] (invisible)
  /// and logged as a warning so new types are noticed.
  static PluginMessagePartType _toPluginPartType({required String type}) => switch (type) {
    "text" => PluginMessagePartType.text,
    "reasoning" => PluginMessagePartType.reasoning,
    "tool" => PluginMessagePartType.tool,
    "subtask" => PluginMessagePartType.subtask,
    "step-start" => PluginMessagePartType.stepStart,
    "step-finish" => PluginMessagePartType.stepFinish,
    "file" => PluginMessagePartType.file,
    "snapshot" => PluginMessagePartType.snapshot,
    "patch" => PluginMessagePartType.patch,
    "agent" => PluginMessagePartType.agent,
    "retry" => PluginMessagePartType.retry,
    "compaction" => PluginMessagePartType.compaction,
    _ => () {
      Log.w("Unknown message part type: '$type' — filtering out");
      return PluginMessagePartType.unknown;
    }(),
  };

  PluginMessagePart _mapMessagePart(MessagePart raw) {
    return PluginMessagePart(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      type: _toPluginPartType(type: raw.type),
      text: raw.text,
      tool: raw.tool,
      state: switch (raw.state) {
        ToolState(:final status, :final title, :final output, :final error) => PluginToolState(
          status: status,
          title: title,
          output: output != null && output.length > maxToolOutputLength
              ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
              : output,
          error: error,
        ),
        null => null,
      },
      prompt: raw.prompt,
      description: raw.description,
      agent: raw.agent,
      agentName: raw.name,
      attempt: raw.attempt,
      retryError: (raw.error?['data'] as Map<String, dynamic>?)?['message']?.toString(),
    );
  }

  BridgeSseEvent? _mapSseEvent(SseEventData event) {
    return switch (event) {
      SseServerConnected() => const BridgeSseServerConnected(),
      SseServerHeartbeat() => const BridgeSseServerHeartbeat(),
      SseServerInstanceDisposed(:final directory) => BridgeSseServerInstanceDisposed(directory: directory),
      SseGlobalDisposed() => const BridgeSseGlobalDisposed(),
      SseSessionCreated(:final info) => BridgeSseSessionCreated(info: info.toJson()),
      SseSessionUpdated(:final info) => BridgeSseSessionUpdated(info: info.toJson()),
      SseSessionDeleted(:final info) => BridgeSseSessionDeleted(info: info.toJson()),
      SseSessionDiff(:final sessionID) => BridgeSseSessionDiff(
        sessionID: sessionID,
      ),
      SseSessionError(:final sessionID) => BridgeSseSessionError(sessionID: sessionID),
      SseSessionCompacted(:final sessionID) => BridgeSseSessionCompacted(sessionID: sessionID),
      SseSessionStatus(:final sessionID, :final status) => BridgeSseSessionStatus(
        sessionID: sessionID,
        status: status.toJson(),
      ),
      // ignore: deprecated_member_use, forwards legacy idle event for backward compatibility
      SseSessionIdle(:final sessionID) => BridgeSseSessionIdle(sessionID: sessionID),
      SseMessageUpdated(:final info) => BridgeSseMessageUpdated(info: info.toJson()),
      SseMessageRemoved(:final sessionID, :final messageID) => BridgeSseMessageRemoved(
        sessionID: sessionID,
        messageID: messageID,
      ),
      SseMessagePartUpdated(:final part) => BridgeSseMessagePartUpdated(part: _mapMessagePart(part)),
      SseMessagePartDelta(
        :final sessionID,
        :final messageID,
        :final partID,
        :final field,
        :final delta,
      ) =>
        BridgeSseMessagePartDelta(
          sessionID: sessionID,
          messageID: messageID,
          partID: partID,
          field: field,
          delta: delta,
        ),
      SseMessagePartRemoved(:final sessionID, :final messageID, :final partID) => BridgeSseMessagePartRemoved(
        sessionID: sessionID,
        messageID: messageID,
        partID: partID,
      ),
      SsePtyCreated() => const BridgeSsePtyCreated(),
      SsePtyUpdated() => const BridgeSsePtyUpdated(),
      SsePtyExited(:final id, :final exitCode) => BridgeSsePtyExited(id: id, exitCode: exitCode),
      SsePtyDeleted(:final id) => BridgeSsePtyDeleted(id: id),
      SsePermissionAsked(:final requestID, :final sessionID, :final tool, :final description) =>
        BridgeSsePermissionAsked(
          requestID: requestID,
          sessionID: sessionID,
          tool: tool,
          description: description,
        ),
      SsePermissionReplied(:final requestID, :final reply) => BridgeSsePermissionReplied(
        requestID: requestID,
        reply: reply,
      ),
      SsePermissionUpdated() => const BridgeSsePermissionUpdated(),
      SseQuestionAsked(:final id, :final sessionID, :final questions) => BridgeSseQuestionAsked(
        id: id,
        sessionID: sessionID,
        questions: questions.map((q) => q.toJson()).toList(),
      ),
      SseQuestionReplied(:final requestID, :final sessionID) => BridgeSseQuestionReplied(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseQuestionRejected(:final requestID, :final sessionID) => BridgeSseQuestionRejected(
        requestID: requestID,
        sessionID: sessionID,
      ),
      SseTodoUpdated(:final sessionID) => BridgeSseTodoUpdated(sessionID: sessionID),
      SseProjectUpdated() => const BridgeSseProjectUpdated(),
      SseVcsBranchUpdated() => const BridgeSseVcsBranchUpdated(),
      SseFileEdited(:final file) => BridgeSseFileEdited(file: file),
      SseFileWatcherUpdated(:final file, :final event) => BridgeSseFileWatcherUpdated(file: file, event: event),
      SseLspUpdated() => const BridgeSseLspUpdated(),
      SseLspClientDiagnostics(:final serverID, :final path) => BridgeSseLspClientDiagnostics(
        serverID: serverID,
        path: path,
      ),
      SseMcpToolsChanged() => const BridgeSseMcpToolsChanged(),
      SseMcpBrowserOpenFailed() => const BridgeSseMcpBrowserOpenFailed(),
      SseInstallationUpdated(:final version) => BridgeSseInstallationUpdated(version: version),
      SseInstallationUpdateAvailable(:final version) => BridgeSseInstallationUpdateAvailable(version: version),
      SseWorkspaceReady(:final name) => BridgeSseWorkspaceReady(name: name),
      SseWorkspaceFailed(:final message) => BridgeSseWorkspaceFailed(message: message),
      SseTuiToastShow(:final title, :final message, :final variant) => BridgeSseTuiToastShow(
        title: title,
        message: message,
        variant: variant,
      ),
      SseWorktreeReady() => const BridgeSseWorktreeReady(),
      SseWorktreeFailed() => const BridgeSseWorktreeFailed(),
    };
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    return _service
        .buildSummary()
        .map(
          (s) => PluginProjectActivitySummary(
            id: s.id,
            activeSessions: s.activeSessions
                .map(
                  (a) => PluginActiveSession(
                    id: a.id,
                    mainAgentRunning: a.mainAgentRunning,
                    childSessionIds: a.childSessionIds,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }
}
