import "dart:async";
import "dart:io" as io;

import "package:http/io_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../opencode_plugin.dart";
import "models/command.dart";
import "models/send_command_body.dart";
import "sse/sse_connection.dart";
import "sse_event_mapper.dart";

class OpenCodePlugin implements BridgePlugin {
  final OpenCodeService _service;
  final SseEventParser _parser;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final io.HttpClient _httpClient;
  final SseEventMapper _mapper = SseEventMapper();
  late final SseConnection _sseConnection;

  factory OpenCodePlugin({
    required String serverUrl,
    String? password,
  }) {
    final httpClient = io.HttpClient();
    final api = OpenCodeApi(
      serverURL: serverUrl,
      password: password,
      client: IOClient(httpClient),
    );
    final repository = OpenCodeRepository(api);
    final tracker = ActiveSessionTracker(repository);
    return OpenCodePlugin._(
      service: OpenCodeService(repository, tracker),
      httpClient: httpClient,
      serverUrl: serverUrl,
      password: password,
    );
  }

  OpenCodePlugin._({
    required OpenCodeService service,
    required io.HttpClient httpClient,
    required String serverUrl,
    required String? password,
  }) : _service = service,
       _httpClient = httpClient,
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
  Future<bool> healthCheck() {
    return _service.repository.api.healthCheck();
  }

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) {
    return _call(() => _service.getProviders(connectedOnly: connectedOnly));
  }

  @override
  Future<void> dispose() async {
    _sseConnection.stop();
    _httpClient.close(force: true);
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
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final commands = await _call(
      () => _service.repository.api.listCommands(directory: projectId),
    );
    return commands
        .map(
          (command) => PluginCommand(
            name: command.name,
            template: command.template,
            hints: command.hints,
            description: command.description,
            agent: command.agent,
            model: command.model,
            provider: command.provider,
            source: switch (command.source) {
              CommandSource.command => PluginCommandSource.command,
              CommandSource.mcp => PluginCommandSource.mcp,
              CommandSource.skill => PluginCommandSource.skill,
              CommandSource.unknown || null => PluginCommandSource.unknown,
            },
            subtask: command.subtask,
          ),
        )
        .toList();
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
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

    final body = SendPromptBody(parts: parts, agent: agent, model: model);

    if (parts.isNotEmpty) {
      await _call(
        () => _service.repository.api.sendPrompt(
          sessionId: session.id,
          directory: session.directory,
          body: body,
        ),
      );
    }

    return session.toPlugin();
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

    final body = SendPromptBody(parts: parts, agent: agent, model: model);

    return _call(
      () => _service.repository.api.sendPrompt(
        sessionId: sessionId,
        directory: directory,
        body: body,
      ),
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
  }) {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);

    if (directory == null) {
      Log.w("directory missing for session $sessionId. Defaulting to bridge CWD as directory.");
    }

    final body = SendCommandBody(command: command, arguments: arguments);

    return _call(
      () => _service.repository.api.sendCommand(
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
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) {
    return _call(
      () => _service.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: reply,
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
  Future<void> archiveSession({required String sessionId}) async {
    final directory = _service.tracker.getSessionDirectory(sessionId: sessionId);
    await _call(
      () => _service.repository.api.updateSession(
        sessionId: sessionId,
        directory: directory,
        body: {
          "time": {"archived": DateTime.now().millisecondsSinceEpoch},
        },
      ),
    );
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

      final bridgeEvent = _mapper.map(event);
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
      parts: parts.map(_mapper.mapPart).where((p) => p.type.isVisible).toList(),
    );
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
                    awaitingInput: a.awaitingInput,
                    childSessionIds: a.childSessionIds,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }
}
