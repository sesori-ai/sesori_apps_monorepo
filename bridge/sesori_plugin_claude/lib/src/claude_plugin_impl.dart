import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/claude_stream_message.dart";
import "claude_approval_registry.dart";
import "claude_event_dispatcher.dart";
import "claude_history_mapper.dart";
import "models/claude_agent_selection.dart";
import "models/claude_effort_level.dart";
import "models/claude_permission_mode.dart";
import "repositories/claude_backend_catalog_repository.dart";
import "repositories/claude_session_process_repository.dart";
import "repositories/claude_transcript_catalog_repository.dart";
import "services/claude_catalog_service.dart";
import "services/claude_session_service.dart";

typedef ClaudeSessionIdGenerator = String Function();

/// Backend-neutral Claude Code plugin API over the stream-json components.
final class ClaudePlugin({
  required final ClaudeSessionProcessRepository _processes,
  required final ClaudeTranscriptCatalogRepository _transcripts,
  required final ClaudeSessionService _sessions,
  required final ClaudeCatalogService _catalogService,
  required final ClaudeApprovalRegistry _approvals,
  required final ClaudeEventDispatcher _eventDispatcher,
  required final ClaudeHistoryMapper _history,
  required final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer,
  required final ServerClock _clock,
  required final ClaudeSessionIdGenerator _generateSessionId,
  required String launchDirectory,
}) extends BridgeDerivedProjectsPluginApi implements PersistedSessionCleanupApi {
  this {
    _sessions.events.listen(_eventBuffer.add).addTo(_subscriptions);
    _processes.events.listen(_handleProcessEvent).addTo(_subscriptions);
  }

  static const String pluginId = "claude";

  final String _launchDirectory = normalizeProjectDirectory(directory: launchDirectory);
  final Map<String, PluginSession> _createdSessions = {};
  final Set<String> _unstartedSessions = {};
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<void>? _disposeFuture;
  bool _disposed = false;
  int _messageSequence = 0;

  @override
  String get id => pluginId;

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  @override
  String get launchDirectory => _launchDirectory;

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async {
    final persisted = await _transcripts.getSessions(projectId: projectId, start: null, limit: null);
    final target = normalizeProjectDirectory(directory: projectId);
    final combined = _mergeSessions(persisted, [
      for (final session in _createdSessions.values)
        if (session.directory == target) session,
    ]);
    return _page(combined, start: start, limit: limit);
  }

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => _mergeSessions(
    await _transcripts.listAllSessions(knownDirectories: knownDirectories),
    _createdSessions.values,
  );

  @override
  // Claude declares plugin-scoped options, so projectId does not select a catalog.
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      (await _catalogService.getCatalog(refresh: false)).commands;

  @override
  // Claude declares plugin-scoped options, so projectId does not select a catalog.
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final catalog = await _catalogService.getCatalog(
      refresh: discoveryMode == PluginSessionOptionsDiscoveryMode.refresh,
    );
    return PluginSessionOptionsDiscoveryResult.observed(
      options: PluginSessionOptions(
        agents: catalog.agents,
        providers: catalog.providers,
        commands: catalog.commands,
        completeness: PluginSessionOptionsCompleteness.complete,
      ),
    );
  }

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
    _validateModel(model, operation: "createSession");
    _effort(variant, operation: "createSession");
    _permissionMode(agent, operation: "createSession");
    final sessionId = _generateSessionId();
    final normalized = normalizeProjectDirectory(directory: directory);
    final now = _clock.now().millisecondsSinceEpoch;
    final session = PluginSession(
      id: sessionId,
      projectID: normalized,
      directory: normalized,
      parentID: parentSessionId,
      title: null,
      time: PluginSessionTime(created: now, updated: now, archived: null),
    );
    _createdSessions[sessionId] = session;
    _unstartedSessions.add(sessionId);
    _eventBuffer.add(BridgeSseSessionCreated(info: session.toJson()));
    if (parts.isNotEmpty) {
      try {
        await _enqueueInitial(
          sessionId: sessionId,
          directory: normalized,
          parts: parts,
          variant: variant,
          agent: agent,
          model: model,
          operation: "createSession",
        );
        _unstartedSessions.remove(sessionId);
      } on Object {
        await _sessions.deleteSession(sessionId: sessionId);
        _createdSessions.remove(sessionId);
        _unstartedSessions.remove(sessionId);
        _eventDispatcher.forgetSession(sessionId: sessionId);
        _eventBuffer.add(BridgeSseSessionDeleted(info: session.toJson()));
        _eventBuffer.add(const BridgeSseProjectUpdated());
        rethrow;
      }
    }
    return session;
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    final existing = _findSession(sessionId);
    if (existing == null) throw const PluginOperationException.notFound("renameSession", message: "session not found");
    final renamed = existing.copyWith(title: title);
    if (_createdSessions.containsKey(sessionId)) _createdSessions[sessionId] = renamed;
    _eventBuffer.add(BridgeSseSessionUpdated(info: renamed.toJson(), titleChanged: true));
    return renamed;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final existing = _findSession(sessionId);
    final known =
        existing != null ||
        _processes.isResident(sessionId: sessionId) ||
        _sessions.sessionStatuses.containsKey(sessionId);
    if (!known) throw const PluginOperationException.notFound("deleteSession", message: "session not found");
    await _sessions.deleteSession(sessionId: sessionId);
    try {
      try {
        _transcripts.deleteSession(sessionId: sessionId);
      } on Object catch (error) {
        throw PluginOperationException("deleteSession", message: "Claude transcript deletion failed", cause: error);
      }
    } finally {
      _createdSessions.remove(sessionId);
      _unstartedSessions.remove(sessionId);
      _eventDispatcher.forgetSession(sessionId: sessionId);
      if (existing != null) _eventBuffer.add(BridgeSseSessionDeleted(info: existing.toJson()));
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => const [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => _sessions.sessionStatuses;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    if (_transcripts.findTranscriptPath(sessionId: sessionId) == null) {
      if (_createdSessions.containsKey(sessionId)) return const [];
      throw const PluginOperationException.notFound("getSessionMessages", message: "session not found");
    }
    try {
      return _history.map(
        sessionId: sessionId,
        records: await _transcripts.readTranscriptRecordsInIsolate(sessionId: sessionId),
      );
    } on Object catch (error) {
      throw PluginOperationException(
        "getSessionMessages",
        message: "Claude history read failed",
        cause: error,
      );
    }
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
    _requireTurn(parts: parts, operation: "sendPrompt");
    final directory = _directoryForSession(sessionId);
    if (directory == null) throw const PluginOperationException.notFound("sendPrompt", message: "session not found");
    final text = parts
        .whereType<PluginPromptPartText>()
        .map((part) => part.text)
        .where((text) => text.trim().isNotEmpty)
        .join("\n")
        .trim();
    await _enqueueQueued(
      sessionId: sessionId,
      directory: directory,
      parts: parts,
      variant: variant,
      agent: agent,
      model: model,
      operation: "sendPrompt",
      promptId: promptId,
      displayText: text.isEmpty ? null : text,
      command: null,
      attachmentCount: parts.length - parts.whereType<PluginPromptPartText>().length,
      onDispatched: () {
        _unstartedSessions.remove(sessionId);
        _eventDispatcher.beginTurn(sessionId: sessionId);
        _eventDispatcher.expectUserEcho(
          sessionId: sessionId,
          promptId: promptId,
          onConsumed: () => _sessions.consumeQueuedPrompt(sessionId: sessionId, promptId: promptId),
        );
        return ClaudeQueuedDispatch.awaitsUserEcho;
      },
    );
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
    final directory = _directoryForSession(sessionId);
    if (directory == null) throw const PluginOperationException.notFound("sendCommand", message: "session not found");
    final visible = userVisibleArguments?.trim();
    await _enqueueQueued(
      sessionId: sessionId,
      directory: directory,
      parts: [PluginPromptPart.text(text: arguments.isEmpty ? "/$command" : "/$command $arguments")],
      variant: variant,
      agent: agent,
      model: model,
      operation: "sendCommand",
      promptId: promptId,
      displayText: visible == null || visible.isEmpty ? null : visible,
      command: command,
      attachmentCount: 0,
      onDispatched: () {
        _unstartedSessions.remove(sessionId);
        _eventDispatcher.beginTurn(sessionId: sessionId);
        _emitVisibleUserMessage(
          sessionId: sessionId,
          text: visible == null || visible.isEmpty ? "/$command" : "/$command $visible",
          promptId: promptId,
        );
        return ClaudeQueuedDispatch.emittedVisibleMessage;
      },
    );
  }

  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async =>
      _sessions.queuedPrompts(sessionId: sessionId);

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async =>
      _sessions.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);

  @override
  Future<void> abortSession({required String sessionId}) async {
    await _sessions.abort(sessionId: sessionId);
    _eventDispatcher.clearExpectedUserEcho(sessionId: sessionId);
  }

  @override
  // Claude declares plugin-scoped options, so projectId does not select a catalog.
  Future<List<PluginAgent>> getAgents({required String projectId}) async =>
      (await _catalogService.getCatalog(refresh: false)).agents;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async =>
      _approvals.pendingQuestionsForSession(sessionId: sessionId);

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async =>
      _approvals.pendingPermissionsForSession(sessionId: sessionId);

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async {
    final sessions = await getSessions(projectId);
    return [
      for (final session in sessions) ..._approvals.pendingQuestionsForSession(sessionId: session.id),
    ];
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final exitsPlanMode = _approvals.isExitPlanModeQuestion(id: questionId);
    if (!_approvals.hasQuestion(id: questionId)) {
      throw const PluginOperationException.notFound("replyToQuestion", message: "question not found");
    }
    if (!_approvals.replyQuestion(id: questionId, answers: answers)) {
      throw const PluginOperationException("replyToQuestion", message: "Claude rejected the question response");
    }
    if (exitsPlanMode) {
      final applied = _processes.appliedSelection(sessionId: sessionId);
      if (applied != null) {
        _processes.recordAppliedSelection(
          sessionId: sessionId,
          model: applied.model,
          effort: applied.effort,
          permissionMode: ClaudePermissionMode.auto,
        );
      }
      _eventBuffer.add(
        BridgeSseSessionPromptDefaultsChanged(
          sessionID: sessionId,
          agent: "Default",
          model: null,
        ),
      );
    }
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    if (!_approvals.hasQuestion(id: questionId)) {
      throw const PluginOperationException.notFound("rejectQuestion", message: "question not found");
    }
    if (!_approvals.rejectQuestion(id: questionId)) {
      throw const PluginOperationException("rejectQuestion", message: "Claude rejected the question response");
    }
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    if (!_approvals.hasPermission(id: requestId)) {
      throw const PluginOperationException.notFound("replyToPermission", message: "permission not found");
    }
    if (!_approvals.replyPermission(id: requestId, reply: reply)) {
      throw const PluginOperationException("replyToPermission", message: "Claude rejected the permission response");
    }
  }

  @override
  Future<bool> healthCheck() async => !_disposed;

  @override
  // Claude declares plugin-scoped options, so projectId does not select a catalog.
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      (await _catalogService.getCatalog(refresh: false)).providers;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final byProject = <String, List<PluginActiveSession>>{};
    for (final entry in _sessions.sessionStatuses.entries) {
      final running = entry.value is PluginSessionStatusBusy || entry.value is PluginSessionStatusRetry;
      final awaitingInput = _approvals.hasPendingInput(sessionId: entry.key);
      if (!running && !awaitingInput) continue;
      final directory = _directoryForSession(entry.key);
      if (directory == null) continue;
      (byProject[directory] ??= []).add(
        PluginActiveSession(
          id: entry.key,
          mainAgentRunning: running,
          awaitingInput: awaitingInput,
          isRetrying: entry.value is PluginSessionStatusRetry,
          childSessionIds: const [],
        ),
      );
    }
    return [
      for (final entry in byProject.entries) PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) async {
    _transcripts.deleteSession(sessionId: backendSessionId);
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscriptions.cancel();
    await _sessions.dispose();
    _createdSessions.clear();
    _unstartedSessions.clear();
    await _eventBuffer.close();
  }

  /// Queues a send to an existing session, accepted at enqueue.
  Future<void> _enqueueQueued({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
    required String promptId,
    required String? displayText,
    required String? command,
    required int attachmentCount,
    required ClaudeQueuedDispatch Function() onDispatched,
  }) async {
    _validateModel(model, operation: operation);
    final effort = _effort(variant, operation: operation);
    final permissionMode = _permissionMode(agent, operation: operation);
    final createNew = _unstartedSessions.contains(sessionId);
    try {
      await _sessions.enqueueTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: createNew,
        parts: parts,
        model: model?.modelID,
        effort: effort,
        permissionMode: permissionMode,
        promptId: promptId,
        displayText: displayText,
        command: command,
        attachmentCount: attachmentCount,
        onDispatched: onDispatched,
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation, message: "Claude did not accept the turn", cause: error);
    }
  }

  /// Runs a new session's first turn with acceptance at dispatch, so session
  /// creation can roll back when the initial prompt never starts.
  Future<void> _enqueueInitial({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
  }) async {
    _validateModel(model, operation: operation);
    final effort = _effort(variant, operation: operation);
    final permissionMode = _permissionMode(agent, operation: operation);
    _eventDispatcher.beginTurn(sessionId: sessionId);
    try {
      await _sessions.enqueueInitialTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: true,
        parts: parts,
        model: model?.modelID,
        effort: effort,
        permissionMode: permissionMode,
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation, message: "Claude did not accept the turn", cause: error);
    }
  }

  void _validateModel(({String providerID, String modelID})? model, {required String operation}) {
    if (model == null) return;
    if (model.providerID != ClaudeBackendCatalogRepository.providerId || model.modelID.trim().isEmpty) {
      throw PluginOperationException(operation, statusCode: 400, message: "unsupported model");
    }
  }

  ClaudeEffortLevel? _effort(PluginSessionVariant? variant, {required String operation}) {
    if (variant == null) return null;
    final effort = ClaudeEffortLevel.tryParse(variant.id);
    if (effort == null) {
      throw PluginOperationException(operation, statusCode: 400, message: "unsupported Claude effort");
    }
    return effort;
  }

  ClaudePermissionMode? _permissionMode(String? agent, {required String operation}) {
    if (agent == null) return null;
    final selection = ClaudeAgentSelection.tryParse(agent);
    if (selection == null) {
      throw PluginOperationException(operation, statusCode: 400, message: "unsupported Claude agent");
    }
    return selection.permissionMode;
  }

  PluginSession? _findSession(String sessionId) {
    final created = _createdSessions[sessionId];
    if (created != null) return created;
    final record = _transcripts.findSessionById(sessionId: sessionId);
    if (record == null) return null;
    final directory = normalizeProjectDirectory(directory: record.cwd);
    final createdAt = (record.createdAt ?? record.updatedAt)?.millisecondsSinceEpoch;
    final updatedAt = (record.updatedAt ?? record.createdAt)?.millisecondsSinceEpoch;
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: record.title,
      time: createdAt == null || updatedAt == null
          ? null
          : PluginSessionTime(created: createdAt, updated: updatedAt, archived: null),
    );
  }

  String? _directoryForSession(String sessionId) => _findSession(sessionId)?.directory;

  void _handleProcessEvent(ClaudeSessionProcessEvent event) {
    if (event case ClaudeSessionProcessMessage(:final message, :final interrupted)) {
      if (message is ClaudeResultMessage) {
        final denialsWereHandled = _approvals.consumeHandledPermissionDenials(
          sessionId: event.sessionId,
          denials: message.permissionDenials,
        );
        if (interrupted) return;
        if (!message.isError && message.subtype == ClaudeResultSubtype.success && denialsWereHandled) return;
      }
      if (message is ClaudeInitMessage && message.sessionId != event.sessionId) {
        Log.e("[claude] backend reported a different session id; stopping the session");
        unawaited(_sessions.deleteSession(sessionId: event.sessionId));
        _eventBuffer.add(BridgeSseSessionError(sessionID: event.sessionId));
        return;
      }
      if (message is ClaudeApiRetryMessage) {
        final now = _clock.now();
        final status = _eventDispatcher.retryStatus(message: message, now: now);
        if (status != null) _sessions.recordRetryStatus(sessionId: event.sessionId, status: status);
        _eventDispatcher.map(message: message, now: now).forEach(_eventBuffer.add);
        return;
      }
      _eventDispatcher.map(message: message).forEach(_eventBuffer.add);
    }
  }

  /// Synthesizes the visible user bubble for a slash command at dispatch.
  ///
  /// Plain prompts never need this: `--replay-user-messages` echoes them under
  /// their transcript uuid. A command's echo (and its transcript row) is the
  /// CLI's `<command-name>` envelope, which both mapping paths drop, so this
  /// synthetic message stays the turn's only user row and cannot duplicate.
  void _emitVisibleUserMessage({required String sessionId, required String? text, required String? promptId}) {
    final visible = text?.trim();
    if (visible == null || visible.isEmpty) return;
    final messageId = "sesori-user-${++_messageSequence}";
    final now = _clock.now().millisecondsSinceEpoch;
    _eventBuffer.add(
      BridgeSseMessageUpdated(
        info: PluginMessage.user(
          id: messageId,
          sessionID: sessionId,
          agent: null,
          time: PluginMessageTime(created: now, completed: now),
          promptId: promptId,
        ).toJson(),
      ),
    );
    _eventBuffer.add(
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "$messageId-text",
          sessionID: sessionId,
          messageID: messageId,
          type: PluginMessagePartType.text,
          text: visible,
          tool: null,
          state: null,
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
          attachment: null,
        ),
      ),
    );
  }
}

void _requireTurn({required List<PluginPromptPart> parts, required String operation}) {
  if (parts.isEmpty) {
    throw PluginOperationException(operation, statusCode: 400, message: "prompt must not be empty");
  }
}

List<PluginSession> _mergeSessions(Iterable<PluginSession> persisted, Iterable<PluginSession> created) {
  final byId = {for (final session in persisted) session.id: session};
  for (final session in created) {
    byId.putIfAbsent(session.id, () => session);
  }
  return byId.values.toList(growable: false);
}

List<PluginSession> _page(List<PluginSession> sessions, {required int? start, required int? limit}) {
  final from = (start ?? 0).clamp(0, sessions.length);
  if (from >= sessions.length) return const [];
  final count = limit?.clamp(0, sessions.length);
  final until = count == null ? sessions.length : (from + count).clamp(from, sessions.length);
  return sessions.sublist(from, until);
}
