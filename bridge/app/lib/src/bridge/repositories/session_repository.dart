import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin, Log;
import "package:sesori_shared/sesori_shared.dart" show PrState, PullRequestInfo, Session;

import "../api/database/tables/pull_requests_table.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "mappers/plugin_session_mapper.dart";
import "mappers/pull_request_mapper.dart";
import "models/stored_session.dart";
import "pull_request_repository.dart";

class SessionRepository {
  final BridgePlugin _plugin;
  final SessionDao _sessionDao;
  final PullRequestRepository _pullRequestRepository;

  SessionRepository({
    required BridgePlugin plugin,
    required SessionDao sessionDao,
    required PullRequestRepository pullRequestRepository,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _pullRequestRepository = pullRequestRepository;

  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final pluginSessions = await _plugin.getSessions(
      projectId,
      start: start,
      limit: limit,
    );

    return enrichSessions(sessions: pluginSessions.toSharedSessions());
  }

  Future<Session> enrichSession({required Session session}) async {
    final enrichedSessions = await enrichSessions(sessions: [session]);
    return enrichedSessions.single;
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

  Future<String?> getProjectPath({required String projectId}) async {
    try {
      final project = await _plugin.getProject(projectId);
      if (project.id.trim().isEmpty) {
        return null;
      }
      return project.id;
    } catch (e) {
      Log.w("[SessionRepository] getProjectPath failed for $projectId: $e");
      return null;
    }
  }

  Future<SessionDto?> getStoredSession({required String sessionId}) {
    return _sessionDao.getSession(sessionId: sessionId);
  }
}
