import "package:drift/drift.dart";

import "../database.dart";
import "../tables/session_table.dart";

part "session_dao.g.dart";

@DriftAccessor(tables: [SessionTable])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.attachedDatabase);

  /// Inserts a session → worktree mapping.
  Future<void> insertMapping({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) async {
    await into(sessionTable).insert(
      SessionTableCompanion.insert(
        sessionId: sessionId,
        projectId: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
      ),
    );
  }

  /// Returns the worktree record for the given session, or null if not found.
  Future<SessionDto?> getWorktreeForSession({required String sessionId}) async {
    return (select(sessionTable)..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  /// Deletes the worktree mapping for the given session. No-op if not found.
  Future<void> deleteSession({required String sessionId}) async {
    await (delete(sessionTable)..where((t) => t.sessionId.equals(sessionId))).go();
  }
}
