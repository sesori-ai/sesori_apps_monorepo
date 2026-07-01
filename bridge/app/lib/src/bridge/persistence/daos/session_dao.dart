import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../database.dart";
import "../tables/session_table.dart";

part "session_dao.g.dart";

@DriftAccessor(tables: [SessionTable])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
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
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    // Mirrors the column's DB default; production callers (SessionRepository,
    // SessionPersistenceService) pass the active plugin id explicitly.
    String pluginId = "opencode",
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
        lastAgent: Value(lastAgent),
        lastAgentModel: Value(lastAgentModel),
        createdAt: Value(createdAt),
        pluginId: Value(pluginId),
      ),
    );
  }

  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        lastAgent: Value(agent),
        lastAgentModel: Value(agentModel),
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

  Future<List<SessionDto>> getSessionsByProject({required String projectId}) async {
    return (select(sessionTable)..where((t) => t.projectId.equals(projectId))).get();
  }

  /// The worktree→project links the bridge recorded for [pluginId]: every
  /// session created inside a dedicated worktree, as its worktree directory and
  /// the project the user actually opened. A bridge-derived plugin reports each
  /// session under its own cwd (the worktree path), so the derivation uses these
  /// rows to fold a worktree's sessions back under their parent project instead
  /// of spawning a project per worktree.
  Future<List<({String worktreePath, String projectId})>> getWorktreeProjectPaths({
    required String pluginId,
  }) async {
    final rows = await (select(sessionTable)
          ..where((t) => t.worktreePath.isNotNull() & t.pluginId.equals(pluginId)))
        .get();
    return [
      for (final row in rows)
        if (row.worktreePath case final worktreePath?) (worktreePath: worktreePath, projectId: row.projectId),
    ];
  }

  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds}) async {
    if (sessionIds.isEmpty) {
      return <String, SessionDto>{};
    }

    final sessions = await (select(sessionTable)..where((t) => t.sessionId.isIn(sessionIds))).get();
    return <String, SessionDto>{for (final session in sessions) session.sessionId: session};
  }

  Future<List<SessionDto>> getOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async {
    if (worktreePath == null && branchName == null) return [];

    return (select(sessionTable)..where((t) {
          final base = t.sessionId.equals(sessionId).not() & t.projectId.equals(projectId) & t.archivedAt.isNull();

          final sharingCondition = switch ((worktreePath, branchName)) {
            (final wt?, final br?) => t.worktreePath.equals(wt) | t.branchName.equals(br),
            (final wt?, null) => t.worktreePath.equals(wt),
            (null, final br?) => t.branchName.equals(br),
            (null, null) => throw StateError("unreachable"), // guarded by early return above
          };

          return base & sharingCondition;
        }))
        .get();
  }

  /// Inserts a placeholder session row if none exists for [sessionId].
  /// Preserves all fields of existing rows — uses InsertMode.insertOrIgnore.
  /// Placeholders are non-dedicated by default and have no worktree/branch state.
  /// Use this to persist plugin-sourced sessions so FK constraints (post-v5) hold.
  ///
  /// [archivedAt] is written explicitly (including null) so that plugin-sourced
  /// archive state is preserved on first insert. Existing rows are never updated.
  Future<void> insertSessionsIfMissing({
    required List<({String sessionId, String projectId, int createdAt, int? archivedAt})> sessions,
    // Mirrors the column's DB default; production callers pass the active id.
    String pluginId = "opencode",
  }) async {
    if (sessions.isEmpty) return;
    await batch((b) {
      b.insertAll(
        sessionTable,
        [
          for (final s in sessions)
            SessionTableCompanion(
              sessionId: Value(s.sessionId),
              projectId: Value(s.projectId),
              // isDedicated hardcoded false — placeholders are non-dedicated by default.
              // Callers (plugin-sourced sessions) never have meaningful worktree state.
              isDedicated: const Value(false),
              createdAt: Value(s.createdAt),
              archivedAt: Value(s.archivedAt),
              pluginId: Value(pluginId),
              // worktreePath, branchName, baseBranch, baseCommit intentionally
              // omitted — they default to absent (null) via SessionTableCompanion
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> deleteSession({required String sessionId}) async {
    await (delete(sessionTable)..where((t) => t.sessionId.equals(sessionId))).go();
  }
}
