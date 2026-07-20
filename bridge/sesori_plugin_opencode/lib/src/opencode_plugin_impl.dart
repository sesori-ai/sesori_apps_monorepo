import "dart:async";
import "dart:io" as io;

import "package:http/io_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../opencode_plugin.dart";
import "assistant_message_mapper.dart";
import "sse/sse_connection.dart";
import "sse_event_mapper.dart";

String formatDroppedSseFrameLog({
  required String category,
  required String message,
  String? directory,
  String? eventType,
}) {
  final context = <String>[];
  if (directory != null) {
    context.add("directory=$directory");
  }
  if (eventType != null) {
    context.add("eventType=$eventType");
  }

  final suffix = context.isEmpty ? "" : " [${context.join(", ")}]";
  return "[opencode][sse][$category]$suffix $message";
}

class OpenCodePlugin implements OpenCodeManagedApi {
  final OpenCodeService _service;
  final SseEventParser _parser;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final io.HttpClient _httpClient;
  // One shared error-normalization mapper drives both the live SSE path
  // ([_mapper]) and the REST load path ([_pluginModelMapper]) so an errored
  // assistant message is collapsed to a `MessageError` identically on both.
  static const AssistantMessageMapper _assistantMessageMapper = AssistantMessageMapper();
  final SseEventMapper _mapper = SseEventMapper(assistantMessageMapper: _assistantMessageMapper);
  final PluginModelMapper _pluginModelMapper = const PluginModelMapper(
    messagePartMapper: MessagePartMapper(),
    assistantMessageMapper: _assistantMessageMapper,
  );
  late final SseConnection _sseConnection;
  late final StreamSubscription<void> _summarySubscription;
  Future<void>? _initializeFuture;
  bool _disposed = false;

  /// Builds an OpenCode plugin against the server at [serverUrl].
  ///
  /// When [autoInitialize] is true (the default, used by the legacy bridge-app
  /// flow), cold-start is kicked off fire-and-forget at construction, swallowing
  /// failures so creation never throws. The descriptor passes
  /// `autoInitialize: false` and awaits [initialize] itself so it can surface a
  /// cold-start failure as a degraded status. [onConnected]/[onDisconnected]
  /// follow the SSE transport's live state for lifecycle reporting.
  factory OpenCodePlugin({
    required String serverUrl,
    String? password,
    bool autoInitialize = true,
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    final httpClient = io.HttpClient();
    final api = OpenCodeApi(
      client: OpenCodeRawHttpClient(
        serverURL: serverUrl,
        password: password,
        client: IOClient(httpClient),
      ),
    );
    final repository = OpenCodeRepository(api);
    final tracker = ActiveSessionTracker(repository);
    return OpenCodePlugin._(
      service: OpenCodeService(repository, tracker),
      httpClient: httpClient,
      serverUrl: serverUrl,
      password: password,
      autoInitialize: autoInitialize,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
  }

  OpenCodePlugin._({
    required OpenCodeService service,
    required io.HttpClient httpClient,
    required String serverUrl,
    required String? password,
    required bool autoInitialize,
    void Function()? onConnected,
    void Function()? onDisconnected,
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
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
    // The service resolves missing parent IDs out-of-band (after handleSseEvent
    // has already returned); re-emit the activity summary when it does so the
    // running badge surfaces on the correct root session.
    _summarySubscription = _service.summaryInvalidations.listen((_) => _emitProjectsSummary());
    if (autoInitialize) {
      // Legacy behavior: cold-start fire-and-forget so direct construction never
      // throws (the descriptor awaits initialize() instead). The failure is
      // swallowed to keep startup fail-soft, but logged so it stays diagnosable.
      unawaited(
        initialize().catchError((Object error, StackTrace stackTrace) {
          Log.e("[opencode] auto-initialize cold-start failed: $error\n$stackTrace");
        }),
      );
    }
  }

  /// Hydrates the session tracker and starts the SSE stream. Idempotent:
  /// repeated calls share one in-flight cold-start.
  @override
  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    Object? coldStartError;
    StackTrace? coldStartStackTrace;
    try {
      await _service.coldStart();
      _emitProjectsSummary();
    } catch (error, stackTrace) {
      // Surface the failure to the caller (the descriptor maps it to a degraded
      // status) but still start the SSE stream so a later reconnect recovers.
      coldStartError = error;
      coldStartStackTrace = stackTrace;
    }
    // A dispose() can win the race against an in-flight cold-start (e.g. a
    // background initialize from a failed attach probe, or an aborted-start
    // rollback): starting the transport now would revive it after teardown.
    if (!_disposed) {
      _sseConnection.start();
    }
    if (coldStartError != null) {
      Error.throwWithStackTrace(coldStartError, coldStartStackTrace ?? StackTrace.current);
    }
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on OpenCodeApiException catch (e) {
      throw PluginApiException(e.endpoint, e.statusCode, message: e.responseBody);
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
  Future<PluginProvidersResult> getProviders({required String projectId}) {
    return _call(
      () => _service.getProviders(projectId: projectId),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      Log.v("[shutdown] OpenCodePlugin.dispose: already disposed, skipping");
      return;
    }
    _disposed = true;
    Log.v("[shutdown] OpenCodePlugin.dispose: stopping SSE connection");
    _sseConnection.stop();
    // Each teardown step is isolated so a failure in one does not prevent the
    // remaining cleanup (http client + event buffer below) from running.
    try {
      await _summarySubscription.cancel();
    } on Object catch (e, st) {
      Log.w("[shutdown] OpenCodePlugin.dispose: failed to cancel summary subscription", e, st);
    }
    try {
      await _service.dispose();
    } on Object catch (e, st) {
      Log.w("[shutdown] OpenCodePlugin.dispose: failed to dispose service", e, st);
    }
    Log.v("[shutdown] OpenCodePlugin.dispose: force-closing http client");
    _httpClient.close(force: true);
    final sw = Stopwatch()..start();
    await _eventBuffer.close();
    Log.d("[shutdown] OpenCodePlugin.dispose: event buffer closed in ${sw.elapsedMilliseconds}ms");
  }

  @override
  Future<List<PluginProject>> getProjects() => _call(_service.getProjects);

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
        parentId: session.parentID,
      );
    }
    return sessions
        .map(
          (session) =>
              _pluginModelMapper.mapSession(session, projectID: _resolveCanonicalProjectID(session, projectId)),
        )
        .toList();
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    return _call(() => _service.getCommands(projectId: projectId));
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) async {
    return _call(
      () => _service.createSession(
        directory: directory,
        parentSessionId: parentSessionId,
        parts: parts,
        agent: agent,
        variant: variant,
        model: model,
      ),
    );
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
    return _pluginModelMapper.mapSession(session, projectID: _resolveCanonicalProjectID(session, session.projectID));
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
    return sessions
        .map(
          (session) => _pluginModelMapper.mapSession(
            session,
            projectID: _resolveCanonicalProjectID(session, session.projectID),
          ),
        )
        .toList();
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async {
    final apiStatuses = await _call(
      () => _service.repository.api.getSessionStatuses(directory: null),
    );

    // Start with the API response as a baseline.
    final merged = apiStatuses.map((key, value) => MapEntry(key, _pluginModelMapper.mapSessionStatus(value)));

    // Overlay the tracker's real-time active statuses. The tracker is
    // maintained by SSE events and accurately reflects which sessions are
    // busy/retry. The API response may be scoped by OpenCode's directory
    // context and miss sessions from other projects.
    final activeStatuses = _service.tracker.getActiveStatuses();
    for (final entry in activeStatuses.entries) {
      merged[entry.key] = _pluginModelMapper.mapSessionStatus(entry.value);
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
    return messages;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    return _call(
      () => _service.sendPrompt(
        sessionId: sessionId,
        parts: parts,
        agent: agent,
        variant: variant,
        model: model,
      ),
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    return _call(
      () => _service.sendCommand(
        sessionId: sessionId,
        command: command,
        arguments: arguments,
        agent: agent,
        variant: variant,
        model: model,
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
  Future<List<PluginAgent>> getAgents({required String projectId}) {
    return _call(() => _service.getAgents(projectId: projectId));
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async {
    final pending = await _call(
      () => _service.getPendingQuestionsForSession(sessionId: sessionId),
    );
    return pending.map((e) => _pluginModelMapper.mapQuestion(e.request, displaySessionId: e.displaySessionId)).toList();
  }

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async {
    final pending = await _call(
      () => _service.getPendingPermissionsForSession(sessionId: sessionId),
    );
    return pending
        .map((e) => _pluginModelMapper.mapPermission(e.request, displaySessionId: e.displaySessionId))
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
    return pending
        .map(
          (q) => _pluginModelMapper.mapQuestion(
            q,
            displaySessionId: _service.resolveDisplaySessionId(q.sessionID),
          ),
        )
        .toList();
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final result = await _call(
      () => _service.replyToQuestion(
        questionId: questionId,
        sessionId: sessionId,
        answers: answers,
      ),
    );
    if (result.found) {
      _eventBuffer.add(
        BridgeSseQuestionReplied(
          requestID: questionId,
          sessionID: sessionId,
          displaySessionId: _service.resolveDisplaySessionId(sessionId),
        ),
      );
    }
    if (result.summaryChanged) _emitProjectsSummary();
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    final result = await _call(
      () => _service.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: reply,
      ),
    );
    if (result.found) {
      _eventBuffer.add(
        BridgeSsePermissionReplied(
          requestID: requestId,
          sessionID: sessionId,
          displaySessionId: _service.resolveDisplaySessionId(sessionId),
          reply: reply.name,
        ),
      );
    }
    if (result.summaryChanged) _emitProjectsSummary();
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    final result = await _call(
      () => _service.rejectQuestion(
        questionId: questionId,
        sessionId: sessionId,
      ),
    );
    if (result.found) {
      if (result.resolvedSessionId case final sessionID?) {
        _eventBuffer.add(
          BridgeSseQuestionRejected(
            requestID: questionId,
            sessionID: sessionID,
            displaySessionId: _service.resolveDisplaySessionId(sessionID),
          ),
        );
      }
    }
    if (result.summaryChanged) _emitProjectsSummary();
  }

  @override
  Future<PluginProject> getProject(String projectId) async {
    return _call(() => _service.getProject(directory: projectId));
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
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) {
    return _call(
      () => _service.repository.api.removeWorktree(
        directory: projectId,
        worktreePath: worktreePath,
      ),
    );
  }

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) {
    return _call(
      () => _service.repository.renameProject(
        directory: projectId,
        name: name,
      ),
    );
  }

  void _handleRawSseEvent(String rawData) {
    try {
      final parseResult = _parser.parse(rawData);
      switch (parseResult.outcome) {
        case SseParseOutcome.validKnownEvent:
          final event = parseResult.event;
          if (event == null) {
            Log.e("[opencode] SSE parser reported validKnownEvent without an event instance.");
            return;
          }

          final changed = _service.handleSseEvent(event, parseResult.directory);
          if (changed) {
            _emitProjectsSummary();
          }

          final canonicalEvent = _canonicalizeEvent(event);
          final bridgeEvent = _mapper.map(
            canonicalEvent,
            displaySessionId: _displaySessionIdForEvent(canonicalEvent),
          );
          if (bridgeEvent != null) {
            _eventBuffer.add(bridgeEvent);
          }
          return;
        case SseParseOutcome.ignoredKnownEvent:
          return;
        case SseParseOutcome.unknownEventType:
          _logDroppedSseFrame(
            category: "unknown-event-type",
            message: "Ignoring SSE frame with unknown event type.",
            directory: parseResult.directory,
            eventType: parseResult.eventType,
          );
          return;
        case SseParseOutcome.malformedEnvelope:
          _logDroppedSseFrame(
            category: "malformed-envelope",
            message: "Ignoring malformed SSE envelope.",
            directory: parseResult.directory,
            eventType: parseResult.eventType,
          );
          return;
        case SseParseOutcome.malformedKnownPayload:
          _logDroppedSseFrame(
            category: "malformed-known-payload",
            message: "Ignoring malformed payload for known SSE event.",
            directory: parseResult.directory,
            eventType: parseResult.eventType,
          );
          return;
      }
    } catch (e, st) {
      Log.e("[opencode] SSE event processing error: $e\n$st");
    }
  }

  void _logDroppedSseFrame({
    required String category,
    required String message,
    String? directory,
    String? eventType,
  }) {
    Log.w(
      formatDroppedSseFrameLog(
        category: category,
        message: message,
        directory: directory,
        eventType: eventType,
      ),
    );
  }

  void _emitProjectsSummary() {
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  Session _canonicalizeSession(Session session, String fallbackProjectID) {
    return session.copyWith(projectID: _resolveCanonicalProjectID(session, fallbackProjectID));
  }

  String _resolveCanonicalProjectID(Session session, String fallbackProjectID) {
    return _service.tracker.resolveProjectWorktree(directory: session.directory) ?? fallbackProjectID;
  }

  SseEventData _canonicalizeEvent(SseEventData event) {
    return switch (event) {
      SseSessionCreated(:final info) => SseEventData.sessionCreated(
        info: _canonicalizeSession(info, info.projectID),
      ),
      SseSessionUpdated(:final info) => SseEventData.sessionUpdated(
        info: _canonicalizeSession(info, info.projectID),
      ),
      SseSessionDeleted(:final info) => SseEventData.sessionDeleted(
        info: _canonicalizeSession(info, info.projectID),
      ),
      _ => event,
    };
  }

  /// Resolves the root display session for the permission/question events that
  /// carry it, so a child/sub-agent request can surface on its root session.
  /// Returns null for all other event types (which are not surfaced cross-session).
  String? _displaySessionIdForEvent(SseEventData event) {
    final ownerSessionId = switch (event) {
      SsePermissionAsked(:final sessionID) => sessionID,
      SsePermissionReplied(:final sessionID) => sessionID,
      SseQuestionAsked(:final sessionID) => sessionID,
      SseQuestionReplied(:final sessionID) => sessionID,
      SseQuestionRejected(:final sessionID) => sessionID,
      _ => null,
    };
    return ownerSessionId == null ? null : _service.resolveDisplaySessionId(ownerSessionId);
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
                    isRetrying: a.isRetrying,
                    childSessionIds: a.childSessionIds,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }
}
