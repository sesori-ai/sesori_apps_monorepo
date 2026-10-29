import "package:drift/drift.dart" show Value;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_page_cursor.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late _ActivityPlugin plugin;
  late SessionRepository repository;

  setUp(() async {
    db = createTestDatabase();
    plugin = _ActivityPlugin();
    repository = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    for (final (projectId, hidden, displayName) in [
      ("/work/app", false, null),
      ("/work/tools", false, "Renamed"),
      ("/work/secret", true, null),
      // The No project project, whose own name is null.
      ("/scratch", false, null),
    ]) {
      await db
          .into(db.projectsTable)
          .insert(
            ProjectsTableCompanion.insert(
              projectId: projectId,
              path: projectId,
              hidden: Value(hidden),
              displayName: Value(displayName),
              projectionUpdatedAt: 1,
            ),
          );
    }
  });

  tearDown(() async {
    await plugin.close();
    await db.close();
  });

  Future<void> insert({required String id, required String projectId, required int updatedAt, String? title}) {
    return db
        .into(db.sessionTable)
        .insert(
          SessionTableCompanion.insert(
            sessionId: id,
            backendSessionId: "backend-$id",
            projectId: projectId,
            directory: projectId,
            isDedicated: false,
            createdAt: 1,
            updatedAt: updatedAt,
            projectionUpdatedAt: 1,
            pluginId: plugin.id,
            title: Value(title),
          ),
        );
  }

  Future<SessionPage> page({
    String? projectId,
    String? query,
    SessionPageFilter filter = SessionPageFilter.all,
    SessionPageCursor? cursor,
    int limit = 100,
  }) => repository.getSessionPage(
    mode: SessionPageMode.active,
    projectId: projectId,
    query: query,
    filter: filter,
    cursor: cursor,
    limit: limit,
  );

  List<String> ids({required SessionPage page}) => [for (final session in page.items) session.id];

  test("lists roots of every visible project, the scratch project included", () async {
    await insert(id: "app", projectId: "/work/app", updatedAt: 4);
    await insert(id: "tools", projectId: "/work/tools", updatedAt: 3);
    await insert(id: "secret", projectId: "/work/secret", updatedAt: 2);
    await insert(id: "scratch", projectId: "/scratch", updatedAt: 1);

    final all = await page();
    expect(ids(page: all), ["app", "tools", "scratch"]);
    expect(all.items.first.projectID, "/work/app");
    expect(ids(page: await page(projectId: "/work/tools")), ["tools"]);
    expect(ids(page: await page(projectId: "/work/secret")), isEmpty);
    expect(ids(page: await page(projectId: "/work/unknown")), isEmpty);
  });

  test("pages continue from the cursor", () async {
    await insert(id: "a", projectId: "/work/app", updatedAt: 3);
    await insert(id: "b", projectId: "/work/app", updatedAt: 2);
    await insert(id: "c", projectId: "/work/app", updatedAt: 1);

    final first = await page(limit: 2);
    expect(ids(page: first), ["a", "b"]);
    final second = await page(limit: 2, cursor: first.nextCursor);
    expect(ids(page: second), ["c"]);
    expect(second.nextCursor, isNull);
  });

  test("search words match titles or the project's own name", () async {
    await insert(id: "app-fix", projectId: "/work/app", updatedAt: 4, title: "Fix the header");
    await insert(id: "app-other", projectId: "/work/app", updatedAt: 3, title: "Docs");
    await insert(id: "tools-fix", projectId: "/work/tools", updatedAt: 2, title: "fix it");
    await insert(id: "scratch-fix", projectId: "/scratch", updatedAt: 1, title: "Fix");

    expect(ids(page: await page(query: "APP fix")), ["app-fix"]);
    expect(ids(page: await page(query: "renamed")), ["tools-fix"]);
    // The directory name of a renamed project is not its own name.
    expect(ids(page: await page(query: "tools")), isEmpty);
    // The scratch project has no own name to match.
    expect(ids(page: await page(query: "scratch")), isEmpty);
    final fix = await page(query: "fix");
    expect(ids(page: fix), ["app-fix", "tools-fix", "scratch-fix"]);
    expect(fix.counts, const SessionPageCounts(all: 3, running: 0, unread: 0));
  });

  test("running sessions come from the plugins' activity under the shared rule", () async {
    await insert(id: "working", projectId: "/work/app", updatedAt: 4);
    await insert(id: "waiting", projectId: "/work/app", updatedAt: 3);
    await insert(id: "tasks", projectId: "/work/app", updatedAt: 2);
    await insert(id: "task", projectId: "/work/app", updatedAt: 1);
    plugin.summaries = const [
      PluginProjectActivitySummary(
        id: "/work/app",
        activeSessions: [
          PluginActiveSession(id: "backend-working", mainAgentRunning: true),
          PluginActiveSession(id: "backend-waiting", awaitingInput: true),
          PluginActiveSession(id: "backend-tasks", childSessionIds: ["backend-task"]),
        ],
      ),
    ];

    final running = await page(filter: SessionPageFilter.running);
    expect(ids(page: running), ["working", "tasks"]);
    expect(running.counts, const SessionPageCounts(all: 4, running: 2, unread: 0));
  });

  test("an active root of a project the activity read discovers is on the same page", () async {
    const directory = "/work/new";
    plugin
      ..summaries = const [
        PluginProjectActivitySummary(
          id: directory,
          activeSessions: [PluginActiveSession(id: "backend-new", mainAgentRunning: true)],
        ),
      ]
      ..currentProjectResult = const PluginProject(id: directory, directory: directory)
      ..sessionsResult = [
        const PluginSession(
          id: "backend-new",
          projectID: directory,
          directory: directory,
          parentID: null,
          title: "New",
          time: PluginSessionTime(created: 1, updated: 2, archived: null),
        ),
      ];

    final all = await page();
    expect([for (final session in all.items) session.projectID], [directory]);
    expect(all.counts, const SessionPageCounts(all: 1, running: 1, unread: 0));
  });
}

class _ActivityPlugin() extends FakeBridgePlugin {
  List<PluginProjectActivitySummary> summaries = const [];

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => summaries;
}
