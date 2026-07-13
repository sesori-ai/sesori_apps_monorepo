import "package:drift/drift.dart";
import "package:sesori_bridge/src/bridge/api/database/tables/catalog_hydrations_table.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db
        .into(db.projectsTable)
        .insert(
          ProjectsTableCompanion.insert(
            projectId: "project-1",
            path: "/projects/one",
            createdAt: const Value(1),
            updatedAt: const Value(1),
            projectionUpdatedAt: 1,
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> insertSession({
    required String id,
    required String backendId,
    required String pluginId,
    required String? parentId,
    required int updatedAt,
    required int? archivedAt,
  }) {
    return db
        .into(db.sessionTable)
        .insert(
          SessionTableCompanion.insert(
            sessionId: id,
            backendSessionId: backendId,
            projectId: "project-1",
            parentSessionId: Value(parentId),
            directory: "/projects/one",
            isDedicated: false,
            archivedAt: Value(archivedAt),
            createdAt: 1,
            updatedAt: updatedAt,
            projectionUpdatedAt: updatedAt,
            pluginId: pluginId,
          ),
        );
  }

  test("catalog DAOs return ordered roots, children, bindings, and archived rows", () async {
    await db
        .into(db.projectsTable)
        .insert(
          ProjectsTableCompanion.insert(
            projectId: "project-2",
            path: "/projects/two",
            createdAt: const Value(2),
            updatedAt: const Value(30),
            projectionUpdatedAt: 30,
          ),
        );
    await insertSession(
      id: "root-old",
      backendId: "backend-old",
      pluginId: "opencode",
      parentId: null,
      updatedAt: 10,
      archivedAt: null,
    );
    await insertSession(
      id: "root-new",
      backendId: "backend-new",
      pluginId: "codex",
      parentId: null,
      updatedAt: 20,
      archivedAt: 30,
    );
    await insertSession(
      id: "child",
      backendId: "backend-child",
      pluginId: "codex",
      parentId: "root-new",
      updatedAt: 25,
      archivedAt: null,
    );

    final roots = await db.sessionDao.getRootCatalogSessions(
      ownerIdentity: "local",
      projectId: "project-1",
      offset: 0,
      limit: 10,
    );
    expect(roots.map((row) => row.sessionId), ["root-new", "root-old"]);
    expect(
      (await db.sessionDao.getChildCatalogSessions(
        ownerIdentity: "local",
        parentSessionId: "root-new",
      )).single.sessionId,
      "child",
    );
    expect(
      (await db.sessionDao.getSessionByBinding(
        ownerIdentity: "local",
        pluginId: "codex",
        backendSessionId: "backend-new",
      ))?.sessionId,
      "root-new",
    );
    expect(
      (await db.sessionDao.getArchivedCatalogSessions(ownerIdentity: "local", offset: 0, limit: 10)).single.sessionId,
      "root-new",
    );
    expect(
      (await db.projectsDao.getProjectsByOwnerAndPath(ownerIdentity: "local", path: "/projects/one")).single.projectId,
      "project-1",
    );
    expect(
      (await db.projectsDao.getCatalogProjects(ownerIdentity: "local")).map((row) => row.projectId),
      ["project-2", "project-1"],
    );
  });

  test("hydration completion access is exact and replaceable", () async {
    const first = CatalogHydrationDto(
      ownerIdentity: "local",
      pluginId: "codex",
      projectionVersion: 1,
      completedAt: 10,
    );
    await db.catalogHydrationsDao.recordCompletion(completion: first);
    await db.catalogHydrationsDao.recordCompletion(completion: first.copyWith(completedAt: 20));

    expect(
      (await db.catalogHydrationsDao.getCompletion(
        ownerIdentity: "local",
        pluginId: "codex",
        projectionVersion: 1,
      ))?.completedAt,
      20,
    );
    await db.catalogHydrationsDao.deleteForPlugin(ownerIdentity: "local", pluginId: "codex");
    expect(await db.select(db.catalogHydrationsTable).get(), isEmpty);
  });

  test("catalog queries use their declared indexes", () async {
    Future<String> plan(String sql) async {
      final rows = await db.customSelect("EXPLAIN QUERY PLAN $sql").get();
      return rows.map((row) => row.read<String>("detail")).join("\n");
    }

    expect(
      await plan("SELECT * FROM projects_table WHERE owner_identity = 'local' AND path = '/projects/one'"),
      contains("idx_projects_owner_path"),
    );
    expect(
      await plan(
        "SELECT * FROM projects_table WHERE owner_identity = 'local' "
        "ORDER BY updated_at DESC, project_id DESC",
      ),
      allOf(contains("idx_projects_owner_updated"), isNot(contains("USE TEMP B-TREE"))),
    );
    expect(
      await plan(
        "SELECT * FROM sessions_table WHERE owner_identity = 'local' AND plugin_id = 'codex' "
        "AND backend_session_id = 'backend'",
      ),
      contains("idx_sessions_owner_plugin_backend"),
    );
    expect(
      await plan(
        "SELECT * FROM sessions_table WHERE owner_identity = 'local' AND project_id = 'project-1' "
        "AND parent_session_id IS NULL ORDER BY updated_at DESC, session_id DESC",
      ),
      contains("idx_sessions_roots"),
    );
    expect(
      await plan(
        "SELECT * FROM sessions_table WHERE owner_identity = 'local' AND parent_session_id = 'parent' "
        "ORDER BY updated_at DESC, session_id DESC",
      ),
      contains("idx_sessions_children"),
    );
    expect(
      await plan(
        "SELECT * FROM sessions_table WHERE owner_identity = 'local' AND archived_at IS NOT NULL "
        "ORDER BY updated_at DESC, session_id DESC",
      ),
      allOf(contains("idx_sessions_archive"), isNot(contains("USE TEMP B-TREE"))),
    );
  });
}
