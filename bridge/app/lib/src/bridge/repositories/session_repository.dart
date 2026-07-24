import "dart:async";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PersistedSessionCleanupApi,
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
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../../api/database/tables/pull_requests_table.dart";
import "../../api/database/tables/session_table.dart" show SessionDto;
import "../../repositories/project_catalog_identity_calculator.dart";
import "../runtime/plugin_runtime.dart";
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

enum SessionBindingCommitKind { sessionCreation, catalogSync }

typedef SessionBindingsCommitted = ({
  String pluginId,
  int generation,
  SessionBindingCommitKind kind,
  List<String> backendSessionIds,
});

class SessionRepository {
  static const SessionCatalogMapper _sessionCatalogMapper = SessionCatalogMapper();

  final PluginRuntime _runtime;
  final Set<String> _bridgeDerivedProjectPluginIds;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final PullRequestDao _pullRequestDao;
  final SessionUnseenCalculator _unseenCalculator;
  final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator;
  final Duration _aggregateSourceDeadline;
  final Map<String, Set<String>> _tombstonedBackendSessionIds = <String, Set<String>>{};
  final Set<String> _deletedSessionIds = <String>{};
  final StreamController<SessionBindingsCommitted> _bindingCommitsController =
      StreamController<SessionBindingsCommitted>.broadcast(sync: true);
  final Map<String, Future<void>> _tombstoneLoads = <String, Future<void>>{};
  final Set<String> _tombstonesLoaded = <String>{};
  int _lastProjectionTimestamp = 0;

  SessionRepository({
    required PluginRuntime runtime,
    required Set<String> bridgeDerivedProjectPluginIds,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required PullRequestDao pullRequestDao,
    required SessionUnseenCalculator unseenCalculator,
    required ProjectCatalogIdentityCalculator projectCatalogIdentityCalculator,
    required Duration aggregateSourceDeadline,
  }) : _runtime = runtime,
       _bridgeDerivedProjectPluginIds = Set<String>.unmodifiable(bridgeDerivedProjectPluginIds),
       _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _pullRequestDao = pullRequestDao,
       _unseenCalculator = unseenCalculator,
       _projectCatalogIdentityCalculator = projectCatalogIdentityCalculator,
       _aggregateSourceDeadline = aggregateSourceDeadline;

  Stream<SessionBindingsCommitted> get bindingCommits => _bindingCommitsController.stream;

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

  Future<Session> enrichSession({required Session session}) async {
    final enrichedSessions = await enrichSessions(sessions: [session]);
    return enrichedSessions.single;
  }

  Future<Session> enrichPluginSession({required String pluginId, required PluginSession pluginSession}) {
    return enrichSession(session: pluginSession.toSharedSession(pluginId: pluginId));
  }

  Future<Session> createSession({
    required String pluginId,
    required String projectId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required String? userVisibleText,
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
    final result = await _runtime.useAndCommit(
      pluginId: pluginId,
      operation: SessionOperation.createSession,
      prepare: (plugin) {
        return plugin.createSession(
          directory: directory,
          parentSessionId: parentSessionId,
          parts: parts.map((part) => part.toPlugin()).toList(growable: false),
          userVisibleText: userVisibleText,
          variant: _toPluginVariant(variant),
          agent: agent,
          model: switch (model) {
            PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
            null => null,
          },
        );
      },
      commit: (created, generation) async {
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
        return (created: created, sessionId: sessionId, generation: generation);
      },
    );
    _publishBindingsCommitted(
      pluginId: pluginId,
      generation: result.generation,
      kind: SessionBindingCommitKind.sessionCreation,
      backendSessionIds: [result.created.id],
    );
    return result.created.toSharedSessionWithId(sessionId: result.sessionId, pluginId: pluginId);
  }

  Future<Session> renameSession({required String sessionId, required String title}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.renameSession,
    );
    final updated = await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.renameSession,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.renameSession(sessionId: binding.backendSessionId, title: title);
      },
    );
    return updated.toSharedSessionWithId(
      sessionId: binding.sessionId,
      pluginId: binding.pluginId,
    );
  }

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

  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.sendCommand,
    );
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.sendCommand,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.sendCommand(
          sessionId: binding.backendSessionId,
          command: command,
          arguments: arguments,
          userVisibleArguments: userVisibleArguments,
          variant: _toPluginVariant(variant),
          agent: agent,
          model: switch (model) {
            PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
            null => null,
          },
        );
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
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.sendPrompt,
    );
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.sendPrompt,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.sendPrompt(
          sessionId: binding.backendSessionId,
          parts: parts.map((part) => part.toPlugin()).toList(growable: false),
          variant: _toPluginVariant(variant),
          agent: agent,
          model: switch (model) {
            PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
            null => null,
          },
        );
      },
    );
  }

  /// All messages of [sessionId], mapped to the shared model. The stored
  /// directory is primed first: after a bridge restart, the history replay can
  /// be the FIRST plugin call for a stored worktree session, and a
  /// directory-scoped backend would otherwise replay in its launch directory.
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getSessionMessages,
    );
    final pluginMessages = await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.getSessionMessages,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.getSessionMessages(binding.backendSessionId);
      },
    );
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
    if (inFlight != null) return inFlight;

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
  Future<Session> deleteSession({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
    );
    final subtree = await _getSessionSubtree(root: binding);
    final deletionSnapshot = (await _mapCatalogSessions(rows: [binding])).single;
    await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.deleteSession,
      body: (plugin) async {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        try {
          await plugin.deleteSession(binding.backendSessionId);
        } on PluginOperationException catch (error) {
          if (!error.isNotFound) rethrow;
        }
      },
    );
    await _sessionDao.transaction(() async {
      final deletedAt = DateTime.now().millisecondsSinceEpoch;
      for (final binding in subtree) {
        await _sessionDao.insertSessionTombstone(
          backendSessionId: binding.backendSessionId,
          pluginId: binding.pluginId,
          deletedAt: deletedAt,
        );
      }
      await _sessionDao.deleteSession(sessionId: binding.sessionId);
    });
    _deletedSessionIds.addAll(subtree.map((binding) => binding.sessionId));
    for (final binding in subtree) {
      _tombstonesFor(binding.pluginId).add(binding.backendSessionId);
    }
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
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async {
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
          return _mapPluginProjectActivitySummaries(observation: observation);
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
  }) async {
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: observation.pluginId,
      backendSessionIds: observation.backendSessionIds.toList(growable: false),
    );

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
        final hydratedProject =
            existing ??
            ProjectDto(
              projectId: project.id,
              path: project.directory,
              createdAt: 0,
              updatedAt: 0,
              projectionUpdatedAt: 0,
            );
        if (hydratedProjectIds.contains(hydratedProject.projectId)) continue;
        final sessions = await plugin.getSessions(project.directory, start: null, limit: null);
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

  Future<ProjectDto> _persistNativeRootSessions({
    required String pluginId,
    required int generation,
    required String preferredProjectId,
    required String projectDirectory,
    required List<PluginSession> pluginSessions,
  }) async {
    final projectionUpdatedAt = captureProjectionTimestamp();
    final backendSessionIds = [for (final session in pluginSessions) session.id];
    final result = await _sessionDao.attachedDatabase.transaction(() async {
      final storedProjects = await _projectsDao.getAllProjects();
      final existingProject = _projectCatalogIdentityCalculator.calculate(
        projectsById: {
          for (final project in storedProjects) project.projectId: project,
        },
        projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
          projects: storedProjects,
        ),
        preferredProjectId: preferredProjectId,
        observedPath: projectDirectory,
      );
      final hydratedProject =
          existingProject ??
          ProjectDto(
            projectId: preferredProjectId,
            path: projectDirectory,
            createdAt: 0,
            updatedAt: 0,
            projectionUpdatedAt: 0,
          );
      await _projectsDao.insertProjectIfMissing(
        projectId: hydratedProject.projectId,
        path: projectDirectory,
      );
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
          updatedAt: session.time?.updated ?? existingBinding?.updatedAt ?? projectionUpdatedAt,
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
    _publishBindingsCommitted(
      pluginId: pluginId,
      generation: generation,
      kind: SessionBindingCommitKind.catalogSync,
      backendSessionIds: result.committedByBackendId.keys.toList(growable: false),
    );
    return result.project;
  }

  PluginSessionVariant? _toPluginVariant(SessionVariant? variant) {
    return switch (variant) {
      SessionVariant(:final id) => PluginSessionVariant(id: id),
      null => null,
    };
  }

  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async {
    final row = await _sessionDao.getSession(sessionId: sessionId);
    if (row == null || row.projectId != projectId) return null;
    return (await _mapCatalogSessions(rows: [row])).single;
  }

  Future<String?> findProjectIdForSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.projectId;
  }

  Future<void> notifySessionArchived({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.archiveSession,
    );
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.archiveSession,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.archiveSession(sessionId: binding.backendSessionId);
      },
    );
  }

  Future<void> abortSession({required String sessionId}) async {
    final binding = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.abortSession,
    );
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.abortSession,
      body: (plugin) {
        _primeDerivedSessionDirectory(binding: binding, plugin: plugin);
        return plugin.abortSession(sessionId: binding.backendSessionId);
      },
    );
  }

  Future<SessionStatusResponse> getSessionStatuses() async {
    final results = await Future.wait(
      _runtime.eligiblePluginIds.map((pluginId) async {
        try {
          final pluginStatuses = await _runtime.useIfActive(
            pluginId: pluginId,
            operation: SessionOperation.getSessionStatuses,
            body: (plugin, _) => plugin.getSessionStatuses().timeout(_aggregateSourceDeadline),
          );
          if (pluginStatuses == null) return (pluginId: pluginId, statuses: null);
          final bindings = await _sessionDao.getSessionsByBackendIds(
            pluginId: pluginId,
            backendSessionIds: pluginStatuses.keys.toList(growable: false),
          );
          return (
            pluginId: pluginId,
            statuses: {
              for (final entry in pluginStatuses.entries)
                if (bindings[entry.key] case final binding?) binding.sessionId: entry.value.toSharedSessionStatus(),
            },
          );
        } on Object {
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

  Future<List<Session>> enrichSessions({required List<Session> sessions}) async {
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);

    final (dbSessions, prsBySessionId) = await (
      _sessionDao.getSessionsByIds(sessionIds: sessionIds),
      _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds),
    ).wait;

    final pullRequestsBySessionId = <String, PullRequestInfo>{};
    for (final session in sessions) {
      final selectedPr = _selectBestPr(prsBySessionId[session.id]);
      if (selectedPr != null) {
        pullRequestsBySessionId[session.id] = pullRequestInfoFromDto(selectedPr);
      }
    }

    return [
      for (final session in sessions)
        enrichSharedSession(
          session: session,
          storedSession: dbSessions[session.id],
          pullRequest: pullRequestsBySessionId[session.id],
          unseenCalculator: _unseenCalculator,
          // Only the owning bridge-derived plugin cedes project attribution to
          // the stored row; a native backend's reported projectID is authoritative.
          adoptStoredProjectId: _bridgeDerivedProjectPluginIds.contains(
            dbSessions[session.id]?.pluginId ?? session.pluginId,
          ),
        ),
    ];
  }

  Future<List<Session>> _mapCatalogSessions({required List<SessionDto> rows}) async {
    final sessionIds = [for (final row in rows) row.sessionId];
    final prsBySessionId = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
    return [
      for (final row in rows)
        _sessionCatalogMapper.map(
          row: row,
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
    if (await _sessionDao.getSession(sessionId: sessionId) == null) {
      throw PluginOperationException.notFound(
        SessionOperation.getChildSessions.name,
        message: "session $sessionId was not found",
      );
    }
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
    return _projectsDao.getResolvedPath(projectId: projectId);
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
    required int generation,
    required Session observed,
    required bool updateCatalogTitle,
    required int projectionUpdatedAt,
  }) async {
    return _runtime.commitCurrentGeneration(
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
          updatedAt: observed.time?.updated ?? binding.updatedAt,
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
    return _runtime.commitCurrentGeneration(
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
            updatedAt: observed.time?.updated ?? existing.updatedAt,
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
        final sessionId = await _allocateSessionId();
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

  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _requireBinding(sessionId: sessionId, operation: operation);
    return _runtime.use(
      pluginId: binding.pluginId,
      operation: operation,
      body: (_) async => binding.toStoredSession(),
    );
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

  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) {
    return _runtime.use(
      pluginId: pluginId,
      operation: operation,
      body: (_) async {},
    );
  }

  Future<SessionDto> _requireBinding({
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
    required int generation,
    required SessionBindingCommitKind kind,
    required List<String> backendSessionIds,
  }) {
    if (backendSessionIds.isEmpty || _bindingCommitsController.isClosed) return;
    _bindingCommitsController.add((
      pluginId: pluginId,
      generation: generation,
      kind: kind,
      backendSessionIds: List<String>.unmodifiable(backendSessionIds),
    ));
  }

  Set<String> _tombstonesFor(String pluginId) {
    return _tombstonedBackendSessionIds.putIfAbsent(pluginId, () => <String>{});
  }

  PersistedSessionCleanupApi _requirePersistedSessionCleanupApi({
    required String pluginId,
    required BridgePluginApi? plugin,
  }) {
    if (plugin case final PersistedSessionCleanupApi cleanupApi) return cleanupApi;
    throw StateError('Plugin "$pluginId" does not support persisted session cleanup');
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

class _PluginActivityObservation {
  const _PluginActivityObservation({
    required this.pluginId,
    required this.summaries,
    required this.backendSessionIds,
    required this.hydrations,
  });

  final String pluginId;
  final List<PluginProjectActivitySummary> summaries;
  final Set<String> backendSessionIds;
  final List<_ActiveRootHydration> hydrations;
}

class _ActiveRootHydration {
  const _ActiveRootHydration({
    required this.summaryId,
    required this.preferredProjectId,
    required this.projectDirectory,
    required this.sessions,
  });

  final String summaryId;
  final String preferredProjectId;
  final String projectDirectory;
  final List<PluginSession> sessions;
}
