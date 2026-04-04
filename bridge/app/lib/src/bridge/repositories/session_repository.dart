import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/pull_request_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../api/database/tables/pull_requests_table.dart";
import "../repositories/mappers/plugin_session_mapper.dart";
import "../repositories/mappers/pull_request_mapper.dart";
import "../repositories/models/stored_session.dart";

class SessionRepository {
  final BridgePlugin _plugin;
  final SessionDao _sessionDao;
  final PullRequestDao _pullRequestDao;

  SessionRepository({
    required BridgePlugin plugin,
    required SessionDao sessionDao,
    required PullRequestDao pullRequestDao,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _pullRequestDao = pullRequestDao;

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

    final sessions = pluginSessions.map((s) => s.toSharedSession()).toList();
    final sessionIds = sessions.map((s) => s.id).toList();

    final (dbSessions, prsBySessionId) = await (
      _sessionDao.getSessionsByIds(sessionIds: sessionIds),
      _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds),
    ).wait;

    return sessions.map((session) {
      var result = session;

      final dbSession = dbSessions[session.id];
      if (dbSession != null) {
        final currentTime = session.time;
        final mergedTime = currentTime != null
            ? currentTime.copyWith(archived: dbSession.archivedAt)
            : SessionTime(created: 0, updated: 0, archived: dbSession.archivedAt);
        result = result.copyWith(time: mergedTime);
      }

      final pr = _selectBestPr(prsBySessionId[session.id]);
      if (pr != null) {
        result = result.copyWith(pullRequest: pullRequestInfoFromDto(pr));
      }

      return result;
    }).toList();
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

      final selectedIsOpen = selected.state.toUpperCase() == "OPEN";
      final currentIsOpen = pr.state.toUpperCase() == "OPEN";

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
    return pluginSessions.map((s) => s.toSharedSession()).toList();
  }

  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions
        .map((session) => StoredSession(id: session.sessionId, branchName: session.branchName))
        .toList(growable: false);
  }

  Future<String?> getProjectPath({required String projectId}) async {
    try {
      final project = await _plugin.getProject(projectId);
      if (project.id.isEmpty) {
        return null;
      }
      return project.id;
    } catch (_) {
      return null;
    }
  }
}
