import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PluginActiveSession,
        PluginOperationException,
        PluginSession,
        PluginSessionVariant;
import "package:sesori_shared/sesori_shared.dart"
    show
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

class SessionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();
  static const SessionCatalogMapper _sessionCatalogMapper = SessionCatalogMapper();

  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final PullRequestDao _pullRequestDao;
  final SessionUnseenCalculator _unseenCalculator;
  final Set<String> _tombstonedBackendSessionIds = <String>{};
  final Set<String> _deletedSessionIds = <String>{};
  Future<void>? _tombstoneLoad;
  bool _tombstonesLoaded = false;

  SessionRepository({
    required BridgePluginApi plugin,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required PullRequestDao pullRequestDao,
    required SessionUnseenCalculator unseenCalculator,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _pullRequestDao = pullRequestDao,
       _unseenCalculator = unseenCalculator;

  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final projectionUpdatedAt = DateTime.now().millisecondsSinceEpoch;
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
      final existingBySessionId = await _sessionDao.getSessionsByIds(
        sessionIds: backendSessionIds,
      );
      final tombstoned = await _sessionDao.getTombstonedSessionIds(
        pluginId: _plugin.id,
      );
      final observedRoots = <ObservedRootSession>[];
      for (final session in pluginSessions) {
        if (tombstoned.contains(session.id)) continue;
        final existingBinding = existingByBackendId[session.id];
        final occupiedSessionId = existingBySessionId[session.id];
        if (existingBinding == null && occupiedSessionId != null) {
          Log.w(
            "Skipping ${_plugin.id} session ${session.id}: its stable id is already bound to "
            "${occupiedSessionId.pluginId}/${occupiedSessionId.backendSessionId}",
          );
          continue;
        }
        observedRoots.add((
          sessionId: existingBinding?.sessionId ?? session.id,
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

  Future<Session> enrichPluginEventSessionJson({required Map<String, dynamic> sessionJson}) {
    return enrichSession(
      session: Session.fromJson(sessionJson).copyWith(pluginId: _plugin.id),
    );
  }

  Future<Session> createSession({
    required String pluginId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
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
    return created.toSharedSessionWithId(sessionId: created.id, pluginId: pluginId);
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
    final binding = await _resolveSessionTargetAllowingRowlessChild(
      sessionId: sessionId,
      operation: SessionOperation.getSessionMessages,
    );
    if (binding != null) await _primeDerivedSessionDirectory(binding: binding);
    final pluginMessages = await _plugin.getSessionMessages(binding?.backendSessionId ?? sessionId);
    return pluginMessages.toSharedMessageWithParts(sessionId: binding?.sessionId ?? sessionId);
  }

  /// Persists the bridge-owned title override. Null removes the override so
  /// later reads fall back to the latest observed catalog title.
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    if (await _sessionDao.getSession(sessionId: sessionId) == null) return false;
    await _sessionDao.setTitle(
      sessionId: sessionId,
      title: title,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
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
    switch (_plugin) {
      case NativeProjectsPluginApi():
        return [
          for (final summary in summaries)
            ProjectActivitySummary(
              id: summary.id,
              activeSessions: [
                for (final active in summary.activeSessions) active.toSharedActiveSession(),
              ],
            ),
        ];
      case final BridgeDerivedProjectsPluginApi plugin:
        final rows = await _sessionDao.getSessionProjectPaths(pluginId: plugin.id);
        final projectPathBySessionId = {for (final row in rows) row.backendSessionId: row.projectPath};
        // Regroup under the stored attribution — the same rule the REST path's
        // DerivedSessionBuilder/DerivedProjectBuilder apply. A rowless session
        // keeps the plugin's own grouping.
        final byProject = <String, List<PluginActiveSession>>{};
        for (final summary in summaries) {
          for (final active in summary.activeSessions) {
            final target = normalizeProjectDirectory(
              directory: projectPathBySessionId[active.id] ?? summary.id,
            );
            (byProject[target] ??= []).add(active);
          }
        }
        return [
          for (final entry in byProject.entries)
            ProjectActivitySummary(
              id: entry.key,
              activeSessions: [
                for (final active in entry.value) active.toSharedActiveSession(),
              ],
            ),
        ];
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
    final binding = await _resolveSessionTargetAllowingRowlessChild(
      sessionId: sessionId,
      operation: SessionOperation.abortSession,
    );
    return _plugin.abortSession(sessionId: binding?.backendSessionId ?? sessionId);
  }

  Future<SessionStatusResponse> getSessionStatuses() async {
    final pluginStatuses = await _plugin.getSessionStatuses();
    final (bindings, tombstoned) = await (
      _sessionDao.getSessionsByBackendIds(
        pluginId: _plugin.id,
        backendSessionIds: pluginStatuses.keys.toList(growable: false),
      ),
      _sessionDao.getTombstonedSessionIds(pluginId: _plugin.id),
    ).wait;
    return SessionStatusResponse(
      statuses: {
        for (final entry in pluginStatuses.entries)
          if (bindings[entry.key] case final binding?) binding.sessionId: entry.value.toSharedSessionStatus(),
        // COMPATIBILITY 2026-07-16 (v1.5.0): OpenCode exposes identity-preserving child ids without durable bridge rows. Remove this passthrough when child bindings translate every status key.
        for (final entry in pluginStatuses.entries)
          if (_plugin.supportsIdentityPreservingRowlessChildSessions &&
              bindings[entry.key] == null &&
              !tombstoned.contains(entry.key))
            entry.key: entry.value.toSharedSessionStatus(),
      },
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

    return enrichSharedSessions(
      sessions: sessions,
      storedSessionsById: dbSessions,
      pullRequestsBySessionId: pullRequestsBySessionId,
      unseenCalculator: _unseenCalculator,
      // Only a bridge-derived plugin cedes project attribution to the stored
      // row; a native backend's reported projectID is authoritative.
      adoptStoredProjectId: _plugin is BridgeDerivedProjectsPluginApi,
    );
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
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
      final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
      if (tombstoned.contains(sessionId)) {
        throw PluginOperationException.notFound(
          SessionOperation.getChildSessions.name,
          message: "session $sessionId was deleted",
        );
      }
      final pluginSessions = await plugin.getChildSessions(sessionId);
      return pluginSessions.where((session) => !tombstoned.contains(session.id)).toSharedSessions(pluginId: _plugin.id);
    }
    final pluginSessions = await _plugin.getChildSessions(sessionId);
    return pluginSessions.toSharedSessions(pluginId: _plugin.id);
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
    );
  }

  Future<void> unarchiveStoredSession({required String sessionId}) {
    return _sessionDao.clearArchived(
      sessionId: sessionId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
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

  Future<SessionDto?> _resolveSessionTargetAllowingRowlessChild({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding != null) {
      ensurePluginAvailable(pluginId: binding.pluginId, operation: operation);
      return binding;
    }
    // COMPATIBILITY 2026-07-16 (v1.5.0): OpenCode exposes identity-preserving child ids without durable bridge rows. Remove this fallback when child bindings resolve every targeted operation.
    if (_plugin.supportsIdentityPreservingRowlessChildSessions && !await isSessionTombstoned(sessionId: sessionId)) {
      return null;
    }
    throw PluginOperationException.notFound(
      operation.name,
      message: "session $sessionId was not found",
    );
  }
}
