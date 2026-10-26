import "package:drift/native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_shared/sesori_shared.dart";

export "single_plugin_repository_test_support.dart";

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

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
    preservePullRequestScope: false,
  );
}

/// Inserts an in-place session row of [projectId] whose stored directory is
/// [directory], the way a scratch session's own folder is stored.
Future<void> insertTestSessionInDirectory({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String directory,
}) async {
  await insertTestSession(
    db: db,
    sessionId: sessionId,
    backendSessionId: sessionId,
    pluginId: "fake",
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
