import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/dao_interfaces.dart";
import "../repositories/mappers/plugin_session_mapper.dart";
import "../repositories/mappers/pull_request_mapper.dart";
import "../repositories/models/stored_session.dart";

abstract interface class SessionRepositoryLike {
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  });

  Future<List<Session>> getChildSessions({required String sessionId});

  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId});

  Future<String?> getProjectPath({required String projectId});
}

class SessionRepository implements SessionRepositoryLike {
  final BridgePlugin _plugin;
  final SessionDaoLike _sessionDao;
  final PullRequestDaoLike _pullRequestDao;

  SessionRepository({
    required BridgePlugin plugin,
    required SessionDaoLike sessionDao,
    required PullRequestDaoLike pullRequestDao,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _pullRequestDao = pullRequestDao;

  @override
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
    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);

    final mergedSessions = sessions.map((session) {
      final dbSession = dbSessions[session.id];
      if (dbSession != null) {
        final currentTime = session.time;
        final mergedTime = currentTime != null
            ? currentTime.copyWith(archived: dbSession.archivedAt)
            : SessionTime(
                created: 0,
                updated: 0,
                archived: dbSession.archivedAt,
              );
        return session.copyWith(time: mergedTime);
      }
      return session;
    }).toList();

    final prsBySessionId = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);

    return mergedSessions.map((session) {
      final pr = prsBySessionId[session.id];
      if (pr == null) {
        return session;
      }
      return session.copyWith(pullRequest: pullRequestInfoFromDto(pr));
    }).toList();
  }

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async {
    final pluginSessions = await _plugin.getChildSessions(sessionId);
    return pluginSessions.map((s) => s.toSharedSession()).toList();
  }

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions
        .map((session) => StoredSession(id: session.sessionId, branchName: session.branchName))
        .toList(growable: false);
  }

  @override
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
