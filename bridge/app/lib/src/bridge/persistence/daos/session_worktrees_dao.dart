import "package:drift/drift.dart";

import "../database.dart";
import "../tables/session_worktrees_table.dart";

part "session_worktrees_dao.g.dart";

@DriftAccessor(tables: [SessionWorktreesTable])
class SessionWorktreesDao extends DatabaseAccessor<AppDatabase> with _$SessionWorktreesDaoMixin {
  SessionWorktreesDao(super.attachedDatabase);

  /// Inserts a session → worktree mapping.
  Future<void> insertMapping({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) async {
    await into(sessionWorktreesTable).insert(
      SessionWorktreesTableCompanion.insert(
        sessionId: sessionId,
        projectId: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
      ),
    );
  }

  /// Returns the worktree record for the given session, or null if not found.
  Future<SessionWorktree?> getWorktreeForSession({required String sessionId}) async {
    return (select(sessionWorktreesTable)..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  /// Deletes the worktree mapping for the given session. No-op if not found.
  Future<void> deleteMapping({required String sessionId}) async {
    await (delete(sessionWorktreesTable)..where((t) => t.sessionId.equals(sessionId))).go();
  }
}
