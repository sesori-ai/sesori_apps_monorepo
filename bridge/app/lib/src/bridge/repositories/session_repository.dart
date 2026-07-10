import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PluginActiveSession,
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
        SessionVariant;

import "../api/database/tables/pull_requests_table.dart";
import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "derived_session_builder.dart";
import "mappers/plugin_activity_summary_mapper.dart";
import "mappers/plugin_command_mapper.dart";
import "mappers/plugin_message_mapper.dart";
import "mappers/plugin_session_mapper.dart";
import "mappers/prompt_part_mapper.dart";
import "mappers/pull_request_mapper.dart";
import "models/project_not_found_exception.dart";
import "models/stored_session.dart";
import "pull_request_repository.dart";
import "session_unseen_calculator.dart";

class SessionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();

  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final PullRequestRepository _pullRequestRepository;
  final SessionUnseenCalculator _unseenCalculator;

  SessionRepository({
    required BridgePluginApi plugin,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required PullRequestRepository pullRequestRepository,
    required SessionUnseenCalculator unseenCalculator,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _pullRequestRepository = pullRequestRepository,
       _unseenCalculator = unseenCalculator;

  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final pluginSessions = await _pluginSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
    );

    return enrichSessions(sessions: pluginSessions.toSharedSessions());
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
        final sessionProjectPaths = await _sessionDao.getSessionProjectPaths(pluginId: plugin.id);
        final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
        final allSessions = await plugin.listAllSessions(
          knownDirectories: _knownDirectories(
            sessionProjectPaths: sessionProjectPaths,
            projectId: projectId,
          ),
        );
        final scoped = _derivedSessionBuilder.build(
          projectId: projectId,
          // A backend without session deletion keeps enumerating deleted
          // sessions forever — the tombstones filter them out.
          sessions: allSessions.where((s) => !tombstoned.contains(s.id)).toList(growable: false),
          projectPathBySessionId: {
            for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
          },
        );

        final from = start ?? 0;
        if (from >= scoped.length) return const [];
        final until = limit == null ? scoped.length : (from + limit).clamp(0, scoped.length);
        return scoped.sublist(from, until);
    }
  }

  /// The enumeration hints for a derive-style plugin: every stored project
  /// path and dedicated-worktree path the bridge attributes to it, plus the
  /// [projectId] being served (which may not have a stored session yet).
  static Set<String> _knownDirectories({
    required List<({String sessionId, String projectPath, String? worktreePath})> sessionProjectPaths,
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
    return enrichSession(session: pluginSession.toSharedSession());
  }

  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) {
    return enrichSession(session: Session.fromJson(sessionJson));
  }

  Future<Session> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
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
    return created.toSharedSession();
  }

  Future<Session> renameSession({required String sessionId, required String title}) async {
    final updated = await _plugin.renameSession(sessionId: sessionId, title: title);
    return updated.toSharedSession();
  }

  Future<CommandListResponse> getCommands({required String? projectId}) async {
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
    await _primeDerivedSessionDirectory(sessionId: sessionId);
    return _plugin.sendCommand(
      sessionId: sessionId,
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
    await _primeDerivedSessionDirectory(sessionId: sessionId);
    return _plugin.sendPrompt(
      sessionId: sessionId,
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
    await _primeDerivedSessionDirectory(sessionId: sessionId);
    final pluginMessages = await _plugin.getSessionMessages(sessionId);
    return pluginMessages.toSharedMessageWithParts();
  }

  /// Persists the bridge's title copy for a derived-plugin session. Null
  /// removes the copy, so later reads fall back to the backend title. No-op for native plugins, whose backends persist their own
  /// titles (a stored copy would go stale), and for rowless sessions.
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    if (_plugin is! BridgeDerivedProjectsPluginApi) return true;
    if (await _sessionDao.getSession(sessionId: sessionId) == null) return false;
    await _sessionDao.setTitle(sessionId: sessionId, title: title);
    return true;
  }

  Future<bool> isSessionTombstoned({required String sessionId}) {
    return _sessionDao.isSessionTombstoned(sessionId: sessionId, pluginId: _plugin.id);
  }

  /// Records a delete tombstone and removes the stored row atomically. The
  /// tombstone is written even for rowless sessions because a backend without
  /// session deletion may still enumerate them.
  Future<void> deleteSession({required String sessionId}) async {
    await _sessionDao.transaction(() async {
      await _sessionDao.insertSessionTombstone(
        sessionId: sessionId,
        pluginId: _plugin.id,
        deletedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _sessionDao.deleteSession(sessionId: sessionId);
    });
  }

  /// Feeds a derived plugin the bridge's stored session→directory attribution
  /// (the dedicated worktree path, else the owning project directory — which
  /// for derived plugins IS the canonical path) before an operation that
  /// carries only a session id. No-op for native plugins and rowless sessions.
  Future<void> _primeDerivedSessionDirectory({required String sessionId}) async {
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
      final stored = await _sessionDao.getSession(sessionId: sessionId);
      if (stored == null) return;
      plugin.primeSessionDirectory(
        sessionId: sessionId,
        directory: stored.worktreePath ?? stored.projectId,
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
    final summaries = _plugin.getActiveSessionsSummary();
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
        final projectPathBySessionId = {for (final row in rows) row.sessionId: row.projectPath};
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
    final pluginSession = await _getPluginSession(projectId: projectId, sessionId: sessionId);
    if (pluginSession == null) {
      return null;
    }
    return enrichPluginSession(pluginSession: pluginSession);
  }

  Future<String?> findProjectIdForSession({required String sessionId}) async {
    final storedSession = await _sessionDao.getSession(sessionId: sessionId);
    if (storedSession != null) {
      return storedSession.projectId;
    }

    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        // A deleted session must not resolve, even though a backend without
        // session deletion still enumerates it.
        final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
        if (tombstoned.contains(sessionId)) return null;
        // No stored row means the bridge did not create this session (every
        // bridge-created session — worktree ones included — is persisted with
        // its owning project and was handled above), so its own cwd IS its
        // project: resolve via the session enumeration. The hint set includes
        // every stored project row (not just the owning projects of this
        // plugin's sessions) so a rowless session in an opened-but-sessionless
        // folder is still discoverable by a directory-scoped backend.
        final (sessionProjectPaths, storedProjects) = await (
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          _projectsDao.getAllProjects(),
        ).wait;
        final sessions = await plugin.listAllSessions(
          knownDirectories: {
            ..._knownDirectories(sessionProjectPaths: sessionProjectPaths, projectId: null),
            for (final stored in storedProjects) stored.path,
          },
        );
        for (final session in sessions) {
          if (session.id == sessionId) {
            return normalizeProjectDirectory(directory: session.directory);
          }
        }
        return null;

      case final NativeProjectsPluginApi plugin:
        final projects = await plugin.getProjects();
        // The plugin's authoritative list makes these known projects. Persist
        // them before probing sessions so id→path resolution never guesses.
        await _projectsDao.insertProjectsIfMissing(
          projectIds: [for (final project in projects) project.id],
        );
        for (final project in projects) {
          final projectId = project.id;
          if (await _getPluginSession(projectId: projectId, sessionId: sessionId) != null) {
            return projectId;
          }
        }
        return null;
    }
  }

  Future<void> notifySessionArchived({required String sessionId}) {
    return _plugin.archiveSession(sessionId: sessionId);
  }

  Future<void> abortSession({required String sessionId}) {
    return _plugin.abortSession(sessionId: sessionId);
  }

  Future<List<Session>> enrichSessions({required List<Session> sessions}) async {
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);

    final (dbSessions, prsBySessionId) = await (
      _sessionDao.getSessionsByIds(sessionIds: sessionIds),
      _pullRequestRepository.getPrsBySessionIds(sessionIds: sessionIds),
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
    final pluginSessions = await _plugin.getChildSessions(sessionId);
    return pluginSessions.toSharedSessions();
  }

  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions
        .map((session) => StoredSession(id: session.sessionId, branchName: session.branchName))
        .toList(growable: false);
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

  Future<SessionDto?> getStoredSession({required String sessionId}) {
    return _sessionDao.getSession(sessionId: sessionId);
  }

  Future<void> insertStoredSession({
    required String sessionId,
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
      await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSession(
        sessionId: sessionId,
        projectId: projectId,
        isDedicated: isDedicated,
        createdAt: createdAt,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
        lastAgent: agent,
        lastAgentModel: agentModel,
        pluginId: _plugin.id,
      );
      // A live `session.created` can race ahead of this create flow and insert
      // a placeholder keyed to the plugin-reported cwd — for a dedicated
      // worktree session that's the throwaway worktree path, along with a
      // project row for it. The upsert above re-attributed the session to the
      // canonical project; drop the now-orphaned placeholder project row so it
      // can't surface as an empty derived project card. Guarded twice: only
      // when nothing else references the row, and only when the row carries no
      // user-set state (hidden/rename/base-branch/worktree counter) — a row
      // the user touched is a real project, not placeholder junk.
      final placeholderProjectId = placeholder?.projectId;
      if (placeholderProjectId != null && placeholderProjectId != projectId) {
        final (row, remaining) = await (
          db.projectsDao.getProject(projectId: placeholderProjectId),
          _sessionDao.getSessionsByProject(projectId: placeholderProjectId),
        ).wait;
        final untouched =
            row != null && !row.hidden && row.displayName == null && row.baseBranch == null && row.worktreeCounter == 0;
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

  Future<PluginSession?> _getPluginSession({required String projectId, required String sessionId}) async {
    final sessions = await _pluginSessionsForProject(projectId: projectId, start: null, limit: null);
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }
}
