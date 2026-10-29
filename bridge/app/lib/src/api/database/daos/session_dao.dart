import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../database.dart";
import "../tables/deleted_sessions_table.dart";
import "../tables/projects_table.dart";
import "../tables/session_table.dart";

part "session_dao.g.dart";

/// Raw unseen-relevant columns for one active root session. The unseen
/// formula is applied in the repository layer, not here.
typedef SessionUnseenRow = ({
  int? activityAt,
  int? seenAt,
  int? userMessageAt,
});

typedef ObservedRootSession = ({
  String sessionId,
  String backendSessionId,
  String projectId,
  String directory,
  String? catalogTitle,
  int createdAt,
  int updatedAt,
  int? archivedAt,
  int projectionUpdatedAt,
});

/// Where a session page continues: the last row's sort time and id.
typedef SessionPageKey = ({int sortAt, String sessionId});

/// A search word and the projects whose own name holds it, so their sessions
/// match the word whatever their title.
typedef SessionPageWord = ({String word, List<String> projectIds});

typedef SessionPageRows = ({
  List<SessionDto> rows,
  SessionPageKey? nextKey,
  ({int all, int running, int unread}) counts,
});

typedef SessionProjectPathRow = ({
  String sessionId,
  String backendSessionId,
  String projectPath,
  String? worktreePath,
  String directory,
});

@DriftAccessor(tables: [SessionTable, ProjectsTable, DeletedSessionsTable])
class SessionDao(super.attachedDatabase) extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  static const _ownerIdentity = "local";
  static const _writeBatchSize = 500;

  /// Sets the bridge-owned title copy for [sessionId] (null removes the copy).
  /// No-op for rowless sessions.
  Future<void> setTitle({
    required String sessionId,
    required String? title,
    required int updatedAt,
    required int projectionUpdatedAt,
  }) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        title: Value(title),
        updatedAt: Value(updatedAt),
        projectionUpdatedAt: Value(projectionUpdatedAt),
      ),
    );
  }

  /// Sets the approval override for [sessionId] (null clears it). Returns
  /// whether a row was written.
  Future<bool> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    final updatedRows = await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(approvalOverride: Value(approvalOverride)),
    );
    return updatedRows == 1;
  }

  Future<bool> hasApprovalOverride({required SessionApprovalMode approvalOverride}) async {
    final query = selectOnly(sessionTable)
      ..addColumns([sessionTable.sessionId])
      ..where(sessionTable.approvalOverride.equalsValue(approvalOverride))
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  Future<bool> setTitleIfNull({
    required String sessionId,
    required String title,
    required int updatedAt,
    required int projectionUpdatedAt,
  }) async {
    final updatedRows =
        await (update(sessionTable)..where((table) => table.sessionId.equals(sessionId) & table.title.isNull())).write(
          SessionTableCompanion(
            title: Value(title),
            updatedAt: Value(updatedAt),
            projectionUpdatedAt: Value(projectionUpdatedAt),
          ),
        );
    return updatedRows == 1;
  }

  /// Records a delete tombstone for [backendSessionId]. Idempotent — re-deleting an
  /// already-tombstoned session keeps the original timestamp.
  Future<void> insertSessionTombstone({
    required String backendSessionId,
    required String pluginId,
    required int deletedAt,
  }) async {
    await into(deletedSessionsTable).insert(
      DeletedSessionsTableCompanion.insert(
        ownerIdentity: const Value(_ownerIdentity),
        backendSessionId: backendSessionId,
        pluginId: pluginId,
        deletedAt: deletedAt,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The tombstoned session ids for [pluginId] — sessions the user deleted
  /// that a backend without session deletion would otherwise keep listing.
  Future<Set<String>> getTombstonedSessionIds({required String pluginId}) async {
    final query = select(deletedSessionsTable)
      ..where((t) => t.ownerIdentity.equals(_ownerIdentity) & t.pluginId.equals(pluginId));
    final rows = await query.get();
    return {for (final row in rows) row.backendSessionId};
  }

  Future<bool> isSessionTombstoned({required String backendSessionId, required String pluginId}) async {
    final query = select(deletedSessionsTable)
      ..where(
        (t) =>
            t.ownerIdentity.equals(_ownerIdentity) &
            t.pluginId.equals(pluginId) &
            t.backendSessionId.equals(backendSessionId),
      );
    return await query.getSingleOrNull() != null;
  }

  /// Inserts a session row with full worktree state. If a placeholder row
  /// already exists for this id (e.g. a `session.created` SSE event raced ahead
  /// of the `/session/create` flow and inserted an unseen-tracking placeholder
  /// via [insertSessionsIfMissing]), this UPSERTs the worktree-bearing columns
  /// onto that row instead of throwing a duplicate-key error. The unseen-tracking
  /// timestamps and the original `created_at` set by the placeholder are left
  /// untouched.
  Future<void> insertSession({
    required String sessionId,
    required String backendSessionId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required bool fastMode,
    required String pluginId,
  }) async {
    final project = await (select(
      projectsTable,
    )..where((table) => table.projectId.equals(projectId))).getSingleOrNull();
    if (project == null) {
      throw StateError("Cannot insert session for unknown project $projectId");
    }
    final directory = worktreePath ?? project.path;
    await into(sessionTable).insert(
      SessionTableCompanion(
        sessionId: Value(sessionId),
        backendSessionId: Value(backendSessionId),
        projectId: Value(projectId),
        parentSessionId: const Value(null),
        directory: Value(directory),
        worktreePath: Value(worktreePath),
        branchName: const Value(null),
        isDedicated: Value(isDedicated),
        archivedAt: const Value(null),
        baseBranch: Value(baseBranch),
        baseCommit: Value(baseCommit),
        lastAgent: Value(lastAgent),
        lastAgentModel: Value(lastAgentModel),
        fastMode: Value(fastMode),
        createdAt: Value(createdAt),
        updatedAt: Value(createdAt),
        projectionUpdatedAt: Value(createdAt),
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
          directory: Value(directory),
          // Only the worktree/agent state the create flow owns — never clobber
          // created_at or the unseen timestamps that a placeholder may have set.
          worktreePath: Value(worktreePath),
          branchName: const Value(null),
          isDedicated: Value(isDedicated),
          baseBranch: Value(baseBranch),
          baseCommit: Value(baseCommit),
          lastAgent: Value(lastAgent),
          lastAgentModel: Value(lastAgentModel),
          fastMode: Value(fastMode),
        ),
        target: [sessionTable.sessionId],
      ),
    );
  }

  /// Returns the updated row, or null when [sessionId] has none.
  Future<SessionDto?> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {
    final rows = await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).writeReturning(
      SessionTableCompanion(
        lastAgent: Value(agent),
        lastAgentModel: Value(agentModel),
      ),
    );
    return rows.firstOrNull;
  }

  Future<void> updateRequestedPromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
    required bool fastMode,
  }) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        lastAgent: Value(agent),
        lastAgentModel: Value(agentModel),
        fastMode: Value(fastMode),
      ),
    );
  }

  Future<SessionDto?> getSession({required String sessionId}) async {
    return await (select(sessionTable)..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  /// Upserts the supplied rows without applying merge or import policy.
  Future<void> upsertSessionRows({required List<SessionDto> rows}) async {
    if (rows.isEmpty) return;
    for (var start = 0; start < rows.length; start += _writeBatchSize) {
      final candidateEnd = start + _writeBatchSize;
      final end = candidateEnd < rows.length ? candidateEnd : rows.length;
      await batch((batch) {
        batch.insertAllOnConflictUpdate(sessionTable, rows.sublist(start, end));
      });
    }
  }

  Future<SessionDto?> getSessionByBinding({
    required String pluginId,
    required String backendSessionId,
  }) {
    return (select(sessionTable)..where(
          (table) => table.pluginId.equals(pluginId) & table.backendSessionId.equals(backendSessionId),
        ))
        .getSingleOrNull();
  }

  Future<Map<String, SessionDto>> getSessionsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async {
    if (backendSessionIds.isEmpty) return const {};
    final rows =
        await (select(sessionTable)..where(
              (table) => table.pluginId.equals(pluginId) & table.backendSessionId.isIn(backendSessionIds),
            ))
            .get();
    return {for (final row in rows) row.backendSessionId: row};
  }

  /// Stable ids for [backendSessionIds] of one plugin, keyed by backend id; a
  /// backend id with no row is absent. Projects to the two id columns because
  /// event translation and subtask remapping never read the rest of the row.
  Future<Map<String, String>> getSessionIdsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async {
    if (backendSessionIds.isEmpty) return const {};
    final query = selectOnly(sessionTable)
      ..addColumns([sessionTable.backendSessionId, sessionTable.sessionId])
      ..where(sessionTable.pluginId.equals(pluginId) & sessionTable.backendSessionId.isIn(backendSessionIds));
    final rows = await query.get();
    return {
      for (final row in rows)
        if ((row.read(sessionTable.backendSessionId), row.read(sessionTable.sessionId)) case (
          final backendSessionId?,
          final sessionId?,
        ))
          backendSessionId: sessionId,
    };
  }

  Future<Map<String, SessionDto>> getSessionsForPlugin({required String pluginId}) async {
    final rows = await (select(sessionTable)..where((table) => table.pluginId.equals(pluginId))).get();
    return {for (final row in rows) row.backendSessionId: row};
  }

  Future<Set<String>> getSessionIdsForPlugin({required String pluginId}) async {
    final query = selectOnly(sessionTable)
      ..addColumns([sessionTable.sessionId])
      ..where(sessionTable.pluginId.equals(pluginId));
    final rows = await query.get();
    return {for (final row in rows) row.read(sessionTable.sessionId)!};
  }

  Future<Set<String>> getAllSessionIds() async {
    final query = selectOnly(sessionTable)..addColumns([sessionTable.sessionId]);
    final rows = await query.get();
    return {for (final row in rows) row.read(sessionTable.sessionId)!};
  }

  /// The distinct stored directory of every session row, archived ones
  /// included, exactly as stored.
  Future<Set<String>> getAllSessionDirectories() async {
    final query = selectOnly(sessionTable, distinct: true)..addColumns([sessionTable.directory]);
    final rows = await query.get();
    return {for (final row in rows) ?row.read(sessionTable.directory)};
  }

  Future<Map<String, SessionDto>> upsertObservedRootSessions({
    required String pluginId,
    required List<ObservedRootSession> sessions,
  }) async {
    if (sessions.isEmpty) return const {};
    await batch((batch) {
      batch.insertAll<SessionTable, SessionDto>(
        sessionTable,
        [
          for (final session in sessions)
            SessionTableCompanion(
              sessionId: Value(session.sessionId),
              backendSessionId: Value(session.backendSessionId),
              projectId: Value(session.projectId),
              parentSessionId: const Value(null),
              directory: Value(session.directory),
              isDedicated: const Value(false),
              archivedAt: Value(session.archivedAt),
              createdAt: Value(session.createdAt),
              updatedAt: Value(session.updatedAt),
              projectionUpdatedAt: Value(session.projectionUpdatedAt),
              pluginId: Value(pluginId),
              catalogTitle: Value(session.catalogTitle),
            ),
        ],
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => SessionTableCompanion.custom(
            directory: excluded.directory,
            updatedAt: excluded.updatedAt,
            projectionUpdatedAt: excluded.projectionUpdatedAt,
            catalogTitle: excluded.catalogTitle,
          ),
          target: [sessionTable.pluginId, sessionTable.backendSessionId],
          where: (old, excluded) => old.projectionUpdatedAt.isSmallerOrEqual(excluded.projectionUpdatedAt),
        ),
      );
    });
    return await getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: [for (final session in sessions) session.backendSessionId],
    );
  }

  Future<void> advanceUpdatedAt({required String sessionId, required int updatedAt}) async {
    await (update(sessionTable)..where(
          (table) => table.sessionId.equals(sessionId) & table.updatedAt.isSmallerThanValue(updatedAt),
        ))
        .write(SessionTableCompanion(updatedAt: Value(updatedAt)));
  }

  Future<bool> updateObservedSessionProjection({
    required String sessionId,
    required String directory,
    required String? catalogTitle,
    required bool updateCatalogTitle,
    required int updatedAt,
    required int projectionUpdatedAt,
  }) async {
    final updated =
        await (update(sessionTable)..where(
              (table) =>
                  table.sessionId.equals(sessionId) &
                  table.projectionUpdatedAt.isSmallerOrEqualValue(projectionUpdatedAt),
            ))
            .write(
              SessionTableCompanion(
                directory: Value(directory),
                catalogTitle: updateCatalogTitle ? Value(catalogTitle) : const Value.absent(),
                updatedAt: Value(updatedAt),
                projectionUpdatedAt: Value(projectionUpdatedAt),
              ),
            );
    return updated > 0;
  }

  Future<void> insertObservedChild({
    required String sessionId,
    required String backendSessionId,
    required String projectId,
    required String parentSessionId,
    required String directory,
    required String? catalogTitle,
    required int? archivedAt,
    required int createdAt,
    required int updatedAt,
    required int projectionUpdatedAt,
    required String pluginId,
  }) async {
    await into(sessionTable).insert(
      SessionTableCompanion(
        sessionId: Value(sessionId),
        backendSessionId: Value(backendSessionId),
        projectId: Value(projectId),
        parentSessionId: Value(parentSessionId),
        directory: Value(directory),
        isDedicated: const Value(false),
        archivedAt: Value(archivedAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        projectionUpdatedAt: Value(projectionUpdatedAt),
        pluginId: Value(pluginId),
        catalogTitle: Value(catalogTitle),
      ),
    );
  }

  Future<void> setParentSessionId({required String sessionId, required String parentSessionId}) async {
    await (update(sessionTable)..where((table) => table.sessionId.equals(sessionId))).write(
      SessionTableCompanion(parentSessionId: Value(parentSessionId)),
    );
  }

  Future<List<SessionDto>> getRootCatalogSessions({
    required String projectId,
    required int offset,
    required int? limit,
  }) {
    return (select(sessionTable)
          ..where(
            (table) => table.projectId.equals(projectId) & table.parentSessionId.isNull(),
          )
          ..orderBy([
            (table) => OrderingTerm.desc(table.updatedAt),
            (table) => OrderingTerm.desc(table.sessionId),
          ])
          ..limit(limit ?? -1, offset: offset))
        .get();
  }

  Future<List<SessionDto>> getChildCatalogSessions({
    required String parentSessionId,
  }) {
    return (select(sessionTable)
          ..where(
            (table) => table.parentSessionId.equals(parentSessionId),
          )
          ..orderBy([
            (table) => OrderingTerm.desc(table.updatedAt),
            (table) => OrderingTerm.desc(table.sessionId),
          ]))
        .get();
  }

  /// One page of root sessions in [projectIds] after [after], in display
  /// order, and the chip counts of every session the page's scope holds, read
  /// in one transaction. A [limit] of 0 reads the counts only.
  ///
  /// Active pages order by the displayed time and archived pages by
  /// `archived_at`, both newest first with ties broken by `session_id`
  /// descending. The scope is the mode's roots in [projectIds] matching every
  /// one of [words]; the [filter] narrows only the page, not the counts.
  Future<SessionPageRows> getSessionPage({
    required SessionPageMode mode,
    required List<String> projectIds,
    required List<SessionPageWord> words,
    required SessionPageFilter filter,
    required Set<String> runningIds,
    required SessionPageKey? after,
    required int limit,
  }) {
    final table = sessionTable;
    final sortKey = switch (mode) {
      SessionPageMode.active => _displayedAt,
      SessionPageMode.archived => table.archivedAt,
    };
    // The scope holds nearly every root, so one pass over the table beats an
    // index lookup per row (7x at 50,000 roots). SQLite only finds that plan
    // with ANALYZE statistics, which the bridge never gathers, so `+column`
    // keeps these terms off the indexes.
    var scope =
        _unindexed<String>(column: "project_id").isIn(projectIds) &
        _unindexed<String>(column: "parent_session_id").isNull() &
        switch (mode) {
          SessionPageMode.active => _unindexed<int>(column: "archived_at").isNull(),
          SessionPageMode.archived => _unindexed<int>(column: "archived_at").isNotNull(),
        };
    for (final (:word, :projectIds) in words) {
      // The title SessionCatalogMapper sends. SQLite's LIKE folds ASCII case
      // only; each word matches literally.
      final inTitle = coalesce([table.title, table.catalogTitle]).like("%${_escapeLike(word)}%", escapeChar: r"\");
      scope = scope & (projectIds.isEmpty ? inTitle : inTitle | table.projectId.isIn(projectIds));
    }
    final running = table.sessionId.isIn(runningIds);
    final unseen = _unseen;

    return transaction(() async {
      final all = countAll();
      final runningCount = countAll(filter: running);
      final unreadCount = countAll(filter: unseen);
      final counts =
          await (selectOnly(table)
                ..addColumns([all, runningCount, unreadCount])
                ..where(scope))
              .getSingle();
      final pageCounts = (
        all: counts.read(all) ?? 0,
        running: counts.read(runningCount) ?? 0,
        unread: counts.read(unreadCount) ?? 0,
      );
      if (limit == 0) return (rows: const <SessionDto>[], nextKey: null, counts: pageCounts);

      var where = switch (filter) {
        SessionPageFilter.all => scope,
        SessionPageFilter.running => scope & running,
        SessionPageFilter.unread => scope & unseen,
      };
      if (after case (:final sortAt, :final sessionId)) {
        where =
            where &
            (sortKey.isSmallerThanValue(sortAt) |
                (sortKey.equals(sortAt) & table.sessionId.isSmallerThanValue(sessionId)));
      }
      final rows =
          await (select(table).addColumns([sortKey])
                ..where(where)
                ..orderBy([OrderingTerm.desc(sortKey), OrderingTerm.desc(table.sessionId)])
                ..limit(limit + 1))
              .get();
      final page = [for (final row in rows.take(limit)) row.readTable(table)];
      final SessionPageKey? nextKey = rows.length > limit
          ? (sortAt: rows[limit - 1].read(sortKey) ?? 0, sessionId: page.last.sessionId)
          : null;
      return (rows: page, nextKey: nextKey, counts: pageCounts);
    });
  }

  /// SQL form of the time SessionCatalogMapper sends as `time.updated`: the
  /// later of `updated_at` and `last_user_message_at`.
  Expression<int> get _displayedAt {
    final userMessageAt = coalesce([sessionTable.lastUserMessageAt, const Constant(0)]);
    return CaseWhenExpression(
      cases: [CaseWhen(userMessageAt.isBiggerThan(sessionTable.updatedAt), then: userMessageAt)],
      orElse: sessionTable.updatedAt,
    );
  }

  /// SQL form of SessionUnseenCalculator.isUnseen: activity strictly newer
  /// than both the user's last message and the last time they saw it.
  Expression<bool> get _unseen {
    final activityAt = coalesce([sessionTable.lastActivityAt, const Constant(0)]);
    return activityAt.isBiggerThan(coalesce([sessionTable.lastUserMessageAt, const Constant(0)])) &
        activityAt.isBiggerThan(coalesce([sessionTable.lastSeenAt, const Constant(0)]));
  }

  static Expression<T> _unindexed<T extends Object>({required String column}) =>
      CustomExpression<T>('+"sessions_table"."$column"', precedence: Precedence.unary);

  static String _escapeLike(String word) => word.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_");

  Future<void> setArchived({
    required String sessionId,
    required int archivedAt,
    required int updatedAt,
    required int projectionUpdatedAt,
  }) async {
    await (update(sessionTable)..where((t) => t.sessionId.equals(sessionId))).write(
      SessionTableCompanion(
        archivedAt: Value(archivedAt),
        lastAgent: const Value(null),
        lastAgentModel: const Value(null),
        updatedAt: Value(updatedAt),
        projectionUpdatedAt: Value(projectionUpdatedAt),
      ),
    );
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
  /// these paths into the plugin's enumeration hints, as they do with the
  /// [directory] of a project-less session's scratch folder.
  Future<List<SessionProjectPathRow>> getSessionProjectPaths({
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
          backendSessionId: row.readTable(sessionTable).backendSessionId,
          projectPath: row.readTable(projectsTable).path,
          worktreePath: row.readTable(sessionTable).worktreePath,
          directory: row.readTable(sessionTable).directory,
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

  /// Returns the unseen-relevant columns of the non-archived root sessions
  /// across all of [projectIds], grouped by project, in a single query (avoids
  /// N+1 for the `/projects` aggregate). The repository applies the unseen
  /// formula; the DAO stays query-only.
  Future<Map<String, List<SessionUnseenRow>>> getActiveRootUnseenRowsForProjects({
    required List<String> projectIds,
  }) async {
    if (projectIds.isEmpty) return const {};
    final query = selectOnly(sessionTable)
      ..addColumns([
        sessionTable.projectId,
        sessionTable.lastActivityAt,
        sessionTable.lastSeenAt,
        sessionTable.lastUserMessageAt,
      ])
      ..where(
        sessionTable.projectId.isIn(projectIds) &
            sessionTable.parentSessionId.isNull() &
            sessionTable.archivedAt.isNull(),
      );
    final grouped = <String, List<SessionUnseenRow>>{};
    for (final row in await query.get()) {
      final projectId = row.read(sessionTable.projectId);
      if (projectId == null) continue;
      (grouped[projectId] ??= <SessionUnseenRow>[]).add((
        activityAt: row.read(sessionTable.lastActivityAt),
        seenAt: row.read(sessionTable.lastSeenAt),
        userMessageAt: row.read(sessionTable.lastUserMessageAt),
      ));
    }
    return grouped;
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
    required String worktreePath,
  }) async {
    return await (select(sessionTable)..where(
          (t) =>
              t.sessionId.equals(sessionId).not() &
              t.projectId.equals(projectId) &
              t.archivedAt.isNull() &
              t.worktreePath.equals(worktreePath),
        ))
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
    required List<
      ({
        String sessionId,
        String backendSessionId,
        String projectId,
        String directory,
        int createdAt,
        int? archivedAt,
      })
    >
    sessions,
    required String pluginId,
  }) async {
    if (sessions.isEmpty) return;
    final projectIds = {for (final session in sessions) session.projectId};
    final projects = await (select(projectsTable)..where((table) => table.projectId.isIn(projectIds))).get();
    final knownProjectIds = {for (final project in projects) project.projectId};
    final unknownProjectIds = projectIds.difference(knownProjectIds);
    if (unknownProjectIds.isNotEmpty) {
      throw StateError("Cannot insert sessions for unknown projects $unknownProjectIds");
    }
    await batch((b) {
      b.insertAll(
        sessionTable,
        [
          for (final s in sessions)
            SessionTableCompanion(
              sessionId: Value(s.sessionId),
              backendSessionId: Value(s.backendSessionId),
              projectId: Value(s.projectId),
              parentSessionId: const Value(null),
              directory: Value(s.directory),
              // isDedicated hardcoded false — placeholders are non-dedicated by default.
              // Callers (plugin-sourced sessions) never have meaningful worktree state.
              isDedicated: const Value(false),
              createdAt: Value(s.createdAt),
              updatedAt: Value(s.createdAt),
              projectionUpdatedAt: Value(s.createdAt),
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

  Future<List<SessionDto>> getSessionsByParentIds({required List<String> parentSessionIds}) {
    if (parentSessionIds.isEmpty) return Future.value(const []);
    return (select(sessionTable)..where((table) => table.parentSessionId.isIn(parentSessionIds))).get();
  }
}
