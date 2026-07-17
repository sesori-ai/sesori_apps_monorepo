import "dart:async";
import "dart:math";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PluginActiveSession,
        PluginOperationException,
        PluginProjectActivitySummary,
        PluginSession,
        PluginSessionVariant;
import "package:sesori_shared/sesori_shared.dart"
    show
        ActiveSession,
        AgentModel,
        CommandListResponse,
        MessageWithParts,
        PrState,
        ProjectActivitySummary,
        PromptModel,
        PromptPart,
        PullRequestInfo,
        Session,
        SessionStatusResponse,
        SessionVariant;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/pull_request_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/tables/pull_requests_table.dart";
import "../../api/database/tables/session_table.dart" show SessionDto;
import "../api/git_cli_api.dart";
import "derived_session_builder.dart";
import "mappers/plugin_activity_summary_mapper.dart";
import "mappers/plugin_command_mapper.dart";
import "mappers/plugin_message_mapper.dart";
import "mappers/plugin_session_mapper.dart";
import "mappers/plugin_session_status_mapper.dart";
import "mappers/prompt_part_mapper.dart";
import "mappers/pull_request_mapper.dart";
import "mappers/session_catalog_mapper.dart";
import "mappers/stored_session_mapper.dart";
import "models/project_not_found_exception.dart";
import "models/session_operation.dart";
import "models/stored_session.dart";
import "session_unseen_calculator.dart";

typedef SessionBindingsCommitted = ({String pluginId, List<String> backendSessionIds});

class SessionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();
  static const SessionCatalogMapper _sessionCatalogMapper = SessionCatalogMapper();

  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final PullRequestDao _pullRequestDao;
  final GitCliApi _gitCliApi;
  final SessionUnseenCalculator _unseenCalculator;
  final Set<String> _tombstonedBackendSessionIds = <String>{};
  final Set<String> _deletedSessionIds = <String>{};
  final StreamController<SessionBindingsCommitted> _bindingCommitsController =
      StreamController<SessionBindingsCommitted>.broadcast(sync: true);
  Future<void>? _tombstoneLoad;
  bool _tombstonesLoaded = false;
  int _lastProjectionTimestamp = 0;

  SessionRepository({
    required BridgePluginApi plugin,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required PullRequestDao pullRequestDao,
    required GitCliApi gitCliApi,
    required SessionUnseenCalculator unseenCalculator,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _pullRequestDao = pullRequestDao,
       _gitCliApi = gitCliApi,
       _unseenCalculator = unseenCalculator;

  Stream<SessionBindingsCommitted> get bindingCommits => _bindingCommitsController.stream;

  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final projectionUpdatedAt = captureProjectionTimestamp();
    final pluginSessions = await _pluginSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
    );
    final backendSessionIds = [for (final session in pluginSessions) session.id];
    final committedByBackendId = await _sessionDao.attachedDatabase.transaction(() async {
      final existingByBackendId = await _sessionDao.getSessionsByBackendIds(
        pluginId: _plugin.id,
        backendSessionIds: backendSessionIds,
      );
      final tombstoned = await _sessionDao.getTombstonedSessionIds(
        pluginId: _plugin.id,
      );
      final observedRoots = <ObservedRootSession>[];
      final allocatedSessionIds = await _allocateSessionIds(
        count: pluginSessions
            .where((session) => !tombstoned.contains(session.id) && existingByBackendId[session.id] == null)
            .length,
      );
      var allocatedIndex = 0;
      for (final session in pluginSessions) {
        if (tombstoned.contains(session.id)) continue;
        final existingBinding = existingByBackendId[session.id];
        observedRoots.add((
          sessionId: existingBinding?.sessionId ?? allocatedSessionIds[allocatedIndex++],
          backendSessionId: session.id,
          projectId: projectId,
          directory: session.directory,
          catalogTitle: session.title,
          createdAt: session.time?.created ?? existingBinding?.createdAt ?? projectionUpdatedAt,
          updatedAt: session.time?.updated ?? existingBinding?.updatedAt ?? projectionUpdatedAt,
          archivedAt: session.time?.archived,
          projectionUpdatedAt: projectionUpdatedAt,
        ));
      }
      return _sessionDao.upsertObservedRootSessions(
        pluginId: _plugin.id,
        sessions: observedRoots,
      );
    });
    _publishBindingsCommitted(
      backendSessionIds: committedByBackendId.keys.toList(growable: false),
    );
    return _mapCatalogSessions(
      rows: [
        for (final session in pluginSessions) ?committedByBackendId[session.id],
      ],
    );
  }

  /// The plugin sessions that belong to [projectId].
  ///
  /// A native plugin owns its own project→session grouping, so we delegate
  /// straight to it. A bridge-derived plugin only knows each session's own cwd
  /// — which, for a session started in a dedicated worktree, is the worktree
  /// path rather than the project the user opened. The bridge owns that
  /// session→project attribution (the row it wrote at creation), so for
  /// derived plugins we scope via [DerivedSessionBuilder] and paginate here,
  /// keeping a worktree session under its project.
  Future<List<PluginSession>> _pluginSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    switch (_plugin) {
      case final NativeProjectsPluginApi plugin:
        // The plugin scopes sessions by directory, so hand it the project's
        // live directory — the id may point where the folder used to be.
        final directory = await resolveProjectDirectory(projectId: projectId);
        final sessions = await plugin.getSessions(directory, start: start, limit: limit);
        // Sessions fetched for a project belong to it by construction. Re-key
        // them to the stable id: when the lookup went through a moved folder's
        // live path, the plugin can only echo the directory it was asked
        // about, not the identifier the phone and the bridge key on.
        return [
          for (final session in sessions) session.copyWith(projectID: projectId),
        ];

      case final BridgeDerivedProjectsPluginApi plugin:
        final projectDirectory = await resolveProjectDirectory(projectId: projectId);
        final sessionProjectPaths = await _sessionDao.getSessionProjectPaths(pluginId: plugin.id);
        final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
        final allSessions = await plugin.listAllSessions(
          knownDirectories: _knownDirectories(
            sessionProjectPaths: sessionProjectPaths,
            projectId: projectDirectory,
          ),
        );
        final scoped = _derivedSessionBuilder.build(
          projectId: projectDirectory,
          // A backend without session deletion keeps enumerating deleted
          // sessions forever — the tombstones filter them out.
          sessions: allSessions.where((s) => !tombstoned.contains(s.id)).toList(growable: false),
          projectPathBySessionId: {
            for (final row in sessionProjectPaths) row.backendSessionId: row.projectPath,
          },
        );

        final from = start ?? 0;
        if (from >= scoped.length) return const [];
        final until = limit == null ? scoped.length : (from + limit).clamp(0, scoped.length);
        return [
          for (final session in scoped.sublist(from, until)) session.copyWith(projectID: projectId),
        ];
    }
  }

  /// The enumeration hints for a derive-style plugin: every stored project
  /// path and dedicated-worktree path the bridge attributes to it, plus the
  /// [projectId] being served (which may not have a stored session yet).
  static Set<String> _knownDirectories({
    required List<SessionProjectPathRow> sessionProjectPaths,
    required String? projectId,
  }) {
    return {
      ?projectId,
      for (final row in sessionProjectPaths) ...[
        row.projectPath,
        ?row.worktreePath,
      ],
    };
  }

  /// Whether an unpaginated [getSessionsForProject] result is the complete
  /// authoritative session list for a project — the precondition for
  /// reconciling away stored rows missing from it.
  ///
  /// A native plugin owns its session list, so the fetched list is complete.
  /// A bridge-derived plugin's enumeration is only eventually-complete: a
  /// freshly-created session can exist solely as a stored row until the
  /// backend flushes it to disk (codex rollouts), so treating that list as
  /// complete would reconcile away the fresh row — and with it a worktree
  /// session's parent-project attribution.
  bool get sessionListIsAuthoritative => switch (_plugin) {
    NativeProjectsPluginApi() => true,
    BridgeDerivedProjectsPluginApi() => false,
  };

  Future<Session> enrichSession({required Session session}) async {
    final enrichedSessions = await enrichSessions(sessions: [session]);
    return enrichedSessions.single;
  }

  Future<Session> enrichPluginSession({required PluginSession pluginSession}) {
    return enrichSession(session: pluginSession.toSharedSession(pluginId: _plugin.id));
  }

  Future<Session> createSession({
    required String pluginId,
    required String projectId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
    required bool isDedicated,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
  }) async {
    ensurePluginAvailable(pluginId: pluginId, operation: SessionOperation.createSession);
    final created = await _plugin.createSession(
      directory: directory,
      parentSessionId: parentSessionId,
      parts: parts.map((part) => part.toPlugin()).toList(growable: false),
      variant: _toPluginVariant(variant),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
    final projectionUpdatedAt = captureProjectionTimestamp();
    final createdAt = created.time?.created ?? projectionUpdatedAt;
    final updatedAt = created.time?.updated ?? createdAt;
    late String sessionId;
    await _sessionDao.attachedDatabase.transaction(() async {
      final existingBinding = await _sessionDao.getSessionByBinding(
        pluginId: pluginId,
        backendSessionId: created.id,
      );
      if (existingBinding?.parentSessionId != null) {
        throw PluginOperationException(
          SessionOperation.createSession.name,
          statusCode: 409,
          message: "backend session ${created.id} is already bound as a child session",
        );
      }
      sessionId = existingBinding?.sessionId ?? await _allocateSessionId();
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSession(
        sessionId: sessionId,
        backendSessionId: created.id,
        projectId: projectId,
        isDedicated: isDedicated,
        createdAt: createdAt,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
        lastAgent: lastAgent,
        lastAgentModel: lastAgentModel,
        pluginId: pluginId,
      );
      await _sessionDao.updateObservedSessionProjection(
        sessionId: sessionId,
        directory: directory,
        catalogTitle: created.title,
        updateCatalogTitle: true,
        updatedAt: updatedAt,
        projectionUpdatedAt: projectionUpdatedAt,
      );
    });
    _publishBindingsCommitted(backendSessionIds: [created.id]);
    return created.toSharedSessionWithId(sessionId: sessionId, pluginId: pluginId);
  }

  Future<Session> renameSession({required String sessionId, required String title}) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.renameSession,
    );
    await _primeDerivedSessionDirectory(binding: binding);
    final updated = await _plugin.renameSession(sessionId: binding.backendSessionId, title: title);
    return updated.toSharedSessionWithId(sessionId: binding.sessionId, pluginId: binding.pluginId);
  }

  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) async {
    ensurePluginAvailable(pluginId: pluginId, operation: SessionOperation.getCommands);
    final normalizedProjectId = projectId?.trim();
    final commands = await _plugin.getCommands(
      // The plugin reads commands from the project's directory, so resolve
      // the id to the live path. Null/blank keeps the plugin's own fallback.
      projectId: normalizedProjectId == null || normalizedProjectId.isEmpty
          ? null
          : await resolveProjectDirectory(projectId: normalizedProjectId),
    );
    return CommandListResponse(
      items: commands.map((command) => command.toSharedCommandInfo()).toList(growable: false),
    );
  }

  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.sendCommand,
    );
    await _primeDerivedSessionDirectory(binding: binding);
    return _plugin.sendCommand(
      sessionId: binding.backendSessionId,
      command: command,
      arguments: arguments,
      variant: _toPluginVariant(variant),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.sendPrompt,
    );
    await _primeDerivedSessionDirectory(binding: binding);
    return _plugin.sendPrompt(
      sessionId: binding.backendSessionId,
      parts: parts.map((part) => part.toPlugin()).toList(growable: false),
      variant: _toPluginVariant(variant),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  /// All messages of [sessionId], mapped to the shared model. The stored
  /// directory is primed first: after a bridge restart, the history replay can
  /// be the FIRST plugin call for a stored worktree session, and a
  /// directory-scoped backend would otherwise replay in its launch directory.
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.getSessionMessages,
    );
    await _primeDerivedSessionDirectory(binding: binding);
    final pluginMessages = await _plugin.getSessionMessages(binding.backendSessionId);
    return pluginMessages.toSharedMessageWithParts(sessionId: binding.sessionId);
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

  Future<bool> isSessionTombstoned({required String sessionId}) async {
    if (_deletedSessionIds.contains(sessionId)) return true;
    await _ensureTombstonesLoaded();
    if (_tombstonedBackendSessionIds.contains(sessionId)) return true;
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    return binding != null && _tombstonedBackendSessionIds.contains(binding.backendSessionId);
  }

  Future<void> _ensureTombstonesLoaded() async {
    if (_tombstonesLoaded) return;
    final inFlight = _tombstoneLoad;
    if (inFlight != null) return inFlight;

    final load = _loadTombstones();
    _tombstoneLoad = load;
    try {
      await load;
    } finally {
      if (identical(_tombstoneLoad, load)) {
        _tombstoneLoad = null;
      }
    }
  }

  Future<void> _loadTombstones() async {
    final stored = await _sessionDao.getTombstonedSessionIds(pluginId: _plugin.id);
    // Merge rather than replace so a deletion committed during the initial
    // read cannot be lost when that read completes.
    _tombstonedBackendSessionIds.addAll(stored);
    _tombstonesLoaded = true;
  }

  /// Deletes the backend root, then tombstones every persisted binding in its
  /// subtree and removes the stable root atomically.
  Future<Session> deleteSession({required String sessionId}) async {
    final stored = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
    );
    final subtree = await _getSessionSubtree(root: stored);
    final deletionSnapshot = (await _mapCatalogSessions(rows: [stored])).single;
    try {
      await _plugin.deleteSession(stored.backendSessionId);
    } on PluginOperationException catch (error) {
      if (!error.isNotFound) rethrow;
    }
    await _sessionDao.transaction(() async {
      final deletedAt = DateTime.now().millisecondsSinceEpoch;
      for (final binding in subtree) {
        await _sessionDao.insertSessionTombstone(
          backendSessionId: binding.backendSessionId,
          pluginId: binding.pluginId,
          deletedAt: deletedAt,
        );
      }
      await _sessionDao.deleteSession(sessionId: stored.sessionId);
    });
    _deletedSessionIds.addAll(subtree.map((binding) => binding.sessionId));
    _tombstonedBackendSessionIds.addAll(subtree.map((binding) => binding.backendSessionId));
    return deletionSnapshot;
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
  Future<void> _primeDerivedSessionDirectory({required SessionDto binding}) async {
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
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
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async {
    await _ensureTombstonesLoaded();
    final summaries = [
      for (final summary in _plugin.getActiveSessionsSummary())
        if (summary.activeSessions.any((active) => !_tombstonedBackendSessionIds.contains(active.id)))
          summary.copyWith(
            activeSessions: [
              for (final active in summary.activeSessions)
                if (!_tombstonedBackendSessionIds.contains(active.id)) active,
            ],
          ),
    ];
    final backendSessionIds = {
      for (final summary in summaries)
        for (final active in summary.activeSessions) ...{
          active.id,
          ...active.childSessionIds,
        },
    };
    var bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: _plugin.id,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    final missingRootIds = {
      for (final summary in summaries)
        for (final active in summary.activeSessions)
          if (!bindings.containsKey(active.id)) active.id,
    };
    final plugin = _plugin;
    if (missingRootIds.isNotEmpty && plugin is NativeProjectsPluginApi) {
      await _hydrateActiveRootBindings(
        plugin: plugin,
        summaries: summaries,
        missingRootIds: missingRootIds,
      );
      bindings = await _sessionDao.getSessionsByBackendIds(
        pluginId: _plugin.id,
        backendSessionIds: backendSessionIds.toList(growable: false),
      );
    }

    ActiveSession? mapActiveSession(PluginActiveSession active) {
      final binding = bindings[active.id];
      if (binding == null) return null;
      return active.toSharedActiveSession(
        sessionId: binding.sessionId,
        childSessionIds: [
          for (final backendChildId in active.childSessionIds)
            if (bindings[backendChildId] case final child?) child.sessionId,
        ],
      );
    }

    switch (_plugin) {
      case NativeProjectsPluginApi():
        return [
          for (final summary in summaries)
            ProjectActivitySummary(
              id: summary.id,
              activeSessions: [
                for (final active in summary.activeSessions) ?mapActiveSession(active),
              ],
            ),
        ];
      case final BridgeDerivedProjectsPluginApi plugin:
        final rows = await _sessionDao.getSessionProjectPaths(pluginId: plugin.id);
        final projectPathBySessionId = {for (final row in rows) row.backendSessionId: row.projectPath};
        // Regroup under the stored attribution — the same rule the REST path's
        // DerivedSessionBuilder/DerivedProjectBuilder apply. Unknown sessions
        // are omitted because no stable Sesori identity can be published.
        final byProject = <String, List<PluginActiveSession>>{};
        for (final summary in summaries) {
          for (final active in summary.activeSessions) {
            if (!bindings.containsKey(active.id)) continue;
            final target = normalizeProjectDirectory(
              directory: projectPathBySessionId[active.id]!,
            );
            (byProject[target] ??= []).add(active);
          }
        }
        return [
          for (final entry in byProject.entries)
            ProjectActivitySummary(
              id: entry.key,
              activeSessions: [
                for (final active in entry.value) ?mapActiveSession(active),
              ],
            ),
        ];
    }
  }

  Future<void> _hydrateActiveRootBindings({
    required NativeProjectsPluginApi plugin,
    required List<PluginProjectActivitySummary> summaries,
    required Set<String> missingRootIds,
  }) async {
    // A native project API can resolve an activity-summary directory to both
    // stable project identity and live path. Derived plugins cannot safely do
    // that for an unknown worktree, so their rowless activity stays omitted.
    final hydratedProjectIds = <String>{};
    for (final summary in summaries) {
      if (!summary.activeSessions.any((active) => missingRootIds.contains(active.id))) continue;

      try {
        final project = await plugin.getProject(summary.id);
        if (!hydratedProjectIds.add(project.id)) continue;
        await _projectsDao.insertProjectIfMissing(projectId: project.id, path: project.directory);
        await getSessionsForProject(projectId: project.id, start: null, limit: null);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Could not hydrate active project ${summary.id}; omitting unresolved sessions",
          error,
          stackTrace,
        );
      }
    }
  }

  PluginSessionVariant? _toPluginVariant(SessionVariant? variant) {
    return switch (variant) {
      SessionVariant(:final id) => PluginSessionVariant(id: id),
      null => null,
    };
  }

  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.getSession,
    );
    if (binding.projectId != projectId) return null;
    if (binding.parentSessionId != null) {
      return getCatalogSession(sessionId: sessionId);
    }
    final sessions = await getSessionsForProject(projectId: projectId, start: null, limit: null);
    for (final session in sessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  Future<String?> findProjectIdForSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.projectId;
  }

  Future<void> notifySessionArchived({required String sessionId}) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.archiveSession,
    );
    return _plugin.archiveSession(sessionId: binding.backendSessionId);
  }

  Future<void> abortSession({required String sessionId}) async {
    final binding = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.abortSession,
    );
    return _plugin.abortSession(sessionId: binding.backendSessionId);
  }

  Future<SessionStatusResponse> getSessionStatuses() async {
    final pluginStatuses = await _plugin.getSessionStatuses();
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: _plugin.id,
      backendSessionIds: pluginStatuses.keys.toList(growable: false),
    );
    return SessionStatusResponse(
      statuses: {
        for (final entry in pluginStatuses.entries)
          if (bindings[entry.key] case final binding?) binding.sessionId: entry.value.toSharedSessionStatus(),
      },
    );
  }

  Future<List<Session>> enrichSessions({required List<Session> sessions}) async {
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);

    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);

    // Ask git only for sessions that still have no branch: the list path and
    // catalog reads already resolve+store before handing a Session here, and
    // GetSessionsHandler calls this again for PR/archive merge — re-spawning
    // git for those would only repeat the same answer. Plugin-mapped sessions
    // arrive with a null branch, so they still get resolved. Resolved before
    // PRs are queried: the PR join reads the stored branch_name in SQL, so it
    // must see the branch this response is about to show.
    final branchesByDirectory = await _resolveBranches(
      directories: {
        for (final session in sessions)
          if (session.branchName == null && dbSessions[session.id]?.worktreePath == null) session.directory,
      },
      rows: dbSessions.values,
    );

    final prsBySessionId = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
    final pullRequestsBySessionId = <String, PullRequestInfo>{};
    for (final session in sessions) {
      final selectedPr = _selectBestPr(prsBySessionId[session.id]);
      if (selectedPr != null) {
        pullRequestsBySessionId[session.id] = pullRequestInfoFromDto(selectedPr);
      }
    }

    return enrichSharedSessions(
      sessions: sessions,
      storedSessionsById: dbSessions,
      pullRequestsBySessionId: pullRequestsBySessionId,
      branchNamesBySessionId: {
        for (final session in sessions)
          session.id:
              session.branchName ??
              _branchFor(
                row: dbSessions[session.id],
                directory: session.directory,
                branchesByDirectory: branchesByDirectory,
              ),
      },
      unseenCalculator: _unseenCalculator,
      // Only a bridge-derived plugin cedes project attribution to the stored
      // row; a native backend's reported projectID is authoritative.
      adoptStoredProjectId: _plugin is BridgeDerivedProjectsPluginApi,
    );
  }

  /// The branch each directory in [directories] is checked out on, keyed by
  /// directory and omitting the ones git has no branch for, written back onto
  /// whichever of [rows] it applies to.
  ///
  /// Only a session the bridge cut in a worktree is given a branch at creation.
  /// A plain checkout's branch lives in the working copy and changes under the
  /// bridge whenever the user checks something else out, so it is re-read here
  /// on every listing rather than trusted from the row. Sessions in a plain
  /// checkout all share the project's one directory, so resolving per distinct
  /// directory rather than per session keeps a list of them to a single git
  /// call.
  ///
  /// Resolving and storing are bundled here because a branch only this process
  /// knows is a branch pull requests cannot be matched against: `PrSyncService`
  /// decides a PR is worth keeping by looking for its head branch among the
  /// stored rows, and the PR-to-session join runs in SQL over `branch_name`.
  /// Both read the column, so resolving without storing names the branch in the
  /// list and still leaves the PR dark.
  Future<Map<String, String>> _resolveBranches({
    required Set<String> directories,
    required Iterable<SessionDto> rows,
  }) async {
    if (directories.isEmpty) return const {};

    final resolved = await Future.wait<(String, String?)>([
      for (final directory in directories)
        _gitCliApi.getCurrentBranch(projectPath: directory).then((branch) => (directory, branch)),
    ]);
    final branchesByDirectory = {
      for (final (directory, branch) in resolved) directory: ?branch,
    };

    final sessionIdsByBranch = <String, List<String>>{};
    for (final row in rows) {
      final branch = _branchFor(row: row, directory: row.directory, branchesByDirectory: branchesByDirectory);
      if (branch == null || branch == row.branchName) continue;
      sessionIdsByBranch.putIfAbsent(branch, () => <String>[]).add(row.sessionId);
    }
    for (final MapEntry(key: branch, value: sessionIds) in sessionIdsByBranch.entries) {
      await _sessionDao.setBranchName(sessionIds: sessionIds, branchName: branch);
    }

    return branchesByDirectory;
  }

  /// The branch to show for the session [row] describes in [directory], and to
  /// store back on it.
  ///
  /// A worktree session's branch was cut by the bridge and written to its row
  /// at creation, so it is authoritative and git would only echo it back. A
  /// plain checkout's branch is whatever git reports right now; the stored
  /// value is only the last answer git gave, which we keep rather than drop
  /// when it has no answer today — a detached HEAD and a project folder that
  /// has moved away are indistinguishable here, and the second must not erase
  /// a branch the checkout is still on.
  static String? _branchFor({
    required SessionDto? row,
    required String directory,
    required Map<String, String> branchesByDirectory,
  }) {
    if (row?.worktreePath != null) return row?.branchName;
    return branchesByDirectory[directory] ?? row?.branchName;
  }

  Future<List<Session>> _mapCatalogSessions({required List<SessionDto> rows}) async {
    final sessionIds = [for (final row in rows) row.sessionId];
    // Branches before PRs, not concurrently: the PR join reads the stored
    // branch_name in SQL, so it must run after _resolveBranches has written
    // the branch this response is about to show.
    final branchesByDirectory = await _resolveBranches(
      directories: {
        for (final row in rows)
          if (row.worktreePath == null) row.directory,
      },
      rows: rows,
    );
    final prsBySessionId = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
    return [
      for (final row in rows)
        _sessionCatalogMapper.map(
          row: row,
          branchName: _branchFor(row: row, directory: row.directory, branchesByDirectory: branchesByDirectory),
          pullRequest: switch (_selectBestPr(prsBySessionId[row.sessionId])) {
            final pullRequest? => pullRequestInfoFromDto(pullRequest),
            null => null,
          },
          unseen: _unseenCalculator.isUnseen(
            activity: row.lastActivityAt,
            userMessage: row.lastUserMessageAt,
            seen: row.lastSeenAt,
          ),
        ),
    ];
  }

  /// Selects the most relevant PR from a list of candidates.
  /// Prefers OPEN PRs, then breaks ties by highest PR number.
  static PullRequestDto? _selectBestPr(List<PullRequestDto>? prs) {
    if (prs == null || prs.isEmpty) return null;

    PullRequestDto? selected;
    for (final pr in prs) {
      if (selected == null) {
        selected = pr;
        continue;
      }

      final selectedIsOpen = selected.state == PrState.open;
      final currentIsOpen = pr.state == PrState.open;

      if (currentIsOpen && !selectedIsOpen) {
        selected = pr;
        continue;
      }

      if (currentIsOpen == selectedIsOpen && pr.prNumber > selected.prNumber) {
        selected = pr;
      }
    }

    return selected;
  }

  Future<List<Session>> getChildSessions({required String sessionId}) async {
    final parent = await _requireActiveBinding(
      sessionId: sessionId,
      operation: SessionOperation.getChildSessions,
    );
    await _primeDerivedSessionDirectory(binding: parent);
    final durableRows = await _sessionDao.getChildCatalogSessions(parentSessionId: sessionId);
    // COMPATIBILITY 2026-07-16 (pre-Stage 5 catalog import): released bridges
    // kept backend children rowless. Remove this additive plugin discovery once
    // automatic catalog hydration imports existing child ancestry.
    final projectionUpdatedAt = captureProjectionTimestamp();
    final List<PluginSession> pluginChildren;
    try {
      pluginChildren = await _plugin.getChildSessions(parent.backendSessionId);
    } on PluginOperationException catch (error, stackTrace) {
      if (durableRows.isEmpty) rethrow;
      Log.w(
        "Could not refresh children for ${parent.pluginId}/${parent.backendSessionId}; serving durable catalog history",
        error,
        stackTrace,
      );
      return _mapCatalogSessions(rows: durableRows);
    }
    final committedBackendIds = <String>[];
    for (final pluginChild in pluginChildren) {
      final child = pluginChild.copyWith(parentID: parent.backendSessionId).toSharedSession(pluginId: _plugin.id);
      final committed = await insertObservedChild(
        pluginId: _plugin.id,
        observed: child,
        parent: parent.toStoredSession(),
        projectionUpdatedAt: projectionUpdatedAt,
      );
      if (committed != null) committedBackendIds.add(pluginChild.id);
    }
    _publishBindingsCommitted(backendSessionIds: committedBackendIds);
    return _mapCatalogSessions(
      rows: await _sessionDao.getChildCatalogSessions(parentSessionId: sessionId),
    );
  }

  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions.map((session) => session.toStoredSession()).toList(growable: false);
  }

  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async {
    final sessions = await _sessionDao.getOtherActiveSessionsSharing(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
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
    switch (_plugin) {
      case BridgeDerivedProjectsPluginApi():
        // The project id IS the canonical directory and the plugin has no
        // getProject — resolve the path directly.
        final trimmed = projectId.trim();
        return trimmed.isEmpty ? null : normalizeProjectDirectory(directory: trimmed);

      case final NativeProjectsPluginApi plugin:
        final directory = await resolveProjectDirectory(projectId: projectId);
        try {
          // Probe the plugin so an unreachable backend yields null (callers
          // fall back rather than running git tooling blind), then hand back
          // the live directory — not the plugin's id, which may point where
          // the folder used to be.
          await plugin.getProject(directory);
          return directory;
        } catch (e) {
          Log.w("[SessionRepository] getProjectPath failed for $projectId: $e");
          return null;
        }
    }
  }

  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
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

  Future<Map<String, StoredSession>> getStoredSessionsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async {
    final rows = await _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds,
    );
    return {
      for (final entry in rows.entries) entry.key: entry.value.toStoredSession(),
    };
  }

  Future<StoredSession?> updateObservedSessionProjection({
    required String pluginId,
    required Session observed,
    required bool updateCatalogTitle,
    required int projectionUpdatedAt,
  }) async {
    return _sessionDao.attachedDatabase.transaction(() async {
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
      final updated = await _sessionDao.updateObservedSessionProjection(
        sessionId: binding.sessionId,
        directory: observed.directory,
        catalogTitle: observed.title,
        updateCatalogTitle: updateCatalogTitle,
        updatedAt: observed.time?.updated ?? binding.updatedAt,
        projectionUpdatedAt: projectionUpdatedAt,
      );
      if (!updated) return null;
      return (await _sessionDao.getSession(sessionId: binding.sessionId))?.toStoredSession();
    });
  }

  Future<StoredSession?> insertObservedChild({
    required String pluginId,
    required Session observed,
    required StoredSession parent,
    required int projectionUpdatedAt,
  }) async {
    return _sessionDao.attachedDatabase.transaction(() async {
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
        final updated = await _sessionDao.updateObservedSessionProjection(
          sessionId: existing.sessionId,
          directory: observed.directory,
          catalogTitle: observed.title,
          updateCatalogTitle: observed.title != null,
          updatedAt: observed.time?.updated ?? existing.updatedAt,
          projectionUpdatedAt: projectionUpdatedAt,
        );
        if (!updated) return null;
        return (await _sessionDao.getSession(sessionId: existing.sessionId))?.toStoredSession();
      }
      final sessionId = await _allocateSessionId();
      final createdAt = observed.time?.created ?? projectionUpdatedAt;
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
      return (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
    });
  }

  Future<StoredSession> requireActiveStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    return (await _requireActiveBinding(sessionId: sessionId, operation: operation)).toStoredSession();
  }

  Future<Session?> getCatalogSession({required String sessionId}) async {
    final row = await _sessionDao.getSession(sessionId: sessionId);
    if (row == null) return null;
    return (await _mapCatalogSessions(rows: [row])).single;
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

  Future<void> unarchiveStoredSession({required String sessionId}) {
    return _sessionDao.clearArchived(
      sessionId: sessionId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      projectionUpdatedAt: captureProjectionTimestamp(),
    );
  }

  Future<void> insertStoredSession({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? agent,
    required AgentModel? agentModel,
  }) async {
    final db = _sessionDao.attachedDatabase;
    await db.transaction(() async {
      final placeholder = await _sessionDao.getSession(sessionId: sessionId);
      if (placeholder != null &&
          (placeholder.pluginId != pluginId || placeholder.backendSessionId != backendSessionId)) {
        throw PluginOperationException(
          SessionOperation.createSession.name,
          statusCode: 409,
          message: "session id $sessionId is already bound to another plugin session",
        );
      }
      await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSession(
        sessionId: sessionId,
        backendSessionId: backendSessionId,
        projectId: projectId,
        isDedicated: isDedicated,
        createdAt: createdAt,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
        lastAgent: agent,
        lastAgentModel: agentModel,
        pluginId: pluginId,
      );
      // A live `session.created` can race ahead of this create flow and insert
      // a placeholder keyed to the plugin-reported cwd — for a dedicated
      // worktree session that's the throwaway worktree path, along with a
      // project row for it. The upsert above re-attributed the session to the
      // canonical project; drop the now-orphaned placeholder project row so it
      // can't surface as an empty derived project card. Guarded twice: only
      // when nothing else references the row, and only when the row carries no
      // user-set state (hidden/rename/base-branch) — a row
      // the user touched is a real project, not placeholder junk.
      final placeholderProjectId = placeholder?.projectId;
      if (placeholderProjectId != null && placeholderProjectId != projectId) {
        final (row, remaining) = await (
          db.projectsDao.getProject(projectId: placeholderProjectId),
          _sessionDao.getSessionsByProject(projectId: placeholderProjectId),
        ).wait;
        final untouched = row != null && !row.hidden && row.displayName == null && row.baseBranch == null;
        if (untouched && remaining.isEmpty) {
          await db.projectsDao.deleteProject(projectId: placeholderProjectId);
        }
      }
    });
  }

  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    return _sessionDao.updatePromptDefaults(
      sessionId: sessionId,
      agent: agent,
      agentModel: agentModel,
    );
  }

  void ensurePluginAvailable({required String pluginId, required SessionOperation operation}) {
    if (pluginId == _plugin.id) return;
    throw PluginOperationException(
      operation.name,
      statusCode: 503,
      message: "plugin $pluginId is not running",
    );
  }

  Future<SessionDto> _requireActiveBinding({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    ensurePluginAvailable(pluginId: binding.pluginId, operation: operation);
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

  void _publishBindingsCommitted({required List<String> backendSessionIds}) {
    if (backendSessionIds.isEmpty || _bindingCommitsController.isClosed) return;
    _bindingCommitsController.add((
      pluginId: _plugin.id,
      backendSessionIds: List<String>.unmodifiable(backendSessionIds),
    ));
  }

  Future<List<String>> _allocateSessionIds({required int count}) async {
    final allocated = <String>[];
    final reserved = <String>{};
    while (allocated.length < count) {
      final candidates = <String>{};
      while (candidates.length < count - allocated.length) {
        final candidate = _generateSessionId();
        if (reserved.add(candidate)) candidates.add(candidate);
      }
      final occupied = await _sessionDao.getSessionsByIds(
        sessionIds: candidates.toList(growable: false),
      );
      allocated.addAll(candidates.where((candidate) => !occupied.containsKey(candidate)));
    }
    return allocated;
  }

  Future<String> _allocateSessionId({Set<String>? reservedSessionIds}) async {
    while (true) {
      final candidate = _generateSessionId();
      if (reservedSessionIds != null && !reservedSessionIds.add(candidate)) continue;
      if (await _sessionDao.getSession(sessionId: candidate) == null) return candidate;
      reservedSessionIds?.remove(candidate);
    }
  }

  static String _generateSessionId() {
    final buffer = StringBuffer("ses_");
    for (var index = 0; index < 16; index++) {
      buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
    }
    return buffer.toString();
  }
}
