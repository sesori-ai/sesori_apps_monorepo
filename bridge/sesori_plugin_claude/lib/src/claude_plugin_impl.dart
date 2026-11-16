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
import "models/claude_subagent_session_id.dart";
import "repositories/claude_backend_catalog_repository.dart";
import "repositories/claude_session_process_repository.dart";
import "repositories/claude_transcript_catalog_repository.dart";
import "services/claude_catalog_service.dart";
import "services/claude_mcp_authentication_service.dart";
import "services/claude_session_service.dart";

typedef ClaudeSessionIdGenerator = String Function();

/// Backend-neutral Claude Code plugin API over the stream-json components.
final class ClaudePlugin({
  required final ClaudeSessionProcessRepository _processes,
  required final ClaudeMcpAuthenticationService _mcpAuthentication,
  required final bool Function() _usesCustomBaseUrl,
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
}) extends BridgeDerivedProjectsPluginApi
    implements
        PersistedSessionCleanupApi,
        McpManagementPluginApi,
        McpAuthenticationPluginApi,
        FormInteractionPluginApi,
        SessionExternalActionsPluginApi,
        SessionRewindPluginApi,
        SessionForkPluginApi,
        SideQuestionPluginApi {
  this {
    _sessions.events.listen(_eventBuffer.add).addTo(_subscriptions);
    _sessions.dispatches.listen(_handleTurnDispatched).addTo(_subscriptions);
    _processes.events.listen(_handleProcessEvent).addTo(_subscriptions);
  }

  static const String pluginId = "claude";
  static const String _syntheticModelId = "<synthetic>";

  final String _launchDirectory = normalizeProjectDirectory(directory: launchDirectory);
  final Map<String, PluginSession> _createdSessions = {};
  final Set<String> _unstartedSessions = {};

  /// The bridge's stored directory of each session it operated on.
  final Map<String, String> _primedDirectories = {};
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<void>? _disposeFuture;

  @override
  String get id => pluginId;

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  @override
  Future<PluginMcpInventoryResult> getMcpInventory({required PluginMcpScope scope}) =>
      _processes.getMcpInventory(scope: scope);

  @override
  Future<PluginMcpAuthenticationOperation> beginMcpAuthentication({required PluginMcpServerTarget target}) =>
      _mcpAuthentication.begin(target: target);

  @override
  Future<PluginMcpActionEffectScope> forgetMcpAuthentication({required PluginMcpServerTarget target}) async {
    await _mcpAuthentication.forget(target: target);
    return PluginMcpActionEffectScope.harness;
  }

  @override
  Future<PluginMcpActionResult> executeMcpServerAction({
    required PluginMcpServerTarget target,
    required PluginMcpServerAction action,
  }) => _processes.executeMcpServerAction(target: target, action: action);

  @override
  String get launchDirectory => _launchDirectory;

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {
    _primedDirectories[sessionId] = normalizeProjectDirectory(directory: directory);
  }

  @override
  Future<List<PluginSession>> getSessions({required String projectId}) async {
    final persisted = await _transcripts.getSessions(projectId: projectId);
    final target = normalizeProjectDirectory(directory: projectId);
    return _mergeSessions(
      persisted: persisted,
      created: [
        for (final session in _createdSessions.values)
          if (session.directory == target) session,
      ],
    );
  }

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => _mergeSessions(
    persisted: await _transcripts.listAllSessions(knownDirectories: knownDirectories),
    created: _createdSessions.values,
  );

  @override
  // A null projectId lists only the user's and Claude's own commands.
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      (await _catalogService.getCatalog(directory: projectId, refresh: false)).commands;

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final catalog = await _catalogService.getCatalog(
      directory: projectId,
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
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    _validateModel(model, operation: "createSession", staleOptions: false);
    _effort(variant, operation: "createSession", staleOptions: false);
    _permissionMode(agent, operation: "createSession", staleOptions: false);
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
          fastMode: fastMode,
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
    final existing = await _findSession(sessionId);
    if (existing == null) {
      throw const PluginOperationException.notFound(operation: "renameSession", message: "session not found");
    }
    final renamed = existing.copyWith(title: title);
    if (_createdSessions.containsKey(sessionId)) _createdSessions[sessionId] = renamed;
    _eventBuffer.add(BridgeSseSessionUpdated(info: renamed.toJson(), titleChanged: true));
    return renamed;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final existing = await _findSession(sessionId);
    final known =
        existing != null ||
        _processes.isResident(sessionId: sessionId) ||
        _sessions.sessionStatuses.containsKey(sessionId);
    if (!known) throw const PluginOperationException.notFound(operation: "deleteSession", message: "session not found");
    await _sessions.deleteSession(sessionId: sessionId);
    try {
      try {
        await _transcripts.deleteSession(sessionId: sessionId);
      } on Object catch (error) {
        throw PluginOperationException(
          operation: "deleteSession",
          message: "Claude transcript deletion failed",
          cause: error,
        );
      }
    } finally {
      _createdSessions.remove(sessionId);
      _unstartedSessions.remove(sessionId);
      _primedDirectories.remove(sessionId);
      _eventDispatcher.forgetSession(sessionId: sessionId);
      if (existing != null) _eventBuffer.add(BridgeSseSessionDeleted(info: existing.toJson()));
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    _approvals.cancelForArchive(sessionId: sessionId);
  }

  @override
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => _transcripts.getChildSessions(sessionId: sessionId);

  @override
  // Roots from the session service, children from the dispatcher: disjoint ids.
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {
    ..._sessions.sessionStatuses,
    ..._eventDispatcher.childSessionStatuses(),
  };

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    if (await _transcripts.findTranscriptPath(sessionId: sessionId) == null) {
      if (_sessionWithoutTranscript(sessionId) != null) return const [];
      throw const PluginOperationException.notFound(operation: "getSessionMessages", message: "session not found");
    }
    final catalog = await _catalogForHistory(directory: await _directoryForSession(sessionId));
    try {
      return _history.map(
        sessionId: sessionId,
        agentId: ClaudeSubagentSessionId.agentIdOf(sessionId),
        records: await _transcripts.readTranscriptRecordsInIsolate(sessionId: sessionId),
        residentTaskToolUseIds: _eventDispatcher.residentTaskToolUseIds(sessionId: sessionId),
        catalogModelId: catalog?.catalogModelId,
        commands: catalog?.commands ?? const [],
      );
    } on Object catch (error) {
      throw PluginOperationException(
        operation: "getSessionMessages",
        message: "Claude history read failed",
        cause: error,
      );
    }
  }

  /// The catalog of the session's [directory], which maps a transcript's API
  /// model names to picker ids and names its commands' kinds. A failed probe
  /// must not withhold history, so it degrades to raw names and unknown kinds.
  Future<ClaudeBackendCatalog?> _catalogForHistory({required String? directory}) async {
    try {
      return await _catalogService.getCatalog(directory: directory, refresh: false);
    } on Object catch (error, stack) {
      Log.w("[claude] history keeps API model names: catalog unavailable", error, stack);
      return null;
    }
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    _requireTurn(parts: parts, operation: "sendPrompt");
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginOperationException.notFound(operation: "sendPrompt", message: "session not found");
    }
    await _enqueueQueued(
      sessionId: sessionId,
      directory: directory,
      parts: parts,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
      operation: "sendPrompt",
      promptId: promptId,
      displayText: _displayText(parts),
      command: null,
      attachmentCount: _attachmentCount(parts),
    );
  }

  @override
  Future<void> rewindAndSendPrompt({
    required String sessionId,
    required String beforeMessageId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    const operation = "rewindAndSendPrompt";
    _requireTurn(parts: parts, operation: operation);
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginOperationException.notFound(operation: operation, message: "session not found");
    }
    final (:effort, :permissionMode) = _queuedSelections(
      sessionId: sessionId,
      variant: variant,
      agent: agent,
      model: model,
      operation: operation,
    );
    try {
      await _sessions.rewindAndEnqueueTurn(
        sessionId: sessionId,
        directory: directory,
        beforeMessageId: beforeMessageId,
        parts: parts,
        model: model?.modelID,
        effort: effort,
        permissionMode: permissionMode,
        fastMode: fastMode,
        promptId: promptId,
        displayText: _displayText(parts),
        attachmentCount: _attachmentCount(parts),
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation: operation, message: "Claude did not accept the rewind", cause: error);
    }
  }

  @override
  Future<PluginSession> forkSession({required String sessionId, required String throughMessageId}) async {
    const operation = "forkSession";
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginBranchPointUnavailableException(
        operation: operation,
        userFacingReason: ClaudeSessionService.forkTranscriptMissingReason,
        cause: null,
      );
    }
    final forkSessionId = _generateSessionId();
    try {
      await _sessions.forkSession(
        sessionId: sessionId,
        throughMessageId: throughMessageId,
        forkSessionId: forkSessionId,
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation: operation, message: "Claude fork could not be written", cause: error);
    }
    final now = _clock.now().millisecondsSinceEpoch;
    final session = PluginSession(
      id: forkSessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: null,
      time: PluginSessionTime(created: now, updated: now, archived: null),
    );
    _eventBuffer.add(BridgeSseSessionCreated(info: session.toJson()));
    return session;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginOperationException.notFound(operation: "sendCommand", message: "session not found");
    }
    // A catalog cached before these were filtered can still offer them.
    if (ClaudeBackendCatalogRepository.selectionCommands.contains(command)) {
      throw const PluginStaleOptionsException(
        operation: "sendCommand",
        message: "model, effort and fast mode are set through the session selection",
      );
    }
    final visible = userVisibleArguments?.trim();
    await _enqueueQueued(
      sessionId: sessionId,
      directory: directory,
      parts: [PluginPromptPart.text(text: arguments.isEmpty ? "/$command" : "/$command $arguments")],
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
      operation: "sendCommand",
      promptId: promptId,
      displayText: visible == null || visible.isEmpty ? null : visible,
      command: command,
      attachmentCount: 0,
    );
  }

  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async =>
      _sessions.queuedPrompts(sessionId: sessionId);

  @override
  Future<PluginSessionReadiness> getSessionReadiness({required String sessionId}) async =>
      _sessions.getSessionReadiness(
        sessionId: sessionId,
        sessionExists:
            _createdSessions.containsKey(sessionId) ||
            await _transcripts.findTranscriptPath(sessionId: sessionId) != null ||
            _sessionWithoutTranscript(sessionId) != null,
      );

  /// The cache life the account's billing route gives, as the catalog read it
  /// from Claude's handshake.
  @override
  Future<Duration?> getPromptCacheLife({required String sessionId}) async => (await _catalogService.getCatalog(
    directory: await _directoryForSession(sessionId),
    refresh: false,
  )).promptCacheLife;

  /// Runs Claude's `/compact` with the session's applied selection, so the
  /// compaction neither switches the model nor restarts the process.
  @override
  Future<PluginCompactionResult> compactSession({required String sessionId, required String promptId}) async {
    const operation = "compactSession";
    if (ClaudeSubagentSessionId.agentIdOf(sessionId) != null) return PluginCompactionResult.unsupported;
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginOperationException.notFound(operation: operation, message: "session not found");
    }
    // The last await before the enqueue, so a turn sent meanwhile is seen.
    switch (await getSessionReadiness(sessionId: sessionId)) {
      case PluginSessionReadiness.busy ||
          PluginSessionReadiness.retrying ||
          PluginSessionReadiness.queued ||
          PluginSessionReadiness.awaitingInput:
        return PluginCompactionResult.sessionBusy;
      case PluginSessionReadiness.idle || PluginSessionReadiness.unavailable || PluginSessionReadiness.unknown:
        break;
    }
    final applied = _processes.appliedSelection(sessionId: sessionId);
    const command = ClaudeBackendCatalogRepository.compactionCommand;
    await _enqueueResolved(
      sessionId: sessionId,
      directory: directory,
      parts: [const PluginPromptPart.text(text: "/$command")],
      model: applied?.model,
      effort: applied?.effort,
      permissionMode: applied?.permissionMode,
      fastMode: applied?.fastMode ?? false,
      operation: operation,
      promptId: promptId,
      displayText: null,
      command: command,
      attachmentCount: 0,
    );
    return PluginCompactionResult.accepted;
  }

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async =>
      _sessions.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);

  @override
  Future<PluginSideAnswer> askSideQuestion({
    required String sessionId,
    required String question,
    required List<PluginSideExchange> history,
  }) async {
    // A session created here has no transcript until its first turn starts,
    // so there is nothing to resume or answer from.
    if (_unstartedSessions.contains(sessionId)) {
      return const PluginSideRefused(reason: PluginSideRefusal.noTurnYet);
    }
    final directory = await _directoryForSession(sessionId);
    if (directory == null) {
      throw const PluginOperationException.notFound(operation: "askSideQuestion", message: "session not found");
    }
    return await _sessions.askSideQuestion(
      sessionId: sessionId,
      directory: directory,
      question: question,
      history: history,
    );
  }

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
    required bool useAtomicStop,
    required Set<String> knownSubAgentSessionIds,
  }) => _sessions.abort(sessionId: sessionId, subAgents: subAgents);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async =>
      (await _catalogService.getCatalog(directory: projectId, refresh: false)).agents;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async =>
      _approvals.pendingQuestionsForSession(sessionId: sessionId);

  @override
  Future<List<PluginPendingExternalAction>> getPendingExternalActions({required String sessionId}) async =>
      _approvals.pendingExternalActionsForSession(sessionId: sessionId);

  @override
  Future<List<PluginPendingForm>> getPendingForms({required String sessionId}) async =>
      _approvals.pendingFormsForSession(sessionId: sessionId);

  @override
  Future<PluginFormSubmissionResult> replyToForm({
    required String requestId,
    required String sessionId,
    required Map<String, PluginFormValue> values,
  }) async => _approvals.replyForm(id: requestId, sessionId: sessionId, values: values);

  @override
  Future<PluginFormDismissalResult> declineForm({
    required String requestId,
    required String sessionId,
    required PluginFormDismissalChoice choice,
  }) async => _approvals.declineForm(id: requestId, sessionId: sessionId, choice: choice);

  @override
  Future<PluginExternalActionReply> replyToExternalAction({
    required String requestId,
    required String sessionId,
    required PluginExternalActionChoice choice,
  }) async => _approvals.replyExternalAction(id: requestId, sessionId: sessionId, choice: choice);

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async =>
      _approvals.pendingPermissionsForSession(sessionId: sessionId);

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 answers through question routes.
    // Remove when all supported production clients consume typed forms.
    if (_approvals.hasForm(id: questionId)) {
      if (answers.length != 1 || answers.single.length != 1 || answers.single.single != "Cancel") {
        throw const PluginOperationException(
          operation: "replyToQuestion",
          statusCode: 400,
          message: "this form notice can only be cancelled",
        );
      }
      _cancelLegacyForm(id: questionId, sessionId: sessionId);
      return;
    }
    // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 answers through question routes.
    // Remove when all supported production clients consume typed external actions.
    if (_approvals.hasExternalAction(id: questionId)) {
      if (answers.length != 1 || answers.single.length != 1 || answers.single.single != "Cancel") {
        throw const PluginOperationException(
          operation: "replyToQuestion",
          statusCode: 400,
          message: "this external-action notice can only be cancelled",
        );
      }
      _cancelLegacyExternalAction(id: questionId, sessionId: sessionId);
      return;
    }
    final exitsPlanMode = _approvals.isExitPlanModeQuestion(id: questionId);
    if (!_approvals.hasQuestion(id: questionId)) {
      throw const PluginOperationException.notFound(operation: "replyToQuestion", message: "question not found");
    }
    if (!_approvals.replyQuestion(id: questionId, answers: answers)) {
      throw const PluginOperationException(
        operation: "replyToQuestion",
        message: "Claude rejected the question response",
      );
    }
    // COMPATIBILITY 2026-09-21 (v1.9.0): Only an honoured "Plan" selection reaches plan
    // exit now. Remove with `ClaudeAgentSelection.plan`.
    if (exitsPlanMode) {
      final applied = _processes.appliedSelection(sessionId: sessionId);
      if (applied != null) {
        _processes.recordAppliedSelection(
          sessionId: sessionId,
          model: applied.model,
          effort: applied.effort,
          permissionMode: ClaudePermissionMode.auto,
          fastMode: applied.fastMode,
        );
      }
      _eventBuffer.add(
        BridgeSseSessionPromptDefaultsChanged(
          sessionID: sessionId,
          agent: ClaudeAgentSelection.standard.displayName,
          model: null,
        ),
      );
    }
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 rejects through question routes.
    // Remove when all supported production clients consume typed forms.
    if (_approvals.hasForm(id: questionId)) {
      _cancelLegacyForm(id: questionId, sessionId: sessionId);
      return;
    }
    // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 rejects through question routes.
    // Remove when all supported production clients consume typed external actions.
    if (_approvals.hasExternalAction(id: questionId)) {
      _cancelLegacyExternalAction(id: questionId, sessionId: sessionId);
      return;
    }
    if (!_approvals.hasQuestion(id: questionId)) {
      throw const PluginOperationException.notFound(operation: "rejectQuestion", message: "question not found");
    }
    if (!_approvals.rejectQuestion(id: questionId)) {
      throw const PluginOperationException(
        operation: "rejectQuestion",
        message: "Claude rejected the question response",
      );
    }
  }

  void _cancelLegacyForm({required String id, required String? sessionId}) {
    if (sessionId == null) {
      throw const PluginOperationException.notFound(operation: "cancelForm", message: "owning session is required");
    }
    switch (_approvals.declineForm(id: id, sessionId: sessionId, choice: PluginFormDismissalChoice.cancel)) {
      case PluginFormDismissalResult.accepted:
        return;
      case PluginFormDismissalResult.alreadySettled:
        throw const PluginOperationException.notFound(
          operation: "cancelForm",
          message: "native request is not pending",
        );
      case PluginFormDismissalResult.unavailable:
        throw const PluginOperationException(
          operation: "cancelForm",
          statusCode: 503,
          message: "native reply unavailable",
        );
    }
  }

  void _cancelLegacyExternalAction({required String id, required String? sessionId}) {
    if (sessionId == null) {
      throw const PluginOperationException.notFound(
        operation: "cancelExternalAction",
        message: "owning session is required",
      );
    }
    switch (_approvals.replyExternalAction(id: id, sessionId: sessionId, choice: PluginExternalActionChoice.cancel)) {
      case PluginExternalActionReply.accepted:
        return;
      case PluginExternalActionReply.alreadySettled:
        throw const PluginOperationException.notFound(
          operation: "cancelExternalAction",
          message: "native request is not pending",
        );
      case PluginExternalActionReply.unsupportedChoice:
        throw const PluginOperationException(
          operation: "cancelExternalAction",
          statusCode: 400,
          message: "unsupported native choice",
        );
      case PluginExternalActionReply.unavailable:
        throw const PluginOperationException(
          operation: "cancelExternalAction",
          statusCode: 503,
          message: "native reply unavailable",
        );
    }
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    if (!_approvals.hasPermission(id: requestId)) {
      throw const PluginOperationException.notFound(operation: "replyToPermission", message: "permission not found");
    }
    if (!_approvals.replyPermission(id: requestId, reply: reply)) {
      throw const PluginOperationException(
        operation: "replyToPermission",
        message: "Claude rejected the permission response",
      );
    }
    if (reply != PluginPermissionReply.always) return;
    // Always on a file edit has Claude switch itself to accept-edits. Record
    // that, so the next turn neither sets the mode again nor waits on the
    // running turn as a selection change would.
    final applied = _processes.appliedSelection(sessionId: sessionId);
    if (applied == null) return;
    final permissionMode = _approvals.permissionModeFor(sessionId: sessionId, requested: applied.permissionMode);
    if (permissionMode == applied.permissionMode) return;
    _processes.recordAppliedSelection(
      sessionId: sessionId,
      model: applied.model,
      effort: applied.effort,
      permissionMode: permissionMode,
      fastMode: applied.fastMode,
    );
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      (await _catalogService.getCatalog(directory: projectId, refresh: false)).providers;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final byProject = <String, List<PluginActiveSession>>{};
    for (final entry in _sessions.sessionStatuses.entries) {
      final running = entry.value is PluginSessionStatusBusy || entry.value is PluginSessionStatusRetry;
      final awaitingInput = _approvals.hasPendingInput(sessionId: entry.key);
      if (!running && !awaitingInput) continue;
      // A running session was resolved by its send, so the cache holds it.
      final cached = _transcripts.cachedSessionById(sessionId: entry.key);
      final directory =
          _createdSessions[entry.key]?.directory ??
          (cached == null ? null : normalizeProjectDirectory(directory: cached.cwd));
      if (directory == null) continue;
      (byProject[directory] ??= []).add(
        PluginActiveSession(
          id: entry.key,
          // Busy also covers background sub-agents alone, which report as
          // children; a background shell is the main agent's own work.
          mainAgentRunning: _sessions.isMainAgentRunning(sessionId: entry.key),
          awaitingInput: awaitingInput,
          isRetrying: entry.value is PluginSessionStatusRetry,
          childSessionIds: _eventDispatcher.busyChildSessionIds(sessionId: entry.key),
        ),
      );
    }
    return [
      for (final entry in byProject.entries) PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) async {
    await _transcripts.deleteSession(sessionId: backendSessionId);
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    await _subscriptions.cancel();
    await _sessions.dispose();
    _createdSessions.clear();
    _unstartedSessions.clear();
    _primedDirectories.clear();
    await _eventBuffer.close();
  }

  /// Queues a send to an existing session, accepted at enqueue.
  Future<void> _enqueueQueued({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
    required String promptId,
    required String? displayText,
    required String? command,
    required int attachmentCount,
  }) async {
    final (:effort, :permissionMode) = _queuedSelections(
      sessionId: sessionId,
      variant: variant,
      agent: agent,
      model: model,
      operation: operation,
    );
    await _enqueueResolved(
      sessionId: sessionId,
      directory: directory,
      parts: parts,
      model: model?.modelID,
      effort: effort,
      permissionMode: permissionMode,
      fastMode: fastMode,
      operation: operation,
      promptId: promptId,
      displayText: displayText,
      command: command,
      attachmentCount: attachmentCount,
    );
  }

  Future<void> _enqueueResolved({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required bool fastMode,
    required String operation,
    required String promptId,
    required String? displayText,
    required String? command,
    required int attachmentCount,
  }) async {
    try {
      await _sessions.enqueueTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: _unstartedSessions.contains(sessionId),
        parts: parts,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        fastMode: fastMode,
        promptId: promptId,
        displayText: displayText,
        command: command,
        attachmentCount: attachmentCount,
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation: operation, message: "Claude did not accept the turn", cause: error);
    }
  }

  /// Validates a send to an existing session, before anything is queued.
  ({ClaudeEffortLevel? effort, ClaudePermissionMode? permissionMode}) _queuedSelections({
    required String sessionId,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
  }) {
    // A sub-agent transcript is not a Claude process session: nothing can be
    // resumed under its id, so a write to it is refused rather than spawning a
    // CLI that fails.
    if (ClaudeSubagentSessionId.agentIdOf(sessionId) != null) {
      throw PluginOperationException(
        operation: operation,
        statusCode: 400,
        message: "sub-agent sessions are read-only",
      );
    }
    _validateModel(model, operation: operation, staleOptions: true);
    return (
      effort: _effort(variant, operation: operation, staleOptions: true),
      permissionMode: _permissionMode(agent, operation: operation, staleOptions: true),
    );
  }

  /// Runs a new session's first turn with acceptance at dispatch, so session
  /// creation can roll back when the initial prompt never starts.
  Future<void> _enqueueInitial({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
  }) async {
    _validateModel(model, operation: operation, staleOptions: false);
    final effort = _effort(variant, operation: operation, staleOptions: false);
    final permissionMode = _permissionMode(agent, operation: operation, staleOptions: false);
    _eventDispatcher.beginTurn(
      sessionId: sessionId,
      directory: directory,
      model: model?.modelID,
      variant: effort?.wireValue,
    );
    try {
      await _sessions.enqueueInitialTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: true,
        parts: parts,
        model: model?.modelID,
        effort: effort,
        permissionMode: permissionMode,
        fastMode: fastMode,
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error) {
      throw PluginOperationException(operation: operation, message: "Claude did not accept the turn", cause: error);
    }
  }

  PluginOperationException _unsupportedSelection({
    required String operation,
    required String message,
    required bool staleOptions,
  }) => staleOptions
      ? PluginStaleOptionsException(operation: operation, message: message)
      : PluginOperationException(operation: operation, statusCode: 400, message: message);

  void _validateModel(
    ({String providerID, String modelID})? model, {
    required String operation,
    required bool staleOptions,
  }) {
    if (model == null) return;
    if (model.providerID != ClaudeBackendCatalogRepository.providerId ||
        model.modelID.trim().isEmpty ||
        model.modelID == _syntheticModelId) {
      throw _unsupportedSelection(
        operation: operation,
        message: "unsupported Claude model",
        staleOptions: staleOptions,
      );
    }
  }

  ClaudeEffortLevel? _effort(
    PluginSessionVariant? variant, {
    required String operation,
    required bool staleOptions,
  }) {
    if (variant == null) return null;
    final effort = ClaudeEffortLevel.tryParse(variant.id);
    if (effort == null) {
      throw _unsupportedSelection(
        operation: operation,
        message: "unsupported Claude effort",
        staleOptions: staleOptions,
      );
    }
    return effort;
  }

  ClaudePermissionMode? _permissionMode(
    String? agent, {
    required String operation,
    required bool staleOptions,
  }) {
    if (agent == null) return null;
    final selection = ClaudeAgentSelection.tryParse(agent);
    if (selection == null) {
      throw _unsupportedSelection(
        operation: operation,
        message: "unsupported Claude agent",
        staleOptions: staleOptions,
      );
    }
    return selection.permissionMode;
  }

  Future<PluginSession?> _findSession(String sessionId) async =>
      _createdSessions[sessionId] ??
      await _transcripts.findSessionById(sessionId: sessionId) ??
      _sessionWithoutTranscript(sessionId);

  /// A session known here that has no transcript. Claude Code writes nothing
  /// until a session's first prompt, so a session created without one, such
  /// as an empty fork, is only in memory. After a bridge restart the
  /// bridge's directory hint is all that is left of it, so a hinted root
  /// session without a transcript is taken as unstarted again, and its first
  /// prompt starts it under its own id.
  PluginSession? _sessionWithoutTranscript(String sessionId) {
    if (_createdSessions[sessionId] case final created?) return created;
    final directory = _primedDirectories[sessionId];
    if (directory == null || ClaudeSubagentSessionId.agentIdOf(sessionId) != null) return null;
    final now = _clock.now().millisecondsSinceEpoch;
    final session = PluginSession(
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: null,
      time: PluginSessionTime(created: now, updated: now, archived: null),
    );
    _createdSessions[sessionId] = session;
    _unstartedSessions.add(sessionId);
    return session;
  }

  Future<String?> _directoryForSession(String sessionId) async => (await _findSession(sessionId))?.directory;

  /// Forwards the dispatcher's [events]. A status among them, a sub-agent's or
  /// a retry, changes the activity summary session lists read, which only a
  /// republication refreshes.
  void _addMapped(List<BridgeSseEvent> events) {
    events.forEach(_eventBuffer.add);
    if (events.any((event) => event is BridgeSseSessionStatus)) _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  void _handleProcessEvent(ClaudeSessionProcessEvent event) {
    if (event is ClaudeSessionProcessExited) {
      // Sub-agents live only inside the resident process.
      _addMapped(_eventDispatcher.cancelTasks(sessionId: event.sessionId));
      return;
    }
    if (event case ClaudeSessionProcessMessage(:final message, :final interrupted, :final promptId)) {
      // Between an acknowledged interrupt and the interrupted turn's result the
      // CLI can still stream that turn's output; a full stop tears the process
      // down, a main-agent-only stop keeps it, so assistant output is dropped
      // here. User echoes still render (they are the prompt's transcript identity,
      // and the CLI's interrupt record becomes the turn's stopped row) and so do
      // forwarded sub-agent frames, which belong to the kept work.
      if (interrupted) {
        if (message
            case ClaudeAssistantMessage(parentToolUseId: null) || ClaudeStreamEventMessage(parentToolUseId: null)) {
          return;
        }
      }
      if (message is ClaudeResultMessage && interrupted) {
        _eventDispatcher.completeTurn(sessionId: event.sessionId);
        return;
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
        _addMapped(_eventDispatcher.map(message: message, now: now));
        return;
      }
      if (message is ClaudeUserMessage &&
          promptId != null &&
          _sessions.queuedPrompts(sessionId: event.sessionId).any((entry) => entry.id == promptId)) {
        final events = _eventDispatcher.mapPromptReplay(message: message, promptId: promptId);
        // A replay that maps to nothing visible leaves the queued entry alone:
        // releasing it without a replacement message would drop the prompt from
        // the transcript. Turn settlement removes the entry instead.
        if (events.isEmpty) return;
        events.forEach(_eventBuffer.add);
        _sessions.consumeQueuedPrompt(sessionId: event.sessionId, promptId: promptId);
        return;
      }
      _addMapped(_eventDispatcher.map(message: message, now: null));
      if (message is ClaudeResultMessage) _eventDispatcher.completeTurn(sessionId: event.sessionId);
      // `claude auth status` still reports logged in when the stored OAuth
      // session can no longer refresh; only the turn reveals it.
      if (message case ClaudeAssistantMessage(error: ClaudeAssistantError.authenticationFailed)) {
        _eventBuffer.addError(
          // A gateway behind a custom base URL owns authentication, so a
          // Claude login would not help. The URL stays out of the hint because
          // it can carry credentials.
          _usesCustomBaseUrl()
              ? const PluginAuthenticationRequiredException(
                  operation: "claude session",
                  actionHint:
                      "The Anthropic-compatible gateway configured for Claude Code rejected the request. "
                      "Check the gateway's credentials and configuration, then refresh setup.",
                  recovery: PluginAuthenticationRecovery.externalConfiguration,
                  message: "Claude Code gateway authentication failed",
                )
              : const PluginAuthenticationRequiredException(
                  operation: "claude session",
                  actionHint: "Log in from Sesori, or run `claude auth login` on this machine.",
                  recovery: PluginAuthenticationRecovery.login,
                  message: "Claude Code authentication failed",
                ),
        );
      }
      // Cloud provider credentials (Bedrock, Vertex, Foundry) live outside
      // Claude Code, so a Claude login would not fix them.
      if (message case ClaudeAssistantMessage(error: ClaudeAssistantError.cloudCredentialError)) {
        _eventBuffer.addError(
          const PluginAuthenticationRequiredException(
            operation: "claude session",
            actionHint:
                "The cloud provider configured for Claude Code rejected its credentials. "
                "Refresh the provider credentials on this machine, then refresh setup.",
            recovery: PluginAuthenticationRecovery.externalConfiguration,
            message: "Claude Code cloud credentials failed",
          ),
        );
      }
    }
  }

  void _handleTurnDispatched(ClaudeTurnDispatched event) {
    _unstartedSessions.remove(event.sessionId);
    if (!event.isSteering) {
      final applied = _processes.appliedSelection(sessionId: event.sessionId);
      _eventDispatcher.beginTurn(
        sessionId: event.sessionId,
        directory: event.directory,
        model: applied?.model,
        variant: applied?.effort?.wireValue,
      );
    }
    final command = event.command;
    if (command == null) return;
    final visible = event.displayText;
    _emitVisibleUserMessage(
      sessionId: event.sessionId,
      messageId: event.messageId,
      text: visible == null || visible.isEmpty ? "/$command" : "/$command $visible",
      promptId: event.promptId,
    );
    _sessions.consumeQueuedPrompt(sessionId: event.sessionId, promptId: event.promptId);
  }

  /// Synthesizes the visible user bubble for a slash command at dispatch.
  ///
  /// Plain prompts never need this: `--replay-user-messages` echoes them under
  /// their transcript uuid. A command's echo is the CLI's `<command-name>`
  /// envelope, which the live path drops, so this message is the turn's only
  /// live user row. It takes the uuid the command was sent with, which the CLI
  /// keeps for the envelope's transcript record, so history replays this same
  /// row instead of adding a second one.
  void _emitVisibleUserMessage({
    required String sessionId,
    required String messageId,
    required String? text,
    required String? promptId,
  }) {
    final visible = text?.trim();
    if (visible == null || visible.isEmpty) return;
    final now = _clock.now().millisecondsSinceEpoch;
    _eventBuffer.add(
      BridgeSseMessageUpdated(
        info: PluginMessage.user(
          id: messageId,
          sessionID: sessionId,
          agent: null,
          time: PluginMessageTime(created: now, completed: now),
          promptId: promptId,
          invocation: null,
        ),
      ),
    );
    _eventBuffer.add(
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart.text(
          id: "$messageId-text",
          sessionID: sessionId,
          messageID: messageId,
          text: visible,
        ),
      ),
    );
  }
}

void _requireTurn({required List<PluginPromptPart> parts, required String operation}) {
  if (parts.isEmpty) {
    throw PluginOperationException(operation: operation, statusCode: 400, message: "prompt must not be empty");
  }
}

/// A prompt's text parts as its queued bubble shows them, or null for none.
String? _displayText(List<PluginPromptPart> parts) {
  final text = parts
      .whereType<PluginPromptPartText>()
      .map((part) => part.text)
      .where((text) => text.trim().isNotEmpty)
      .join("\n\n")
      .trim();
  return text.isEmpty ? null : text;
}

int _attachmentCount(List<PluginPromptPart> parts) => parts.length - parts.whereType<PluginPromptPartText>().length;

List<PluginSession> _mergeSessions({
  required Iterable<PluginSession> persisted,
  required Iterable<PluginSession> created,
}) {
  final byId = {for (final session in persisted) session.id: session};
  for (final session in created) {
    byId.putIfAbsent(session.id, () => session);
  }
  return byId.values.toList(growable: false);
}
