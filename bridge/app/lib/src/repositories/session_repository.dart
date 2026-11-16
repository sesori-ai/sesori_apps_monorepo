import "dart:async";
import "dart:math";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PersistedSessionCleanupApi,
        PluginAbortAccepted,
        PluginAbortNotPerformed,
        PluginAbortRejectedSubAgentsRunning,
        PluginActiveSession,
        PluginBranchPointUnavailableException,
        PluginCompactionResult,
        PluginOperationException,
        PluginProjectActivitySummary,
        PluginQuotaReportingSupport,
        PluginSession,
        PluginSessionActivityAvailable,
        PluginSessionActivityUnavailable,
        PluginSessionReadiness,
        PluginSessionStatus,
        PluginSessionVariant,
        PluginSideExchange,
        SessionForkPluginApi,
        SessionRewindPluginApi,
        SideQuestionPluginApi;
import "package:sesori_shared/sesori_shared.dart"
    show
        ActiveSession,
        ActiveSessionRunningCalculator,
        AgentModel,
        AutoContinuationAvailability,
        CommandInvocation,
        CommandListResponse,
        CommandSource,
        Message,
        MessageHandoff,
        MessageHandoffSent,
        MessagePartSubtask,
        MessageUser,
        MessageWithParts,
        ProjectActivitySummary,
        ProjectKind,
        PromptModel,
        QueuedSessionPrompt,
        Session,
        SessionAbortNotPerformedRefusal,
        SessionAbortSubAgentPolicy,
        SessionApprovalMode,
        SessionPageCounts,
        SessionPageFilter,
        SessionPageMode,
        SessionPromptDefaults,
        SessionStatus,
        SessionStatusBusy,
        SessionStatusIdle,
        SessionStatusResponse,
        SessionStatusRetry,
        SessionVariant,
        SideQuestionRefusal,
        matchTexts,
        projectOwnName,
        searchWords;

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../api/database/tables/projects_table.dart" show ProjectDto;
import "../api/database/tables/session_table.dart" show SessionDto;
import "../runtime/plugin_runtime.dart";
import "mappers/deliverable_prompt_part_mapper.dart";
import "mappers/plugin_activity_summary_mapper.dart";
import "mappers/plugin_command_mapper.dart";
import "mappers/plugin_message_mapper.dart";
import "mappers/plugin_session_status_mapper.dart";
import "mappers/plugin_side_answer_mapper.dart";
import "mappers/plugin_to_shared_mapping.dart";
import "mappers/project_catalog_mapper.dart";
import "mappers/session_catalog_mapper.dart";
import "mappers/stored_session_mapper.dart";
import "models/deliverable_prompt_part.dart";
import "models/project_not_found_exception.dart";
import "models/session_abort_result.dart";
import "models/session_compaction_result.dart";
import "models/session_operation.dart";
import "models/session_page_cursor.dart";
import "models/session_quietness.dart";
import "models/session_readiness.dart";
import "models/side_question_ask_result.dart";
import "models/stored_session.dart";
import "project_catalog_identity_calculator.dart";
import "random_hex_id.dart";
import "session_unseen_calculator.dart";
import "trackers/prompt_stamp.dart";
import "trackers/prompt_stamp_tracker.dart";

enum SessionBindingCommitKind() {
  sessionCreation,
  catalogSync,

  /// An existing session now runs on a new harness session; its id is
  /// unchanged.
  sessionReplacement,
}

typedef SessionBindingsCommitted = ({
  String pluginId,
  String projectId,
  int generation,
  SessionBindingCommitKind kind,
  List<String> backendSessionIds,
});

typedef SessionFamilyScope = ({String rootSessionId, String pluginId});

/// What a scheduled task's run writes on the session it starts.
typedef ScheduledRunSessionLink = ({String taskId, SessionApprovalMode approvalOverride});

/// The deleted root as clients see it, plus every session id removed with it.
typedef DeletedSessionSubtree = ({Session session, List<String> sessionIds});

typedef SessionPage = ({List<Session> items, SessionPageCursor? nextCursor, SessionPageCounts counts});

typedef SessionMessagesSnapshot = ({
  List<MessageWithParts> messages,
  SessionPromptDefaults? promptDefaults,
});

class SessionRepository({
  required final PluginRuntime _runtime,
  required final SessionDao _sessionDao,
  required final ProjectsDao _projectsDao,
  required final SessionUnseenCalculator _unseenCalculator,
  required final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator,
  required final Duration _aggregateSourceDeadline,
}) {
  static const SessionCatalogMapper _sessionCatalogMapper = SessionCatalogMapper();
  static const ProjectCatalogMapper _projectCatalogMapper = ProjectCatalogMapper();
  static const ActiveSessionRunningCalculator _runningCalculator = ActiveSessionRunningCalculator();

  final Map<String, Set<String>> _tombstonedBackendSessionIds = <String, Set<String>>{};
  final Set<String> _deletedSessionIds = <String>{};
  final StreamController<SessionBindingsCommitted> _bindingCommitsController =
      StreamController<SessionBindingsCommitted>.broadcast(sync: true);
  final Map<String, Future<void>> _tombstoneLoads = <String, Future<void>>{};
  final Set<String> _tombstonesLoaded = <String>{};
  final Map<String, _BusyObservation> _busyObservations = <String, _BusyObservation>{};
  final PromptStampTracker _stamps = PromptStampTracker();
  int _lastProjectionTimestamp = 0;

  Stream<SessionBindingsCommitted> get bindingCommits => _bindingCommitsController.stream;

  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    const maxDepth = 256;
    final visited = <String>{};
    String? pluginId;
    var currentSessionId = sessionId;
    for (var depth = 0; depth < maxDepth; depth++) {
      if (!visited.add(currentSessionId)) {
        throw PluginOperationException(
          operation: operation.name,
          statusCode: 409,
          message: "session $sessionId has cyclic ancestry at $currentSessionId",
        );
      }
      final binding = await _sessionDao.getSession(sessionId: currentSessionId);
      if (binding == null) {
        throw PluginOperationException.notFound(
          operation: operation.name,
          message: "session $currentSessionId was not found while resolving family for $sessionId",
        );
      }
      pluginId ??= binding.pluginId;
      if (binding.pluginId != pluginId) {
        throw PluginOperationException(
          operation: operation.name,
          statusCode: 409,
          message: "session $sessionId has cross-plugin ancestry at $currentSessionId",
        );
      }
      final parentSessionId = binding.parentSessionId;
      if (parentSessionId == null) {
        return (rootSessionId: binding.sessionId, pluginId: binding.pluginId);
      }
      currentSessionId = parentSessionId;
    }
    throw PluginOperationException(
      operation: operation.name,
      statusCode: 409,
      message: "session $sessionId ancestry exceeds $maxDepth entries",
    );
  }

  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    if (await _projectsDao.getProject(projectId: projectId) == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final effectiveLimit = limit == null || limit <= 0 ? null : limit;
    return _mapCatalogSessions(
      rows: await _sessionDao.getRootCatalogSessions(
        projectId: projectId,
        offset: start ?? 0,
        limit: effectiveLimit,
      ),
    );
  }

  /// One page of root sessions across the visible projects, or only
  /// [projectId] when it is visible, with the counts behind each chip. Every
  /// word of [query] must occur in a session's title or its project's own
  /// name; Running sessions come from the plugins' live activity. With
  /// [pinnedFirst], an active page lists pinned sessions first.
  Future<SessionPage> getSessionPage({
    required SessionPageMode mode,
    required bool pinnedFirst,
    required String? projectId,
    required String? query,
    required SessionPageFilter filter,
    required SessionPageCursor? cursor,
    required int limit,
  }) async {
    // Activity first: it can hydrate an active root into a project it adds.
    final runningIds = {
      for (final summary in await getProjectActivitySummaries())
        for (final active in summary.activeSessions)
          if (_runningCalculator.isRunning(session: active)) active.id,
    };
    final projects = [
      for (final row in await _projectsDao.getCatalogProjects())
        if (projectId == null || row.projectId == projectId)
          // Only the name and kind feed the search; the flags and count are unused.
          _projectCatalogMapper.mapSummary(
            row: row,
            hasUnseenChanges: false,
            directoryMissing: false,
            sessionCount: 0,
            kind: _projectCatalogIdentityCalculator.isScratchRoot(path: row.projectId)
                ? ProjectKind.scratch
                : ProjectKind.folder,
          ),
    ];
    final page = await _sessionDao.getSessionPage(
      mode: mode,
      pinnedFirst: pinnedFirst,
      projectIds: [for (final project in projects) project.id],
      words: [
        for (final word in query == null ? const <String>[] : searchWords(query: query))
          (
            word: word,
            projectIds: [
              for (final project in matchTexts(
                items: projects,
                textsOf: (project) => [projectOwnName(project: project)],
                query: word,
              ))
                project.id,
            ],
          ),
      ],
      filter: filter,
      runningIds: runningIds,
      after: cursor == null ? null : (pinned: cursor.pinned, sortAt: cursor.sortAt, sessionId: cursor.sessionId),
      limit: limit,
    );
    return (
      items: _mapCatalogSessions(rows: page.rows),
      nextCursor: switch (page.nextKey) {
        (:final pinned, :final sortAt, :final sessionId) => SessionPageCursor(
          pinned: pinned,
          sortAt: sortAt,
          sessionId: sessionId,
        ),
        null => null,
      },
      counts: SessionPageCounts(all: page.counts.all, running: page.counts.running, unread: page.counts.unread),
    );
  }

  /// Creates the backend session and binds it under [reservedSessionId], from
  /// [reserveSessionId], so files saved for the first prompt before the
  /// plugin call land in the folder of the session that is committed. A
  /// backend session that is already bound keeps its existing id instead.
  Future<Session> createSession({
    required String reservedSessionId,
    required String pluginId,
    required String projectId,
    required String directory,
    required String? parentSessionId,
    required List<DeliverablePromptPart> parts,
    required String? userVisibleText,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
    required bool isDedicated,
    required String? worktreePath,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required bool fastMode,

    /// Written in the insert transaction, so a permission the first prompt
    /// asks is held until the binding commits and then sees the override.
    required ScheduledRunSessionLink? scheduledRun,
  }) async {
    final parentBinding = parentSessionId == null
        ? null
        : await _requireBinding(
            sessionId: parentSessionId,
            operation: SessionOperation.createSession,
          );
    if (parentBinding != null && parentBinding.pluginId != pluginId) {
      throw PluginOperationException(
        operation: SessionOperation.createSession.name,
        statusCode: 409,
        message: "parent session $parentSessionId belongs to another plugin",
      );
    }
    final result = await _runtime.useAndCommit(
      pluginId: pluginId,
      operation: SessionOperation.createSession,
      prepare: (plugin) {
        if (parentBinding != null) {
          _primeDerivedSessionDirectory(binding: parentBinding, plugin: plugin);
        }
        return plugin.createSession(
          directory: directory,
          parentSessionId: parentBinding?.backendSessionId,
          parts: parts.map((part) => part.toPlugin()).toList(growable: false),
          userVisibleText: userVisibleText,
          variant: _toPluginVariant(variant),
          fastMode: fastMode,
          agent: agent,
          model: _toPluginModel(model),
        );
      },
      commit: (created, generation) async {
        final committedRow = await _commitCreatedSession(
          operation: SessionOperation.createSession,
          pluginId: pluginId,
          reservedSessionId: reservedSessionId,
          created: created,
          projectId: projectId,
          directory: directory,
          isDedicated: isDedicated,
          worktreePath: worktreePath,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
          lastAgent: lastAgent,
          lastAgentModel: lastAgentModel,
          fastMode: fastMode,
          completeRow: ({required sessionId}) async {
            if (scheduledRun != null) {
              await _sessionDao.setScheduledRun(
                sessionId: sessionId,
                scheduledTaskId: scheduledRun.taskId,
                approvalOverride: scheduledRun.approvalOverride,
              );
            }
            if (parentBinding != null) {
              await _sessionDao.setParentSessionId(
                sessionId: sessionId,
                parentSessionId: parentBinding.sessionId,
              );
            }
          },
        );
        return (row: committedRow, backendSessionId: created.id, generation: generation);
      },
    );
    _publishBindingsCommitted(
      pluginId: pluginId,
      projectId: projectId,
      generation: result.generation,
      kind: SessionBindingCommitKind.sessionCreation,
      backendSessionIds: [result.backendSessionId],
    );
    return _sessionCatalogMapper.map(
      row: result.row,
      unseen: _unseenCalculator.isUnseen(
        activity: result.row.lastActivityAt,
        userMessage: result.row.lastUserMessageAt,
        seen: result.row.lastSeenAt,
      ),
    );
  }

  /// Forks root session [originSessionId] into a new root session in the
  /// same directory or worktree: through [throughMessageId] by the plugin's
  /// native fork, or, when it is null, as an unstarted session that keeps
  /// nothing. The new row copies the origin's project, worktree and prompt
  /// defaults, never its approval override. A backend session catalog import
  /// already bound keeps its row, which gains the fork's columns.
  ///
  /// A plugin without native fork cannot cut at any message, so it is
  /// refused the way a plugin refuses a message it cannot map.
  Future<Session> forkSession({
    required String originSessionId,
    required String? throughMessageId,
    required String? title,
    required String? forkedFromTitle,
  }) async {
    final origin = await _requireBinding(sessionId: originSessionId, operation: SessionOperation.forkSession);
    if (origin.parentSessionId != null) {
      throw PluginOperationException(
        operation: SessionOperation.forkSession.name,
        statusCode: 409,
        message: "session $originSessionId is a sub-agent session; only root sessions can be forked",
      );
    }
    final reservedSessionId = await reserveSessionId();
    final result = await _runtime.useAndCommit(
      pluginId: origin.pluginId,
      operation: SessionOperation.forkSession,
      prepare: (plugin) {
        _primeDerivedSessionDirectory(binding: origin, plugin: plugin);
        return switch (throughMessageId) {
          final messageId? => _requireSessionForkApi(plugin: plugin).forkSession(
            sessionId: origin.backendSessionId,
            throughMessageId: messageId,
          ),
          // Every plugin can create a session that has not started; its first
          // prompt takes the session's prompt defaults copied below.
          null => plugin.createSession(
            directory: origin.directory,
            parentSessionId: null,
            parts: const [],
            userVisibleText: null,
            variant: null,
            fastMode: origin.fastMode,
            agent: null,
            model: null,
          ),
        };
      },
      commit: (created, generation) async {
        final committedRow = await _commitCreatedSession(
          operation: SessionOperation.forkSession,
          pluginId: origin.pluginId,
          reservedSessionId: reservedSessionId,
          created: created,
          projectId: origin.projectId,
          directory: origin.directory,
          isDedicated: origin.isDedicated,
          worktreePath: origin.worktreePath,
          baseBranch: origin.baseBranch,
          baseCommit: origin.baseCommit,
          lastAgent: origin.lastAgent,
          lastAgentModel: origin.lastAgentModel,
          fastMode: origin.fastMode,
          completeRow: ({required sessionId}) => _sessionDao.setForkOrigin(
            sessionId: sessionId,
            forkedFromSessionId: origin.sessionId,
            forkedFromTitle: forkedFromTitle,
            title: title,
            branchName: origin.branchName,
          ),
        );
        return (row: committedRow, backendSessionId: created.id, generation: generation);
      },
    );
    _publishBindingsCommitted(
      pluginId: origin.pluginId,
      projectId: origin.projectId,
      generation: result.generation,
      kind: SessionBindingCommitKind.sessionCreation,
      backendSessionIds: [result.backendSessionId],
    );
    return _sessionCatalogMapper.map(
      row: result.row,
      unseen: _unseenCalculator.isUnseen(
        activity: result.row.lastActivityAt,
        userMessage: result.row.lastUserMessageAt,
        seen: result.row.lastSeenAt,
      ),
    );
  }

  /// Binds the backend session a create or fork just made, in one
  /// transaction: under [reservedSessionId], or under the root row catalog
  /// import already gave it. [completeRow] writes what the caller adds to
  /// the row before it is read back.
  Future<SessionDto> _commitCreatedSession({
    required SessionOperation operation,
    required String pluginId,
    required String reservedSessionId,
    required PluginSession created,
    required String projectId,
    required String directory,
    required bool isDedicated,
    required String? worktreePath,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required bool fastMode,
    required Future<void> Function({required String sessionId}) completeRow,
  }) {
    final projectionUpdatedAt = captureProjectionTimestamp();
    final createdAt = created.time?.created ?? projectionUpdatedAt;
    final updatedAt = created.time?.updated ?? createdAt;
    return _sessionDao.attachedDatabase.transaction(() async {
      final existingBinding = await _sessionDao.getSessionByBinding(
        pluginId: pluginId,
        backendSessionId: created.id,
      );
      if (existingBinding?.parentSessionId != null) {
        throw PluginOperationException(
          operation: operation.name,
          statusCode: 409,
          message: "backend session ${created.id} is already bound as a child session",
        );
      }
      final sessionId = existingBinding?.sessionId ?? reservedSessionId;
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSession(
        sessionId: sessionId,
        backendSessionId: created.id,
        projectId: projectId,
        isDedicated: isDedicated,
        createdAt: createdAt,
        worktreePath: worktreePath,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
        lastAgent: lastAgent,
        lastAgentModel: lastAgentModel,
        fastMode: fastMode,
        pluginId: pluginId,
      );
      await completeRow(sessionId: sessionId);
      await _sessionDao.updateObservedSessionProjection(
        sessionId: sessionId,
        directory: directory,
        catalogTitle: created.title,
        updateCatalogTitle: true,
        updatedAt: updatedAt,
        projectionUpdatedAt: projectionUpdatedAt,
      );
      final committed = await _sessionDao.getSession(sessionId: sessionId);
      if (committed == null) {
        throw StateError("session $sessionId is missing right after it was inserted in this transaction");
      }
      return committed;
    });
  }

  Future<void> renameSession({required String sessionId, required String title}) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.renameSession,
    body: (plugin, binding) => plugin.renameSession(sessionId: binding.backendSessionId, title: title),
  );

  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) async {
    final normalizedProjectId = projectId?.trim();
    final directory = normalizedProjectId == null || normalizedProjectId.isEmpty
        ? null
        : await resolveProjectDirectory(projectId: normalizedProjectId);
    final commands = await _runtime.use(
      pluginId: pluginId,
      operation: SessionOperation.getCommands,
      body: (plugin) => plugin.getCommands(projectId: directory),
    );
    return CommandListResponse(
      items: commands.map((command) => command.toSharedCommandInfo()).toList(growable: false),
    );
  }

  /// Sends [command] and remembers it under [promptId], so the user message
  /// that fulfils it is named by [stampLiveMessage].
  ///
  /// [commandSource] is the command's source as the client's picker listed
  /// it; null from clients that predate it.
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required CommandSource? commandSource,
    required String arguments,
    required String? userVisibleArguments,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    try {
      await _useSessionPlugin(
        sessionId: sessionId,
        operation: SessionOperation.sendCommand,
        body: (plugin, binding) {
          // Only for a plugin that declares it names runs, so a client that
          // showed a bubble while sending never sees the turn turn into a card.
          // Recorded before the plugin call: its echo can arrive before the
          // call returns. A definitely refused send forgets it again.
          if (_runtime.namesCommandInvocations(pluginId: plugin.id)) {
            _stamps.record(
              sessionId: sessionId,
              promptId: promptId,
              stamp: PromptStampCommand(
                invocation: CommandInvocation(
                  name: command,
                  source: commandSource ?? CommandSource.unknown,
                  arguments: userVisibleArguments,
                ),
              ),
            );
          }
          return plugin.sendCommand(
            sessionId: binding.backendSessionId,
            promptId: promptId,
            command: command,
            arguments: arguments,
            userVisibleArguments: userVisibleArguments,
            variant: _toPluginVariant(variant),
            fastMode: fastMode,
            agent: agent,
            model: _toPluginModel(model),
          );
        },
      );
    } on PluginOperationException catch (error) {
      // Only a definite refusal forgets the entry. A send whose outcome is
      // unknown (timeout, 5xx, no status) may still have run, and its late
      // echo must come back named, or its card would turn into a bubble.
      _forgetStampOnRefusal(sessionId: sessionId, promptId: promptId, error: error);
      rethrow;
    }
  }

  void _forgetStampOnRefusal({
    required String sessionId,
    required String promptId,
    required PluginOperationException error,
  }) {
    if (error.statusCode case final status? when status >= 400 && status < 500) {
      _stamps.remove(sessionId: sessionId, promptId: promptId);
    }
  }

  /// [message] with the stamp this bridge recorded under its prompt id.
  ///
  /// A plugin that named the invocation itself keeps its own value.
  Message stampLiveMessage({required Message message}) {
    if (message case MessageUser(:final sessionID, promptId: final promptId?)) {
      switch (_stamps.stampFor(sessionId: sessionID, promptId: promptId)) {
        case PromptStampCommand(:final invocation) when message.invocation == null:
          return message.copyWith(invocation: invocation);
        case PromptStampHandoff(:final handoff):
          return message.copyWith(handoff: handoff);
        case PromptStampCommand() || null:
          break;
      }
    }
    return message;
  }

  /// Turns the `sent` handoff recorded for the prompt [promptId] to
  /// [sessionId] into its not-sent form, so an echo that has yet to arrive,
  /// or a later live update of one that has, is stamped as not sent.
  void markHandoffNotSent({required String sessionId, required String promptId}) {
    if (_stamps.stampFor(sessionId: sessionId, promptId: promptId) case PromptStampHandoff(
      handoff: MessageHandoffSent(:final targetSessionId, :final targetTitle),
    )) {
      _stamps.record(
        sessionId: sessionId,
        promptId: promptId,
        stamp: PromptStampHandoff(
          handoff: MessageHandoff.notSent(targetSessionId: targetSessionId, targetTitle: targetTitle),
        ),
      );
    }
  }

  /// [prompts] with the source of each command this bridge sent to [sessionId].
  List<QueuedSessionPrompt> stampQueuedCommandSources({
    required String sessionId,
    required List<QueuedSessionPrompt> prompts,
  }) => [
    for (final prompt in prompts)
      if (prompt.command != null && prompt.commandSource == null)
        prompt.copyWith(
          commandSource: switch (_stamps.stampFor(sessionId: sessionId, promptId: prompt.id)) {
            PromptStampCommand(:final invocation) => invocation.source,
            PromptStampHandoff() || null => null,
          },
        )
      else
        prompt,
  ];

  /// Sends [parts] as the prompt [promptId]. A [handoff] is remembered under
  /// [promptId], so the user message that fulfils it is stamped by
  /// [stampLiveMessage].
  Future<void> sendPrompt({
    required String sessionId,
    required String promptId,
    required List<DeliverablePromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required MessageHandoff? handoff,
  }) async {
    try {
      await _useSessionPlugin(
        sessionId: sessionId,
        operation: SessionOperation.sendPrompt,
        body: (plugin, binding) {
          // Recorded before the plugin call: its echo can arrive before the
          // call returns. A definitely refused send forgets it again.
          if (handoff != null) {
            _stamps.record(
              sessionId: sessionId,
              promptId: promptId,
              stamp: PromptStampHandoff(handoff: handoff),
            );
          }
          return plugin.sendPrompt(
            sessionId: binding.backendSessionId,
            promptId: promptId,
            parts: parts.map((part) => part.toPlugin()).toList(growable: false),
            variant: _toPluginVariant(variant),
            fastMode: fastMode,
            agent: agent,
            model: _toPluginModel(model),
          );
        },
      );
    } on PluginOperationException catch (error) {
      _forgetStampOnRefusal(sessionId: sessionId, promptId: promptId, error: error);
      rethrow;
    }
  }

  /// Removes [beforeMessageId] and every later message from [sessionId]'s
  /// conversation through the plugin's native rewind, then sends [parts] as
  /// its next prompt, as [sendPrompt] does.
  ///
  /// A plugin without native rewind cannot branch at any message, so it is
  /// refused the way a plugin refuses a message it cannot map.
  Future<void> rewindAndSendPrompt({
    required String sessionId,
    required String beforeMessageId,
    required String promptId,
    required List<DeliverablePromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.rewindSession,
    body: (plugin, binding) => _requireSessionRewindApi(plugin: plugin).rewindAndSendPrompt(
      sessionId: binding.backendSessionId,
      beforeMessageId: beforeMessageId,
      promptId: promptId,
      parts: parts.map((part) => part.toPlugin()).toList(growable: false),
      variant: _toPluginVariant(variant),
      fastMode: fastMode,
      agent: agent,
      model: _toPluginModel(model),
    ),
  );

  /// Moves root session [sessionId] onto a new harness session, created in
  /// its directory with [parts] as its first prompt, keeping the session id.
  ///
  /// The old harness session is deleted the way [deleteSession] deletes one:
  /// its subtree is tombstoned and its sub-agent rows removed, in the
  /// transaction that rebinds the row. Returns the ids of the removed rows,
  /// whose history the caller purges. A failed backend delete is only logged:
  /// startup reconciliation retries it through the tombstone.
  Future<List<String>> replaceBackendSession({
    required String sessionId,
    required List<DeliverablePromptPart> parts,
    required String? userVisibleText,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    const operation = SessionOperation.rewindSession;
    final binding = await _requireBinding(sessionId: sessionId, operation: operation);
    final result = await _runtime.useAndCommit(
      pluginId: binding.pluginId,
      operation: operation,
      prepare: (plugin) => plugin.createSession(
        directory: binding.directory,
        parentSessionId: null,
        parts: parts.map((part) => part.toPlugin()).toList(growable: false),
        userVisibleText: userVisibleText,
        variant: _toPluginVariant(variant),
        fastMode: fastMode,
        agent: agent,
        model: _toPluginModel(model),
      ),
      commit: (created, generation) async {
        final removedSessionIds = await _tombstoneSubtree(
          root: binding,
          removeRows: (subtree) async {
            // Catalog import may have bound the new harness session to a row
            // of its own before this commit; that row is this replacement.
            final stray = await _sessionDao.getSessionByBinding(
              pluginId: binding.pluginId,
              backendSessionId: created.id,
            );
            final straySubtree = stray == null ? const <SessionDto>[] : await _getSessionSubtree(root: stray);
            if (stray != null) await _sessionDao.deleteSession(sessionId: stray.sessionId);
            await _sessionDao.rebindBackendSession(sessionId: sessionId, backendSessionId: created.id);
            final children = subtree.skip(1).toList(growable: false);
            for (final child in children) {
              if (child.parentSessionId == sessionId) await _sessionDao.deleteSession(sessionId: child.sessionId);
            }
            return [
              for (final row in [...straySubtree, ...children]) row.sessionId,
            ];
          },
        );
        return (backendSessionId: created.id, generation: generation, removedSessionIds: removedSessionIds);
      },
    );
    _publishBindingsCommitted(
      pluginId: binding.pluginId,
      projectId: binding.projectId,
      generation: result.generation,
      kind: SessionBindingCommitKind.sessionReplacement,
      backendSessionIds: [result.backendSessionId],
    );
    try {
      await _useBoundSessionPlugin(
        binding: binding,
        operation: SessionOperation.deleteSession,
        body: (plugin) => plugin.deleteSession(binding.backendSessionId),
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "Failed to delete harness session ${binding.backendSessionId} replaced in session $sessionId; "
        "its tombstone keeps it out of the catalog",
        error,
        stackTrace,
      );
    }
    return result.removedSessionIds;
  }

  /// Asks [sessionId]'s harness a side question with this side chat's
  /// [history]. A harness that does not declare side questions is refused
  /// before its plugin is started.
  Future<SideQuestionAskResult> askSideQuestion({
    required String sessionId,
    required String question,
    required List<PluginSideExchange> history,
  }) async {
    const operation = SessionOperation.askSideQuestion;
    final binding = await _requireBinding(sessionId: sessionId, operation: operation);
    if (!_runtime.supportsSideQuestions(pluginId: binding.pluginId)) {
      return const SideQuestionRefused(reason: SideQuestionRefusal.harnessUnsupported);
    }
    return await _useBoundSessionPlugin(
      binding: binding,
      operation: operation,
      body: (plugin) async {
        if (plugin case final SideQuestionPluginApi api) {
          final answer = await api.askSideQuestion(
            sessionId: binding.backendSessionId,
            question: question,
            history: history,
          );
          return answer.toAskResult();
        }
        throw PluginOperationException(
          operation: operation.name,
          statusCode: 500,
          message: "plugin ${binding.pluginId} declares side questions but does not implement SideQuestionPluginApi",
        );
      },
    );
  }

  /// The prompts accepted for [sessionId] but not yet dispatched to its
  /// backend, in dispatch order, mapped to the shared wire model.
  ///
  /// Deliberately does not start a stopped backend: the queue lives in the
  /// plugin's memory, so a stopped one holds nothing.
  Future<List<QueuedSessionPrompt>> getQueuedPrompts({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getQueuedPrompts,
    );
    final prompts = await _runtime.useIfActive(
      pluginId: binding.pluginId,
      operation: SessionOperation.getQueuedPrompts,
      body: (plugin, _) async =>
          (await plugin.getQueuedPrompts(sessionId: binding.backendSessionId)).toSharedQueuedPrompts(),
    );
    return stampQueuedCommandSources(sessionId: sessionId, prompts: prompts ?? const []);
  }

  /// Cancels the queued prompt [promptId] on [sessionId] before dispatch.
  ///
  /// Returns whether an entry was removed; `false` covers an unknown id, an
  /// already-dispatched prompt, and a stopped backend (whose queue is empty).
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.cancelQueuedPrompt,
    );
    final removed = await _runtime.useIfActive(
      pluginId: binding.pluginId,
      operation: SessionOperation.cancelQueuedPrompt,
      body: (plugin, _) => plugin.cancelQueuedPrompt(
        sessionId: binding.backendSessionId,
        promptId: promptId,
      ),
    );
    return removed ?? false;
  }

  /// The backend's current activity time for [session] in epoch milliseconds,
  /// read without starting its plugin, or null when its harness cannot answer
  /// cheaply or cannot find it.
  Future<int?> readBackendActivity({required StoredSession session}) async {
    final result = await _runtime.readSessionActivity(
      pluginId: session.pluginId,
      sessionId: session.backendSessionId,
      directory: session.directory,
    );
    return switch (result) {
      PluginSessionActivityAvailable(:final updatedAt) => updatedAt,
      PluginSessionActivityUnavailable() => null,
    };
  }

  /// All messages of [sessionId], mapped to the shared model. The stored
  /// directory is primed first: after a bridge restart, the history replay can
  /// be the FIRST plugin call for a stored worktree session, and a
  /// directory-scoped backend would otherwise replay in its launch directory.
  Future<SessionMessagesSnapshot> getSessionMessages({required String sessionId}) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.getSessionMessages,
    body: (plugin, binding) async {
      final pluginMessages = await plugin.getSessionMessages(binding.backendSessionId);
      // History supplies model/agent changes made natively; fast mode is a
      // bridge-owned preference and is not recorded in backend transcripts.
      final historyDefaults = pluginMessages.latestPromptDefaults();
      return (
        messages: await _resolveChildSessionIds(
          pluginId: binding.pluginId,
          messages: pluginMessages.toSharedMessageWithParts(sessionId: binding.sessionId),
        ),
        promptDefaults:
            historyDefaults?.copyWith(fastMode: binding.fastMode) ??
            (binding.lastAgent == null && binding.lastAgentModel == null && !binding.fastMode
                ? null
                : SessionPromptDefaults(
                    agent: binding.lastAgent,
                    model: binding.lastAgentModel,
                    fastMode: binding.fastMode,
                  )),
      );
    },
  );

  AutoContinuationAvailability quotaReportingAvailability({required String pluginId}) =>
      switch (_runtime.quotaReportingSupport(pluginId: pluginId)) {
        PluginQuotaReportingSupport.conditional => AutoContinuationAvailability.conditional,
        PluginQuotaReportingSupport.unavailable => AutoContinuationAvailability.unavailable,
      };

  /// Whether [pluginId] takes image parts inline.
  bool inlineImagesSupported({required String pluginId}) => _runtime.supportsPromptAttachments(pluginId: pluginId);

  /// Whether the plugin bound to [sessionId] takes image parts inline.
  Future<bool> inlineImagesSupportedForSession({required String sessionId}) async {
    final binding = await _requireBinding(sessionId: sessionId, operation: SessionOperation.sendPrompt);
    return inlineImagesSupported(pluginId: binding.pluginId);
  }

  Future<SessionReadiness> getSessionReadiness({required String sessionId}) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.getSessionReadiness,
    body: (plugin, binding) async => switch (await plugin.getSessionReadiness(sessionId: binding.backendSessionId)) {
      PluginSessionReadiness.idle => SessionReadiness.idle,
      PluginSessionReadiness.busy => SessionReadiness.busy,
      PluginSessionReadiness.retrying => SessionReadiness.retrying,
      PluginSessionReadiness.queued => SessionReadiness.queued,
      PluginSessionReadiness.awaitingInput => SessionReadiness.awaitingInput,
      PluginSessionReadiness.unavailable => SessionReadiness.unavailable,
      PluginSessionReadiness.unknown => SessionReadiness.unknown,
    },
  );

  /// Asks [sessionId]'s harness to compact its context. The harness sends
  /// nothing to a session that is working, so this never stops a turn.
  Future<SessionCompactionResult> compactSession({required String sessionId, required String promptId}) =>
      _useSessionPlugin(
        sessionId: sessionId,
        operation: SessionOperation.compactSession,
        body: (plugin, binding) async =>
            switch (await plugin.compactSession(sessionId: binding.backendSessionId, promptId: promptId)) {
              PluginCompactionResult.accepted => SessionCompactionResult.accepted,
              PluginCompactionResult.sessionBusy => SessionCompactionResult.sessionBusy,
              PluginCompactionResult.unsupported => SessionCompactionResult.unsupported,
            },
      );

  /// The sessions [taskId]'s runs started that are neither archived nor
  /// pinned, newest first: the candidates for archiving old runs.
  Future<List<String>> listArchivableScheduledRunSessionIds({required String taskId}) =>
      _sessionDao.listUnarchivedUnpinnedScheduledRunSessionIds(scheduledTaskId: taskId);

  /// Whether [sessionId] is between turns with nothing waiting on the user.
  /// The one owner of that question for scheduled runs.
  ///
  /// The plugin's active-session summary already folds the session's status,
  /// pending questions, permissions and forms, and busy sub-agents together,
  /// as the Running filter uses them. Readiness adds what a harness reports
  /// beyond that, such as a queued prompt or a pending wake-up.
  Future<SessionQuietness> getSessionQuietness({required String sessionId}) async {
    try {
      final binding = await _sessionDao.getSession(sessionId: sessionId);
      if (binding == null) return SessionQuietness.unknown;
      return await _runtime.useIfActive(
            pluginId: binding.pluginId,
            operation: SessionOperation.getSessionQuietness,
            body: (plugin, _) => _readQuietness(plugin: plugin, backendSessionId: binding.backendSessionId),
          ) ??
          // A backend that is not running runs no turn and holds no pending input.
          SessionQuietness.quiet;
    } on Object catch (error, stackTrace) {
      Log.w("Could not read whether session $sessionId is quiet", error, stackTrace);
      return SessionQuietness.unknown;
    }
  }

  Future<SessionQuietness> _readQuietness({required BridgePluginApi plugin, required String backendSessionId}) async {
    for (final summary in plugin.getActiveSessionsSummary()) {
      for (final active in summary.activeSessions) {
        if (active.id == backendSessionId) {
          return active.awaitingInput ? SessionQuietness.awaitingUser : SessionQuietness.working;
        }
      }
    }
    return switch (await plugin.getSessionReadiness(sessionId: backendSessionId)) {
      PluginSessionReadiness.idle || PluginSessionReadiness.unavailable => SessionQuietness.quiet,
      PluginSessionReadiness.busy ||
      PluginSessionReadiness.retrying ||
      PluginSessionReadiness.queued => SessionQuietness.working,
      PluginSessionReadiness.awaitingInput => SessionQuietness.awaitingUser,
      PluginSessionReadiness.unknown => SessionQuietness.unknown,
    };
  }

  /// Translates the backend child references a plugin puts on subtask parts
  /// into bridge session ids.
  ///
  /// Best effort by contract: a child the bridge has not bound yet leaves the
  /// part with a null reference instead of withholding the page, matching the
  /// live path where the reference never gates delivery.
  Future<List<MessageWithParts>> _resolveChildSessionIds({
    required String pluginId,
    required List<MessageWithParts> messages,
  }) async {
    final backendSessionIds = {
      for (final message in messages)
        for (final part in message.parts)
          if (part case MessagePartSubtask(:final childSessionID)) ?childSessionID,
    };
    if (backendSessionIds.isEmpty) return messages;
    final sessionIds = await getSessionIdsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    return [
      for (final message in messages)
        message.copyWith(
          parts: [
            for (final part in message.parts)
              if (part case MessagePartSubtask(childSessionID: final backendSessionId?))
                part.copyWith(childSessionID: sessionIds[backendSessionId])
              else
                part,
          ],
        ),
    ];
  }

  /// Persists the bridge-owned title override. Null removes the override so
  /// later reads fall back to the latest observed catalog title.
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    if (await _sessionDao.getSession(sessionId: sessionId) == null) return false;
    await _sessionDao.setTitle(
      sessionId: sessionId,
      title: title,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      projectionUpdatedAt: captureProjectionTimestamp(),
    );
    return true;
  }

  /// Persists the session's approval override (null follows the bridge YOLO
  /// setting) and returns the updated catalog session, or null when the
  /// session is not stored.
  Future<Session?> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    final stored = await _sessionDao.setApprovalOverride(sessionId: sessionId, approvalOverride: approvalOverride);
    return stored ? await getCatalogSession(sessionId: sessionId) : null;
  }

  /// Pins or unpins the session and returns the updated catalog session, or
  /// null when no row was written: the session is not stored, or a pin
  /// targeted a child or an archived session.
  Future<Session?> setPinned({required String sessionId, required bool pinned}) async {
    final stored = await _sessionDao.setPinned(sessionId: sessionId, pinned: pinned);
    return stored ? await getCatalogSession(sessionId: sessionId) : null;
  }

  /// The override that governs [sessionId]'s permission requests: its own, or
  /// else its nearest ancestor's, so a sub-agent session follows the session
  /// that started it. Null when none is set or the session is not stored.
  Future<SessionApprovalMode?> resolveApprovalOverride({required String sessionId}) async {
    const maxDepth = 256;
    String? currentSessionId = sessionId;
    for (var depth = 0; depth < maxDepth && currentSessionId != null; depth++) {
      final row = await _sessionDao.getSession(sessionId: currentSessionId);
      if (row == null) return null;
      if (row.approvalOverride case final approvalOverride?) return approvalOverride;
      currentSessionId = row.parentSessionId;
    }
    return null;
  }

  Future<bool> hasYoloApprovalOverride() => _sessionDao.hasApprovalOverride(approvalOverride: SessionApprovalMode.yolo);

  Future<Session?> setGeneratedSessionTitleIfAbsent({required String sessionId, required String title}) async {
    final updated = await _sessionDao.setTitleIfNull(
      sessionId: sessionId,
      title: title,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      projectionUpdatedAt: captureProjectionTimestamp(),
    );
    return updated ? await getCatalogSession(sessionId: sessionId) : null;
  }

  Future<bool> isSessionTombstoned({required String sessionId}) async {
    if (_deletedSessionIds.contains(sessionId)) return true;
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) return false;
    await _ensureTombstonesLoaded(pluginId: binding.pluginId);
    return _tombstonesFor(binding.pluginId).contains(binding.backendSessionId);
  }

  Future<List<String>> get persistedSessionCleanupPluginIds async {
    final pluginIds = <String>[];
    for (final pluginId in _runtime.activePluginIds) {
      try {
        final supportsCleanup = await _runtime.useIfActive(
          pluginId: pluginId,
          operation: SessionOperation.cleanupSession,
          body: (plugin, _) async => plugin is PersistedSessionCleanupApi,
        );
        if (supportsCleanup ?? false) pluginIds.add(pluginId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Failed to inspect persisted session cleanup capability "
          "(plugin=$pluginId); retrying next startup",
          error,
          stackTrace,
        );
      }
    }
    pluginIds.sort();
    return List<String>.unmodifiable(pluginIds);
  }

  Future<Set<String>> getTombstonedBackendSessionIdsForCleanup({required String pluginId}) async {
    final tombstones = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: SessionOperation.cleanupSession,
      body: (plugin, _) {
        _requirePersistedSessionCleanupApi(
          pluginId: pluginId,
          plugin: plugin,
        );
        return _sessionDao.getTombstonedSessionIds(pluginId: pluginId);
      },
    );
    if (tombstones == null) {
      throw StateError('Plugin "$pluginId" is not active');
    }
    return tombstones;
  }

  Future<void> deletePersistedSession({
    required String pluginId,
    required String backendSessionId,
  }) {
    return _runtime.use(
      pluginId: pluginId,
      operation: SessionOperation.cleanupSession,
      body: (plugin) => _requirePersistedSessionCleanupApi(
        pluginId: pluginId,
        plugin: plugin,
      ).deletePersistedSession(backendSessionId: backendSessionId),
    );
  }

  Future<void> _ensureTombstonesLoaded({required String pluginId}) async {
    if (_tombstonesLoaded.contains(pluginId)) return;
    final inFlight = _tombstoneLoads[pluginId];
    if (inFlight != null) return await inFlight;

    final load = _loadTombstones(pluginId: pluginId);
    _tombstoneLoads[pluginId] = load;
    try {
      await load;
    } finally {
      if (identical(_tombstoneLoads[pluginId], load)) {
        unawaited(_tombstoneLoads.remove(pluginId));
      }
    }
  }

  Future<void> _loadTombstones({required String pluginId}) async {
    final stored = await _sessionDao.getTombstonedSessionIds(pluginId: pluginId);
    // Merge rather than replace so a deletion committed during the initial
    // read cannot be lost when that read completes.
    _tombstonesFor(pluginId).addAll(stored);
    _tombstonesLoaded.add(pluginId);
  }

  /// Deletes the backend root, then tombstones every persisted binding in its
  /// subtree and removes the stable root atomically.
  ///
  /// Returns the deleted root snapshot plus the exact set of session ids the
  /// deletion removed, so per-session cleanup outside this repository operates
  /// on what was actually deleted rather than on an earlier snapshot.
  Future<DeletedSessionSubtree> deleteSession({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
    );
    final deletionSnapshot = _mapCatalogSessions(rows: [binding]).single;
    // An unreachable backend must not strand the session in the catalog: an
    // uninstalled or unstartable plugin would otherwise leave the user with a
    // row they can never remove. The tombstone below keeps a surviving backend
    // session from being re-imported.
    var backendDeleteAttempted = false;
    try {
      await _useBoundSessionPlugin(
        binding: binding,
        operation: SessionOperation.deleteSession,
        body: (plugin) async {
          backendDeleteAttempted = true;
          try {
            await plugin.deleteSession(binding.backendSessionId);
          } on PluginOperationException catch (error) {
            if (!error.isNotFound) rethrow;
          }
        },
      );
    } on PluginOperationException catch (error, stackTrace) {
      // A backend that answered keeps its existing retry semantics; only never
      // reaching it clears the way for a local-only delete.
      if (backendDeleteAttempted || !error.isUnavailable) rethrow;
      Log.w(
        "Backend ${binding.pluginId} was unreachable while deleting session $sessionId; "
        "removing the bridge record anyway",
        error,
        stackTrace,
      );
    }
    final sessionIds = await _tombstoneSubtree(
      root: binding,
      removeRows: (subtree) async {
        await _sessionDao.deleteSession(sessionId: binding.sessionId);
        return [for (final binding in subtree) binding.sessionId];
      },
    );
    return (session: deletionSnapshot, sessionIds: sessionIds);
  }

  /// Tombstones the harness session of every row in [root]'s subtree, so
  /// catalog import and startup reconciliation never bring one back, and
  /// runs [removeRows] over that subtree in the same transaction. Returns the
  /// session ids [removeRows] removed.
  Future<List<String>> _tombstoneSubtree({
    required SessionDto root,
    required Future<List<String>> Function(List<SessionDto> subtree) removeRows,
  }) async {
    final (:subtree, :removedSessionIds) = await _sessionDao.transaction(() async {
      final subtree = await _getSessionSubtree(root: root);
      final deletedAt = DateTime.now().millisecondsSinceEpoch;
      for (final binding in subtree) {
        await _sessionDao.insertSessionTombstone(
          backendSessionId: binding.backendSessionId,
          pluginId: binding.pluginId,
          deletedAt: deletedAt,
        );
      }
      return (subtree: subtree, removedSessionIds: await removeRows(subtree));
    });
    _deletedSessionIds.addAll(removedSessionIds);
    for (final binding in subtree) {
      _tombstonesFor(binding.pluginId).add(binding.backendSessionId);
    }
    removedSessionIds.forEach(_busyObservations.remove);
    return removedSessionIds;
  }

  Future<List<SessionDto>> _getSessionSubtree({required SessionDto root}) async {
    final result = <SessionDto>[root];
    final seen = <String>{root.sessionId};
    var parentIds = <String>[root.sessionId];
    while (parentIds.isNotEmpty) {
      final children = await _sessionDao.getSessionsByParentIds(parentSessionIds: parentIds);
      final unseenChildren = [
        for (final child in children)
          if (seen.add(child.sessionId)) child,
      ];
      result.addAll(unseenChildren);
      parentIds = [for (final child in unseenChildren) child.sessionId];
    }
    return result;
  }

  /// Feeds a derived plugin the bridge's stored session→directory attribution
  /// (the dedicated worktree path, else the owning project directory — which
  /// for derived plugins IS the canonical path) before an operation that
  /// carries only a session id. No-op for native plugins and rowless sessions.
  void _primeDerivedSessionDirectory({required SessionDto binding, required BridgePluginApi plugin}) {
    if (plugin is BridgeDerivedProjectsPluginApi) {
      plugin.primeSessionDirectory(
        sessionId: binding.backendSessionId,
        directory: binding.directory,
      );
    }
  }

  /// The plugin's live activity summary with the bridge's session→project
  /// attribution applied. A derived plugin reports each active session under
  /// its own cwd — a dedicated worktree path for worktree sessions — while the
  /// project list folds that session under the stored *parent* project row, so
  /// without this remap the activity badge lands on a project id the phone
  /// doesn't show. A native plugin owns its own attribution and passes
  /// through 1:1.
  ///
  /// Archived sessions are left out unless [includeArchived]: no client shows
  /// their activity, but an archived root's row can still carry an active
  /// sub-agent's pending input.
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries({bool includeArchived = false}) async {
    final results = await Future.wait(
      _runtime.activePluginIds.map((pluginId) async {
        try {
          final sourcedObservation = await _runtime.useIfActive(
            pluginId: pluginId,
            operation: SessionOperation.getProjectActivitySummaries,
            body: (plugin, generation) async => (
              generation: generation,
              observation: await _collectPluginProjectActivity(
                pluginId: pluginId,
                plugin: plugin,
              ).timeout(_aggregateSourceDeadline),
            ),
          );
          if (sourcedObservation == null) return const <ProjectActivitySummary>[];
          final (:generation, :observation) = sourcedObservation;
          _runtime.requireCurrentGeneration(
            pluginId: pluginId,
            generation: generation,
            operation: SessionOperation.getProjectActivitySummaries,
          );
          await _runtime.commitCurrentGeneration(
            pluginId: pluginId,
            generation: generation,
            operation: SessionOperation.getProjectActivitySummaries,
            commit: () => _persistActiveRootHydrations(
              observation: observation,
              generation: generation,
            ),
          );
          return await _mapPluginProjectActivitySummaries(
            observation: observation,
            includeArchived: includeArchived,
          );
        } on Object catch (error, stackTrace) {
          Log.w("Could not read activity summaries from plugin $pluginId", error, stackTrace);
          return const <ProjectActivitySummary>[];
        }
      }),
    );
    final byProject = <String, List<ActiveSession>>{};
    for (final summaries in results) {
      for (final summary in summaries) {
        (byProject[summary.id] ??= <ActiveSession>[]).addAll(summary.activeSessions);
      }
    }
    return [
      for (final entry in byProject.entries) ProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  /// Whether [sessionId] is running by the rule the Running filter and the
  /// apps apply. Only active root sessions can be; an archived one never is.
  Future<bool> isSessionRunning({required String sessionId}) async {
    for (final summary in await getProjectActivitySummaries()) {
      for (final active in summary.activeSessions) {
        if (active.id == sessionId) return _runningCalculator.isRunning(session: active);
      }
    }
    return false;
  }

  Future<_PluginActivityObservation> _collectPluginProjectActivity({
    required String pluginId,
    required BridgePluginApi plugin,
  }) async {
    await _ensureTombstonesLoaded(pluginId: pluginId);
    final tombstones = _tombstonesFor(pluginId);
    final summaries = [
      for (final summary in plugin.getActiveSessionsSummary())
        if (summary.activeSessions.any((active) => !tombstones.contains(active.id)))
          summary.copyWith(
            activeSessions: [
              for (final active in summary.activeSessions)
                if (!tombstones.contains(active.id)) active,
            ],
          ),
    ];
    final backendSessionIds = <String>{
      for (final summary in summaries)
        for (final active in summary.activeSessions) ...{
          active.id,
          ...active.childSessionIds,
        },
    };
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    final missingRootIds = {
      for (final summary in summaries)
        for (final active in summary.activeSessions)
          if (!bindings.containsKey(active.id)) active.id,
    };
    final hydrations = missingRootIds.isNotEmpty && plugin is NativeProjectsPluginApi
        ? await _collectActiveRootHydrations(
            pluginId: pluginId,
            plugin: plugin,
            summaries: summaries,
            missingRootIds: missingRootIds,
          )
        : const <_ActiveRootHydration>[];
    return _PluginActivityObservation(
      pluginId: pluginId,
      summaries: summaries,
      backendSessionIds: backendSessionIds,
      hydrations: hydrations,
    );
  }

  Future<List<ProjectActivitySummary>> _mapPluginProjectActivitySummaries({
    required _PluginActivityObservation observation,
    required bool includeArchived,
  }) async {
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: observation.pluginId,
      backendSessionIds: observation.backendSessionIds.toList(growable: false),
    );
    // Archive state is local: a backend can still report an archived session
    // running, or waiting on a request it can never get an answer to.
    bool isListed(SessionDto binding) => includeArchived || binding.archivedAt == null;

    ActiveSession? mapActiveSession(PluginActiveSession active) {
      final binding = bindings[active.id];
      if (binding == null || !isListed(binding)) return null;
      return active.toSharedActiveSession(
        sessionId: binding.sessionId,
        childSessionIds: [
          for (final backendChildId in active.childSessionIds)
            if (bindings[backendChildId] case final child? when isListed(child)) child.sessionId,
        ],
        lastUserActivityAt: binding.lastUserMessageAt,
        updatedAt: binding.updatedAt,
      );
    }

    final byProject = <String, List<ActiveSession>>{};
    for (final summary in observation.summaries) {
      for (final active in summary.activeSessions) {
        final binding = bindings[active.id];
        final mapped = mapActiveSession(active);
        if (binding == null || mapped == null) continue;
        (byProject[binding.projectId] ??= <ActiveSession>[]).add(mapped);
      }
    }
    return [
      for (final entry in byProject.entries) ProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  Future<List<_ActiveRootHydration>> _collectActiveRootHydrations({
    required String pluginId,
    required NativeProjectsPluginApi plugin,
    required List<PluginProjectActivitySummary> summaries,
    required Set<String> missingRootIds,
  }) async {
    // A native project API can resolve an activity-summary directory to both
    // stable project identity and live path. Derived plugins cannot safely do
    // that for an unknown worktree, so their rowless activity stays omitted.
    final hydrations = <_ActiveRootHydration>[];
    final hydratedProjectIds = <String>{};
    final storedProjects = await _projectsDao.getAllProjects();
    final projectsById = <String, ProjectDto>{
      for (final project in storedProjects) project.projectId: project,
    };
    final projectsByNormalizedPath = _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
      projects: storedProjects,
    );
    for (final summary in summaries) {
      if (!summary.activeSessions.any((active) => missingRootIds.contains(active.id))) continue;

      try {
        final project = await plugin.getProject(summary.id);
        final existing = _projectCatalogIdentityCalculator.calculate(
          projectsById: projectsById,
          projectsByNormalizedPath: projectsByNormalizedPath,
          preferredProjectId: project.id,
          observedPath: project.directory,
        );
        final hydratedProject = existing ?? _projectPlaceholder(projectId: project.id, path: project.directory);
        if (hydratedProjectIds.contains(hydratedProject.projectId)) continue;
        final sessions = await plugin.getSessions(projectId: project.directory);
        hydratedProjectIds.add(hydratedProject.projectId);
        hydrations.add(
          _ActiveRootHydration(
            summaryId: summary.id,
            preferredProjectId: project.id,
            projectDirectory: project.directory,
            sessions: sessions,
          ),
        );
        projectsById[hydratedProject.projectId] = hydratedProject;
        projectsByNormalizedPath
          ..clear()
          ..addAll(
            _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
              projects: projectsById.values,
            ),
          );
      } on Object catch (error, stackTrace) {
        Log.w(
          "Could not hydrate active project ${summary.id}; omitting unresolved sessions",
          error,
          stackTrace,
        );
      }
    }
    return hydrations;
  }

  Future<void> _persistActiveRootHydrations({
    required _PluginActivityObservation observation,
    required int generation,
  }) async {
    for (final hydration in observation.hydrations) {
      try {
        await _persistNativeRootSessions(
          pluginId: observation.pluginId,
          generation: generation,
          preferredProjectId: hydration.preferredProjectId,
          projectDirectory: hydration.projectDirectory,
          pluginSessions: hydration.sessions,
        );
      } on Object catch (error, stackTrace) {
        Log.w(
          "Could not hydrate active project ${hydration.summaryId}; omitting unresolved sessions",
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _persistNativeRootSessions({
    required String pluginId,
    required int generation,
    required String preferredProjectId,
    required String projectDirectory,
    required List<PluginSession> pluginSessions,
  }) async {
    final projectionUpdatedAt = captureProjectionTimestamp();
    final backendSessionIds = [for (final session in pluginSessions) session.id];
    final inScratch = _projectCatalogIdentityCalculator.isWithinScratch(path: projectDirectory);
    final result = await _sessionDao.attachedDatabase.transaction(() async {
      final storedProjects = await _projectsDao.getAllProjects();
      final projectsById = {
        for (final project in storedProjects) project.projectId: project,
      };
      final ProjectDto hydratedProject;
      if (inScratch) {
        // A scratch folder never becomes a project: its sessions bind to the
        // "No project" row, and without that row they stay unbound.
        final scratchProject = projectsById[_projectCatalogIdentityCalculator.scratchRoot];
        if (scratchProject == null) return null;
        hydratedProject = scratchProject;
      } else {
        hydratedProject =
            _projectCatalogIdentityCalculator.calculate(
              projectsById: projectsById,
              projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
                projects: storedProjects,
              ),
              preferredProjectId: preferredProjectId,
              observedPath: projectDirectory,
            ) ??
            _projectPlaceholder(projectId: preferredProjectId, path: projectDirectory);
        await _projectsDao.insertProjectIfMissing(
          projectId: hydratedProject.projectId,
          path: projectDirectory,
          hidden: false,
          displayName: null,
        );
      }
      final existingByBackendId = await _sessionDao.getSessionsByBackendIds(
        pluginId: pluginId,
        backendSessionIds: backendSessionIds,
      );
      final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: pluginId);
      final allocatedSessionIds = await _allocateSessionIds(
        count: pluginSessions
            .where((session) => !tombstoned.contains(session.id) && existingByBackendId[session.id] == null)
            .length,
      );
      var allocatedIndex = 0;
      final observedRoots = <ObservedRootSession>[];
      for (final session in pluginSessions) {
        if (tombstoned.contains(session.id)) continue;
        final existingBinding = existingByBackendId[session.id];
        observedRoots.add((
          sessionId: existingBinding?.sessionId ?? allocatedSessionIds[allocatedIndex++],
          backendSessionId: session.id,
          projectId: hydratedProject.projectId,
          directory: session.directory,
          catalogTitle: session.title,
          createdAt: session.time?.created ?? existingBinding?.createdAt ?? projectionUpdatedAt,
          updatedAt: max(
            session.time?.updated ?? existingBinding?.updatedAt ?? projectionUpdatedAt,
            existingBinding?.updatedAt ?? 0,
          ),
          archivedAt: session.time?.archived,
          projectionUpdatedAt: projectionUpdatedAt,
        ));
      }
      final committedByBackendId = await _sessionDao.upsertObservedRootSessions(
        pluginId: pluginId,
        sessions: observedRoots,
      );
      return (project: hydratedProject, committedByBackendId: committedByBackendId);
    });
    if (result == null) return;
    _publishBindingsCommitted(
      pluginId: pluginId,
      projectId: result.project.projectId,
      generation: generation,
      kind: SessionBindingCommitKind.catalogSync,
      backendSessionIds: result.committedByBackendId.keys.toList(growable: false),
    );
  }

  ({String providerID, String modelID})? _toPluginModel(PromptModel? model) => switch (model) {
    PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
    null => null,
  };

  PluginSessionVariant? _toPluginVariant(SessionVariant? variant) {
    return switch (variant) {
      SessionVariant(:final id) => PluginSessionVariant(id: id),
      null => null,
    };
  }

  /// The plugin and project that own [sessionId], which together scope its
  /// session options cache. `null` when the session has no stored row.
  Future<({String pluginId, String projectId})?> findSessionOptionsScope({required String sessionId}) async {
    final session = await _sessionDao.getSession(sessionId: sessionId);
    if (session == null) return null;
    return (pluginId: session.pluginId, projectId: session.projectId);
  }

  Future<void> notifySessionArchived({required String sessionId}) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.archiveSession,
    body: (plugin, binding) => plugin.archiveSession(sessionId: binding.backendSessionId),
  );

  Future<SessionAbortResult> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
    required bool useAtomicStop,
  }) => _useSessionPlugin(
    sessionId: sessionId,
    operation: SessionOperation.abortSession,
    body: (plugin, binding) async {
      final knownSubAgentSessionIds = {
        for (final descendant in (await _getSessionSubtree(root: binding)).skip(1))
          if (descendant.pluginId == binding.pluginId) descendant.backendSessionId,
      };
      return switch (await plugin.abortSession(
        sessionId: binding.backendSessionId,
        subAgents: subAgents.toPlugin(),
        useAtomicStop: useAtomicStop,
        knownSubAgentSessionIds: knownSubAgentSessionIds,
      )) {
        PluginAbortAccepted(:final workKept, :final subAgentsHandled) => SessionAborted(
          workKept: workKept,
          subAgentsHandled: subAgentsHandled,
        ),
        final PluginAbortRejectedSubAgentsRunning rejected => SessionAbortRejected(rejection: rejected.toShared()),
        PluginAbortNotPerformed(:final reason) => SessionAbortNotPerformed(
          refusal: SessionAbortNotPerformedRefusal(reason: reason.toShared()),
        ),
      };
    },
  );

  /// Whether [pluginId]'s backend is running, so a missing status from it
  /// means its status read failed rather than that it has no turn.
  bool isPluginActive({required String pluginId}) => _runtime.activePluginIds.contains(pluginId);

  Future<SessionStatusResponse> getSessionStatuses() async {
    final results = await Future.wait(
      _runtime.eligiblePluginIds.map((pluginId) async {
        try {
          final pluginStatuses = await _readPluginSessionStatuses(pluginId: pluginId);
          return (
            pluginId: pluginId,
            statuses: pluginStatuses == null
                ? null
                : {
                    for (final MapEntry(key: sessionId, value: status) in pluginStatuses.entries)
                      sessionId: _stampSnapshotStatus(sessionId: sessionId, status: status),
                  },
          );
        } on Object catch (error, stackTrace) {
          Log.w("Could not read session statuses from plugin $pluginId", error, stackTrace);
          return (pluginId: pluginId, statuses: null);
        }
      }),
    );
    return SessionStatusResponse(
      statuses: {
        for (final result in results) ...?result.statuses,
      },
      unavailablePluginIds: [
        for (final result in results)
          if (result.statuses == null) result.pluginId,
      ],
    );
  }

  /// [pluginId]'s session statuses keyed by bridge session id, as its plugin
  /// reports them. A plugin that is not running yet is started for a
  /// short-lived generation, since only it can say whether a turn is still
  /// running. Throws when the plugin cannot start or the read fails.
  Future<Map<String, SessionStatus>> getPluginSessionStatuses({required String pluginId}) async {
    final (:value, generation: _) = await _runtime.useWithGeneration(
      pluginId: pluginId,
      operation: SessionOperation.getSessionStatuses,
      residency: PluginGenerationResidency.transient,
      body: (plugin) => plugin.getSessionStatuses().timeout(_aggregateSourceDeadline),
    );
    return await _toBridgeStatuses(pluginId: pluginId, pluginStatuses: value);
  }

  /// Null when [pluginId] is not active.
  Future<Map<String, SessionStatus>?> _readPluginSessionStatuses({required String pluginId}) async {
    final pluginStatuses = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: SessionOperation.getSessionStatuses,
      body: (plugin, _) => plugin.getSessionStatuses().timeout(_aggregateSourceDeadline),
    );
    if (pluginStatuses == null) return null;
    return await _toBridgeStatuses(pluginId: pluginId, pluginStatuses: pluginStatuses);
  }

  Future<Map<String, SessionStatus>> _toBridgeStatuses({
    required String pluginId,
    required Map<String, PluginSessionStatus> pluginStatuses,
  }) async {
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: pluginStatuses.keys.toList(growable: false),
    );
    return {
      for (final entry in pluginStatuses.entries)
        if (bindings[entry.key] case final binding?) binding.sessionId: entry.value.toSharedSessionStatus(),
    };
  }

  /// [status] as a client receives it live: a busy or retry status carries when
  /// the bridge saw [sessionId] go busy, the same time for the whole busy run.
  ///
  /// Only a busy run that starts after an idle seen live or in the status
  /// snapshot has a known start; a session first seen busy, as after a bridge
  /// restart, stays without one until it next goes idle.
  SessionStatus stampLiveStatus({required String sessionId, required SessionStatus status}) {
    if (status is SessionStatusIdle) {
      markSessionIdle(sessionId: sessionId);
      return status;
    }
    final int? since;
    switch (_busyObservations[sessionId]) {
      case _BusySince(since: final stamped):
        since = stamped;
      case _ObservedNotBusy():
        final now = clock.now().millisecondsSinceEpoch;
        _busyObservations[sessionId] = _BusySince(since: now);
        since = now;
      case null:
        since = null;
    }
    return _withBusySince(status: status, since: since);
  }

  /// Records that [sessionId] went idle, so its next busy run is timed.
  void markSessionIdle({required String sessionId}) {
    _busyObservations[sessionId] = const _ObservedNotBusy();
  }

  /// [status] as a plugin snapshot reports it. A busy or retry status carries
  /// the tracked start but never creates one, since the run began at an unknown
  /// time; an idle counts as seen idle unless a live status is already tracked.
  SessionStatus _stampSnapshotStatus({required String sessionId, required SessionStatus status}) {
    if (status is SessionStatusIdle) {
      _busyObservations.putIfAbsent(sessionId, () => const _ObservedNotBusy());
      return status;
    }
    return _withBusySince(
      status: status,
      since: switch (_busyObservations[sessionId]) {
        _BusySince(:final since) => since,
        _ObservedNotBusy() || null => null,
      },
    );
  }

  static SessionStatus _withBusySince({required SessionStatus status, required int? since}) => switch (status) {
    SessionStatusIdle() => status,
    final SessionStatusBusy busy => busy.copyWith(since: since),
    final SessionStatusRetry retry => retry.copyWith(since: since),
  };

  /// The single session's live status, or null when it cannot be observed —
  /// the session has no binding, its plugin is not active, or the plugin read
  /// failed. The caller owns the policy for that uncertainty.
  Future<SessionStatus?> getSessionStatus({required String sessionId}) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) return null;
    try {
      final pluginStatuses = await _runtime.useIfActive(
        pluginId: binding.pluginId,
        operation: SessionOperation.getSessionStatuses,
        body: (plugin, _) => plugin.getSessionStatuses().timeout(_aggregateSourceDeadline),
      );
      return pluginStatuses?[binding.backendSessionId]?.toSharedSessionStatus();
    } on Object catch (error, stackTrace) {
      Log.w("Could not read the status of session $sessionId from plugin ${binding.pluginId}", error, stackTrace);
      return null;
    }
  }

  List<Session> _mapCatalogSessions({required List<SessionDto> rows}) {
    return [
      for (final row in rows)
        _sessionCatalogMapper.map(
          row: row,
          unseen: _unseenCalculator.isUnseen(
            activity: row.lastActivityAt,
            userMessage: row.lastUserMessageAt,
            seen: row.lastSeenAt,
          ),
        ),
    ];
  }

  Future<List<Session>> getChildSessions({required String sessionId}) async {
    if (await _sessionDao.getSession(sessionId: sessionId) == null) {
      throw PluginOperationException.notFound(
        operation: SessionOperation.getChildSessions.name,
        message: "session $sessionId was not found",
      );
    }
    return _mapCatalogSessions(
      rows: await _sessionDao.getChildCatalogSessions(parentSessionId: sessionId),
    );
  }

  /// The session and every descendant it would take with it on deletion.
  ///
  /// Empty when no such session is stored, so callers preparing per-session
  /// cleanup do not have to distinguish "gone already" from "no children".
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async {
    final root = await _sessionDao.getSession(sessionId: sessionId);
    if (root == null) return const [];
    final subtree = await _getSessionSubtree(root: root);
    return [for (final binding in subtree) binding.sessionId];
  }

  /// The subset of [sessionIds] that still has a stored session row. Archived
  /// sessions keep their row, so absence means the session is really gone.
  Future<Set<String>> getExistingSessionIds({required Set<String> sessionIds}) =>
      _readSessionIds(sessionIds: sessionIds, include: (_) => true);

  Future<Set<String>> getStoredSessionIdsForPlugin({required String pluginId}) {
    return _sessionDao.getSessionIdsForPlugin(pluginId: pluginId);
  }

  /// The subset of [sessionIds] the catalog reports as archived.
  ///
  /// Distinguishes "the archive completed" from "an export ran but the archive
  /// never finished", which look identical from the filesystem alone.
  Future<Set<String>> getArchivedSessionIds({required Set<String> sessionIds}) =>
      _readSessionIds(sessionIds: sessionIds, include: (row) => row.archivedAt != null);

  Future<Set<String>> _readSessionIds({
    required Set<String> sessionIds,
    required bool Function(SessionDto row) include,
  }) async {
    if (sessionIds.isEmpty) return const {};
    const chunkSize = 500;
    final ordered = sessionIds.toList(growable: false);
    final selected = <String>{};
    for (var start = 0; start < ordered.length; start += chunkSize) {
      final end = min(start + chunkSize, ordered.length);
      final rows = await _sessionDao.getSessionsByIds(sessionIds: ordered.sublist(start, end));
      selected.addAll(rows.entries.where((entry) => include(entry.value)).map((entry) => entry.key));
    }
    return selected;
  }

  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String worktreePath,
  }) async {
    final sessions = await _sessionDao.getOtherActiveSessionsSharing(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
    );
    return sessions.isNotEmpty;
  }

  /// The project's recorded live directory, suitable as a git/CLI working
  /// directory. Unknown ids are rejected: an id is not a directory.
  Future<String> resolveProjectDirectory({required String projectId}) async {
    final path = await _projectsDao.getResolvedPath(projectId: projectId);
    if (path == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    return path;
  }

  Future<String?> getProjectPath({required String projectId}) async {
    return await _projectsDao.getResolvedPath(projectId: projectId);
  }

  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
  }

  /// The catalog title shown for [sessionId]: the bridge-owned copy when
  /// present, otherwise the backend copy. Null when the session has no title
  /// yet or is not stored.
  Future<String?> getSessionTitle({required String sessionId}) async {
    final row = await _sessionDao.getSession(sessionId: sessionId);
    return row?.title ?? row?.catalogTitle;
  }

  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async {
    return (await _sessionDao.getSessionByBinding(
      pluginId: pluginId,
      backendSessionId: backendSessionId,
    ))?.toStoredSession();
  }

  /// Stable session ids for [backendSessionIds] of [pluginId], keyed by backend
  /// id. A backend id the bridge has not bound is absent.
  Future<Map<String, String>> getSessionIdsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) {
    return _sessionDao.getSessionIdsByBackendIds(pluginId: pluginId, backendSessionIds: backendSessionIds);
  }

  /// Records the end of live work without changing backend projection metadata
  /// or the independent unseen/user-message markers.
  Future<Session?> recordSessionCompletion({
    required String sessionId,
    required String pluginId,
    required int generation,
    required int completedAt,
  }) => _runtime.commitCurrentGeneration(
    pluginId: pluginId,
    generation: generation,
    operation: SessionOperation.recordSessionCompletion,
    commit: () async {
      await _sessionDao.advanceUpdatedAt(sessionId: sessionId, updatedAt: completedAt);
      return await getCatalogSession(sessionId: sessionId);
    },
  );

  Future<StoredSession?> updateObservedSessionProjection({
    required String pluginId,
    required int generation,
    required Session observed,
    required bool updateCatalogTitle,
    required int projectionUpdatedAt,
  }) async {
    return await _runtime.commitCurrentGeneration(
      pluginId: pluginId,
      generation: generation,
      operation: SessionOperation.updateObservedSessionProjection,
      commit: () => _sessionDao.attachedDatabase.transaction(() async {
        if (await _sessionDao.isSessionTombstoned(
          backendSessionId: observed.id,
          pluginId: pluginId,
        )) {
          return null;
        }
        final binding = await _sessionDao.getSessionByBinding(
          pluginId: pluginId,
          backendSessionId: observed.id,
        );
        if (binding == null) return null;
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.updateObservedSessionProjection,
        );
        final updated = await _sessionDao.updateObservedSessionProjection(
          sessionId: binding.sessionId,
          directory: observed.directory,
          catalogTitle: observed.title,
          updateCatalogTitle: updateCatalogTitle,
          updatedAt: max(observed.time?.updated ?? binding.updatedAt, binding.updatedAt),
          projectionUpdatedAt: projectionUpdatedAt,
        );
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.updateObservedSessionProjection,
        );
        if (!updated) return null;
        final stored = (await _sessionDao.getSession(sessionId: binding.sessionId))?.toStoredSession();
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.updateObservedSessionProjection,
        );
        return stored;
      }),
    );
  }

  Future<StoredSession?> insertObservedChild({
    required String pluginId,
    required int generation,
    required Session observed,
    required StoredSession parent,
    required int projectionUpdatedAt,
  }) async {
    return await _runtime.commitCurrentGeneration(
      pluginId: pluginId,
      generation: generation,
      operation: SessionOperation.insertObservedChild,
      commit: () => _sessionDao.attachedDatabase.transaction(() async {
        if (parent.pluginId != pluginId ||
            await _sessionDao.isSessionTombstoned(
              backendSessionId: observed.id,
              pluginId: pluginId,
            )) {
          return null;
        }
        final durableParent = await _sessionDao.getSession(sessionId: parent.id);
        if (durableParent == null || durableParent.pluginId != pluginId) return null;
        final existing = await _sessionDao.getSessionByBinding(
          pluginId: pluginId,
          backendSessionId: observed.id,
        );
        if (existing != null) {
          if (existing.parentSessionId != durableParent.sessionId) return null;
          _runtime.requireCurrentGeneration(
            pluginId: pluginId,
            generation: generation,
            operation: SessionOperation.insertObservedChild,
          );
          final updated = await _sessionDao.updateObservedSessionProjection(
            sessionId: existing.sessionId,
            directory: observed.directory,
            catalogTitle: observed.title,
            updateCatalogTitle: observed.title != null,
            updatedAt: max(observed.time?.updated ?? existing.updatedAt, existing.updatedAt),
            projectionUpdatedAt: projectionUpdatedAt,
          );
          _runtime.requireCurrentGeneration(
            pluginId: pluginId,
            generation: generation,
            operation: SessionOperation.insertObservedChild,
          );
          if (!updated) return null;
          final stored = (await _sessionDao.getSession(sessionId: existing.sessionId))?.toStoredSession();
          _runtime.requireCurrentGeneration(
            pluginId: pluginId,
            generation: generation,
            operation: SessionOperation.insertObservedChild,
          );
          return stored;
        }
        final sessionId = await reserveSessionId();
        final createdAt = observed.time?.created ?? projectionUpdatedAt;
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.insertObservedChild,
        );
        await _sessionDao.insertObservedChild(
          sessionId: sessionId,
          backendSessionId: observed.id,
          projectId: durableParent.projectId,
          parentSessionId: durableParent.sessionId,
          directory: observed.directory,
          catalogTitle: observed.title,
          archivedAt: observed.time?.archived,
          createdAt: createdAt,
          updatedAt: observed.time?.updated ?? createdAt,
          projectionUpdatedAt: projectionUpdatedAt,
          pluginId: pluginId,
        );
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.insertObservedChild,
        );
        final stored = (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
        _runtime.requireCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
          operation: SessionOperation.insertObservedChild,
        );
        return stored;
      }),
    );
  }

  /// Session identity for bridge-owned work that does not need the backend, so
  /// it stays available when the plugin cannot start.
  Future<StoredSession> requireStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    return (await _requireBinding(sessionId: sessionId, operation: operation)).toStoredSession();
  }

  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _requireBinding(sessionId: sessionId, operation: operation);
    return await _runtime.use(
      pluginId: binding.pluginId,
      operation: operation,
      body: (_) async => binding.toStoredSession(),
    );
  }

  Future<Session?> getCatalogSession({required String sessionId}) async {
    final row = await _sessionDao.getSession(sessionId: sessionId);
    if (row == null) return null;
    return _mapCatalogSessions(rows: [row]).single;
  }

  Future<void> archiveStoredSession({
    required String sessionId,
    required int archivedAt,
  }) {
    return _sessionDao.setArchived(
      sessionId: sessionId,
      archivedAt: archivedAt,
      updatedAt: archivedAt,
      projectionUpdatedAt: captureProjectionTimestamp(),
    );
  }

  /// Records the agent and model the backend reports for [sessionId] and
  /// returns the stored prompt defaults, or null when the session has no row.
  ///
  /// Leaves the stored fast mode untouched: only client requests choose it
  /// (see [updateRequestedPromptDefaults]). The returned value carries it, so
  /// callers never publish a backend report without it.
  Future<SessionPromptDefaults?> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {
    final row = await _sessionDao.updatePromptDefaults(
      sessionId: sessionId,
      agent: agent,
      agentModel: agentModel,
    );
    return row == null
        ? null
        : SessionPromptDefaults(agent: row.lastAgent, model: row.lastAgentModel, fastMode: row.fastMode);
  }

  /// Records the selection a client prompt or command ran with, including
  /// its fast-mode choice.
  Future<void> updateRequestedPromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
    required bool fastMode,
  }) {
    return _sessionDao.updateRequestedPromptDefaults(
      sessionId: sessionId,
      agent: agent,
      agentModel: agentModel,
      fastMode: fastMode,
    );
  }

  /// Whether [pluginId] is a registered harness the user has not disabled. It
  /// may still be starting or need setup.
  bool isPluginEligible({required String pluginId}) => _runtime.eligiblePluginIds.contains(pluginId);

  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) {
    return _runtime.use(
      pluginId: pluginId,
      operation: operation,
      body: (_) async {},
    );
  }

  Future<T> _useSessionPlugin<T>({
    required String sessionId,
    required SessionOperation operation,
    required Future<T> Function(BridgePluginApi plugin, SessionDto binding) body,
  }) async {
    final binding = await _requireBinding(sessionId: sessionId, operation: operation);
    return await _useBoundSessionPlugin(
      binding: binding,
      operation: operation,
      body: (plugin) => body(plugin, binding),
    );
  }

  Future<T> _useBoundSessionPlugin<T>({
    required SessionDto binding,
    required SessionOperation operation,
    required Future<T> Function(BridgePluginApi plugin) body,
  }) {
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: operation,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return body(plugin);
      },
    );
  }

  Future<SessionDto> _requireBinding({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) {
      throw PluginOperationException.notFound(
        operation: operation.name,
        message: "session $sessionId was not found",
      );
    }
    return binding;
  }

  static final Random _secureRandom = Random.secure();

  int captureProjectionTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamp = max(now, _lastProjectionTimestamp + 1);
    _lastProjectionTimestamp = timestamp;
    return timestamp;
  }

  Future<void> dispose() => _bindingCommitsController.close();

  void _publishBindingsCommitted({
    required String pluginId,
    required String projectId,
    required int generation,
    required SessionBindingCommitKind kind,
    required List<String> backendSessionIds,
  }) {
    if (backendSessionIds.isEmpty || _bindingCommitsController.isClosed) return;
    _bindingCommitsController.add((
      pluginId: pluginId,
      projectId: projectId,
      generation: generation,
      kind: kind,
      backendSessionIds: List<String>.unmodifiable(backendSessionIds),
    ));
  }

  Set<String> _tombstonesFor(String pluginId) {
    return _tombstonedBackendSessionIds.putIfAbsent(pluginId, () => <String>{});
  }

  SessionRewindPluginApi _requireSessionRewindApi({required BridgePluginApi plugin}) {
    if (plugin case final SessionRewindPluginApi rewindApi) return rewindApi;
    throw PluginBranchPointUnavailableException(
      operation: SessionOperation.rewindSession.name,
      userFacingReason: null,
      cause: null,
    );
  }

  SessionForkPluginApi _requireSessionForkApi({required BridgePluginApi plugin}) {
    if (plugin case final SessionForkPluginApi forkApi) return forkApi;
    throw PluginBranchPointUnavailableException(
      operation: SessionOperation.forkSession.name,
      userFacingReason: null,
      cause: null,
    );
  }

  PersistedSessionCleanupApi _requirePersistedSessionCleanupApi({
    required String pluginId,
    required BridgePluginApi? plugin,
  }) {
    if (plugin case final PersistedSessionCleanupApi cleanupApi) return cleanupApi;
    throw StateError('Plugin "$pluginId" does not support persisted session cleanup');
  }

  ProjectDto _projectPlaceholder({
    required String projectId,
    required String path,
  }) => ProjectDto(
    projectId: projectId,
    path: path,
    createdAt: 0,
    updatedAt: 0,
    projectionUpdatedAt: 0,
    baseBranch: null,
    displayName: null,
  );

  Future<List<String>> _allocateSessionIds({required int count}) async {
    final allocated = <String>[];
    final reserved = <String>{};
    while (allocated.length < count) {
      final candidates = <String>{};
      while (candidates.length < count - allocated.length) {
        final candidate = generateRandomHexId(
          secureRandom: _secureRandom,
          prefix: "ses_",
          byteLength: 16,
        );
        if (reserved.add(candidate)) candidates.add(candidate);
      }
      final occupied = await _sessionDao.getSessionsByIds(
        sessionIds: candidates.toList(growable: false),
      );
      allocated.addAll(candidates.where((candidate) => !occupied.containsKey(candidate)));
    }
    return allocated;
  }

  /// Draws a random `ses_` id that no stored session uses. It needs no
  /// transaction: 128 random bits make a collision with a concurrent
  /// reservation negligible.
  Future<String> reserveSessionId() async {
    while (true) {
      final candidate = generateRandomHexId(
        secureRandom: _secureRandom,
        prefix: "ses_",
        byteLength: 16,
      );
      if (await _sessionDao.getSession(sessionId: candidate) == null) return candidate;
    }
  }
}

class const _PluginActivityObservation({
  required final String pluginId,
  required final List<PluginProjectActivitySummary> summaries,
  required final Set<String> backendSessionIds,
  required final List<_ActiveRootHydration> hydrations,
});

/// What the bridge saw of a session's busy runs in this process.
sealed class const _BusyObservation();

/// The session was seen not busy, so its next busy run starts when seen.
final class const _ObservedNotBusy() extends _BusyObservation;

/// The session went busy at [since], in epoch ms, after being seen not busy.
final class const _BusySince({required final int since}) extends _BusyObservation;

class const _ActiveRootHydration({
  required final String summaryId,
  required final String preferredProjectId,
  required final String projectDirectory,
  required final List<PluginSession> sessions,
});
