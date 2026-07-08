import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../database.dart";
import "../tables/projects_table.dart";
import "../tables/session_table.dart";

part "session_dao.g.dart";

/// Raw unseen-relevant columns for one session row. The unseen formula is
/// applied in the repository layer, not here.
typedef SessionUnseenRow = ({
  String sessionId,
  int? archivedAt,
  int? activityAt,
  int? seenAt,
  int? userMessageAt,
});

@DriftAccessor(tables: [SessionTable, ProjectsTable])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.attachedDatabase);

  /// Inserts a session row with full worktree state. If a placeholder row
  /// already exists for this id (e.g. a `session.created` SSE event raced ahead
  /// of the `/session/create` flow and inserted an unseen-tracking placeholder
  /// via [insertSessionsIfMissing]), this UPSERTs the worktree-bearing columns
  /// onto that row instead of throwing a duplicate-key error. The unseen-tracking
  /// timestamps and the original `created_at` set by the placeholder are left
  /// untouched.
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
    required String pluginId,
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
      onConflict: DoUpdate(
        (_) => SessionTableCompanion(
          // The create flow is authoritative for project_id: a placeholder row
          // inserted by the unseen service from a live `session.created` may be
          // keyed to the plugin-supplied (pre-canonicalization) worktree path,
          // so adopt the create flow's canonical project id here — otherwise the
          // session stays keyed to the wrong project and its unseen state would
          // not count toward the original project's aggregate. The canonical
          // project row is inserted in the same transaction, so the FK holds.
          projectId: Value(projectId),
          // Only the worktree/agent state the create flow owns — never clobber
          // created_at or the unseen timestamps that a placeholder may have set.
          worktreePath: Value(worktreePath),
          branchName: Value(branchName),
          isDedicated: Value(isDedicated),
          baseBranch: Value(baseBranch),
          baseCommit: Value(baseCommit),
          lastAgent: Value(lastAgent),
          lastAgentModel: Value(lastAgentModel),
        ),
        target: [sessionTable.sessionId],
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

  /// The stored project path for every session recorded for [pluginId], via a
  /// join from each session's projectId to its project row. This is how the
  /// bridge attributes a derive-style plugin's sessions to projects: the row
  /// the bridge wrote at creation is authoritative, so a session running in a
  /// dedicated worktree maps to the project the user opened — not to its own
  /// worktree cwd. The join keeps call sites working if project ids ever stop
  /// being the project path.
  ///
  /// Each row also carries the session's dedicated [worktreePath] (null for
  /// sessions running in the project directory itself): a directory-scoped
  /// backend enumerates a worktree session under its own cwd, so callers feed
  /// these paths into the plugin's enumeration hints.
  Future<List<({String sessionId, String projectPath, String? worktreePath})>> getSessionProjectPaths({
    required String pluginId,
  }) async {
    final query = select(sessionTable).join([
      innerJoin(projectsTable, projectsTable.projectId.equalsExp(sessionTable.projectId)),
    ])..where(sessionTable.pluginId.equals(pluginId));
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          sessionId: row.readTable(sessionTable).sessionId,
          projectPath: row.readTable(projectsTable).path,
          worktreePath: row.readTable(sessionTable).worktreePath,
        ),
    ];
  }

  // ── Unseen-changes tracking ──────────────────────────────────────────────

  /// Sets [lastActivityAt] for [sessionId], and optionally advances
  /// [lastUserMessageAt] and/or [lastSeenAt] in the same write. Each `null`
  /// argument leaves that column untouched. Affects 0 rows when the session is
  /// not persisted (e.g. a child session) — a deliberate no-op.
  Future<void> setActivityTimestamps({
    required String sessionId,
    required int activityAt,
    required int? userMessageAt,
    required int? seenAt,
  }) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        lastActivityAt: Value(activityAt),
        lastUserMessageAt: userMessageAt == null ? const Value.absent() : Value(userMessageAt),
        lastSeenAt: seenAt == null ? const Value.absent() : Value(seenAt),
      ),
    );
  }

  /// Sets [lastSeenAt] for [sessionId] (used by viewing + "Mark as Read").
  Future<void> setSeenAt({required String sessionId, required int seenAt}) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(lastSeenAt: Value(seenAt)),
    );
  }

  /// Sets ONLY [lastUserMessageAt] for [sessionId], leaving the activity and
  /// seen timestamps untouched.
  Future<void> setUserMessageAt({required String sessionId, required int userMessageAt}) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(lastUserMessageAt: Value(userMessageAt)),
    );
  }

  /// Forces [sessionId] into an unseen state for an explicit "Mark as Unread":
  /// stamps activity at [activityAt] and seen just before it, so
  /// `activity > max(userMessage, seen)` holds regardless of prior state.
  /// `last_user_message_at` is intentionally left untouched (kept pure).
  Future<void> forceUnseen({required String sessionId, required int activityAt}) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        lastActivityAt: Value(activityAt),
        lastSeenAt: Value(activityAt - 1),
      ),
    );
  }

  /// Returns the unseen-relevant columns for every session in [projectId].
  /// The repository applies the unseen formula; the DAO stays query-only.
  Future<List<SessionUnseenRow>> getUnseenRowsForProject({required String projectId}) async {
    final rows = await (select(sessionTable)..where((t) => t.projectId.equals(projectId))).get();
    return [for (final r in rows) _toUnseenRow(r)];
  }

  /// Batched variant of [getUnseenRowsForProject]: returns the unseen-relevant
  /// columns for every session across all of [projectIds], grouped by project,
  /// in a single query (avoids N+1 for the `/projects` aggregate).
  Future<Map<String, List<SessionUnseenRow>>> getUnseenRowsForProjects({
    required List<String> projectIds,
  }) async {
    if (projectIds.isEmpty) return const {};
    final rows = await (select(sessionTable)..where((t) => t.projectId.isIn(projectIds))).get();
    final grouped = <String, List<SessionUnseenRow>>{};
    for (final r in rows) {
      (grouped[r.projectId] ??= <SessionUnseenRow>[]).add(_toUnseenRow(r));
    }
    return grouped;
  }

  static SessionUnseenRow _toUnseenRow(SessionDto r) => (
    sessionId: r.sessionId,
    archivedAt: r.archivedAt,
    activityAt: r.lastActivityAt,
    seenAt: r.lastSeenAt,
    userMessageAt: r.lastUserMessageAt,
  );

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
    required String pluginId,
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

  /// Deletes every persisted row for [projectId] AND [pluginId] whose session
  /// id is NOT in [keepSessionIds] and whose `created_at` is strictly before
  /// [createdBefore], returning the ids of the rows that were deleted. Used to
  /// reconcile rows for sessions that vanished from the authoritative list
  /// (deleted while offline / backend-side). Only safe when [keepSessionIds]
  /// is the COMPLETE list for the project.
  ///
  /// Scoped to [pluginId] because the authoritative list comes from the active
  /// plugin: rows another plugin recorded for the same project are legitimately
  /// absent from it and must never be reconciled away.
  ///
  /// [createdBefore] (the wall-clock time the `/sessions` fetch started) guards
  /// against deleting a session that was created AFTER the snapshot was taken
  /// (e.g. a concurrent `/session/create`): such a row is legitimately absent
  /// from the stale snapshot but must be kept.
  Future<List<String>> deleteSessionsForProjectNotIn({
    required String projectId,
    required List<String> keepSessionIds,
    required int createdBefore,
    required String pluginId,
  }) async {
    final rows =
        await (delete(sessionTable)..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.pluginId.equals(pluginId) &
                  t.sessionId.isNotIn(keepSessionIds) &
                  t.createdAt.isSmallerThanValue(createdBefore),
            ))
            .goAndReturn();
    return [for (final row in rows) row.sessionId];
  }
}
