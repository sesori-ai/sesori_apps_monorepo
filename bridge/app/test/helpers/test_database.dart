import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_shared/sesori_shared.dart";

export "single_plugin_repository_test_support.dart";

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Test-only reads over the projects table; production code never needs them.
extension ProjectsDaoTestQueries on ProjectsDao {
  Future<Set<String>> getHiddenProjectIds() async {
    final rows = await (select(projectsTable)..where((table) => table.hidden.equals(true))).get();
    return {for (final row in rows) row.projectId};
  }

  Future<List<ProjectDto>> getProjectsByPath({required String path}) {
    return (select(projectsTable)..where((table) => table.path.equals(path))).get();
  }
}

/// Test setup only: inserts minimal non-dedicated session rows for ids that do
/// not exist yet and leaves existing rows untouched. Production rows are
/// created by `SessionRepository`'s create and observed-binding flows.
extension SessionDaoTestSeeding on SessionDao {
  Future<void> insertSessionsIfMissing({
    required String pluginId,
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
  }) async {
    if (sessions.isEmpty) return;
    await batch((batch) {
      batch.insertAll(
        sessionTable,
        [
          for (final session in sessions)
            SessionTableCompanion(
              sessionId: Value(session.sessionId),
              backendSessionId: Value(session.backendSessionId),
              projectId: Value(session.projectId),
              directory: Value(session.directory),
              isDedicated: const Value(false),
              createdAt: Value(session.createdAt),
              updatedAt: Value(session.createdAt),
              projectionUpdatedAt: Value(session.createdAt),
              archivedAt: Value(session.archivedAt),
              pluginId: Value(pluginId),
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}

/// Inserts a bound session row (and its project) straight through the DAOs.
///
/// Test setup only: production rows are created by `SessionRepository`'s
/// create and observed-binding flows, which the repository tests exercise.
Future<void> insertTestSession({
  required AppDatabase db,
  required String sessionId,
  required String backendSessionId,
  required String pluginId,
  required String projectId,
  required bool isDedicated,
  required int createdAt,
  required String? worktreePath,
  required String? baseBranch,
  required String? baseCommit,
  required String? agent,
  required AgentModel? agentModel,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await db.sessionDao.insertSession(
    fastMode: false,
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    projectId: projectId,
    isDedicated: isDedicated,
    createdAt: createdAt,
    worktreePath: worktreePath,
    baseBranch: baseBranch,
    baseCommit: baseCommit,
    lastAgent: agent,
    lastAgentModel: agentModel,
    pluginId: pluginId,
  );
}

/// Inserts an in-place session row of [projectId] whose stored directory is
/// [directory], the way a scratch session's own folder is stored.
Future<void> insertTestSessionInDirectory({
  required AppDatabase db,
  required String sessionId,
  required String pluginId,
  required String projectId,
  required String directory,
}) async {
  await insertTestSession(
    db: db,
    sessionId: sessionId,
    backendSessionId: sessionId,
    pluginId: pluginId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    baseBranch: null,
    baseCommit: null,
    agent: null,
    agentModel: null,
  );
  await db.sessionDao.updateObservedSessionProjection(
    sessionId: sessionId,
    directory: directory,
    catalogTitle: null,
    updateCatalogTitle: false,
    updatedAt: 1,
    projectionUpdatedAt: 1,
  );
}
