import "package:drift/drift.dart";

import "../../routing/get_sessions_handler.dart";
import "../database.dart";
import "../tables/session_table.dart";

part "session_dao.g.dart";

@DriftAccessor(tables: [SessionTable])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin implements SessionDaoLike {
  SessionDao(super.attachedDatabase);

  Future<void> insertSession({
    required String sessionId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
  }) async {
    await into(sessionTable).insert(
      SessionTableCompanion(
        sessionId: Value(sessionId),
        projectId: Value(projectId),
        worktreePath: Value(worktreePath),
        branchName: Value(branchName),
        isDedicated: Value(isDedicated),
        archivedAt: const Value(null),
        baseBranch: Value(baseBranch),
        baseCommit: Value(baseCommit),
        createdAt: Value(createdAt),
      ),
    );
  }

  Future<SessionDto?> getSession({required String sessionId}) async {
    return (select(sessionTable)..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  Future<void> setArchived({required String sessionId, required int archivedAt}) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(archivedAt: Value(archivedAt)),
    );
  }

  Future<void> clearArchived({required String sessionId}) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      const SessionTableCompanion(archivedAt: Value(null)),
    );
  }

  @override
  Future<List<SessionDto>> getSessionsByProject({required String projectId}) async {
    return (select(sessionTable)..where((t) => t.projectId.equals(projectId))).get();
  }

  @override
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds}) async {
    if (sessionIds.isEmpty) {
      return <String, SessionDto>{};
    }

    final sessions = await (select(sessionTable)..where((t) => t.sessionId.isIn(sessionIds))).get();
    return <String, SessionDto>{for (final session in sessions) session.sessionId: session};
  }

  Future<void> deleteSession({required String sessionId}) async {
    await (delete(sessionTable)..where((t) => t.sessionId.equals(sessionId))).go();
  }
}
