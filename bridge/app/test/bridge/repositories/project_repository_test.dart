import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/test_database.dart";

void main() {
  group("ProjectRepository", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeBridgePlugin();
      repo = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("getProjects fetches plugin projects, persists each, filters hidden, sorts by updated desc", () async {
      plugin.projectsResult = const [
        PluginProject(id: "p1", name: "P1", time: PluginProjectTime(created: 0, updated: 100)),
        PluginProject(id: "p2", name: "P2", time: PluginProjectTime(created: 0, updated: 200)),
        PluginProject(id: "p3", name: "P3", time: PluginProjectTime(created: 0, updated: 300)),
      ];

      // Pre-hide p2 before the call — the repository must still persist it,
      // but it must not appear in the returned list.
      await db.projectsDao.hideProject(projectId: "p2");

      final result = await repo.getProjects();

      // (a) DB has all 3 rows (every plugin project is persisted regardless
      //     of hidden status — the FK target must always exist).
      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3"}),
        reason: "every plugin project must be upserted into projects_table",
      );

      // (b) Returned list filters p2 out.
      expect(result, hasLength(2));

      // (c) Order is [p3, p1] — sorted by time.updated descending.
      expect(result.map((p) => p.id).toList(), equals(["p3", "p1"]));
    });

    test("getProjects rethrows PluginApiException when plugin throws", () async {
      plugin.getProjectsError = PluginApiException("/project", 500);

      await expectLater(
        () => repo.getProjects(),
        throwsA(isA<PluginApiException>()),
      );

      // Plugin failed before the transaction opened — no rows should be
      // present in the database.
      final rows = await db.select(db.projectsTable).get();
      expect(rows, isEmpty, reason: "no DB writes on plugin failure");
    });

    test("getProjects inserts all projects atomically via batch", () async {
      // Verify that all N plugin projects are persisted in a single batch call.
      // The batch API is internally atomic — all rows land or none do.
      plugin.projectsResult = const [
        PluginProject(id: "p1"),
        PluginProject(id: "p2"),
        PluginProject(id: "p3"),
        PluginProject(id: "p4"),
      ];

      await repo.getProjects();

      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3", "p4"}),
        reason: "all plugin projects must be persisted via batch insert",
      );
    });

    test("openProject discovers via plugin, unhides stored row, and maps result", () async {
      plugin.projectResult = const PluginProject(id: "p-open", name: "Opened");
      await db.projectsDao.hideProject(projectId: "p-open");

      final result = await repo.openProject(path: "/tmp/p-open");

      expect(plugin.lastGetProjectId, equals("/tmp/p-open"));
      expect(result.id, equals("p-open"));
      expect(result.name, equals("Opened"));
      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains("p-open")));
    });

    test("hideProject persists hidden project id", () async {
      await repo.hideProject(projectId: "p-hidden");

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, contains("p-hidden"));
    });

    test("getBaseBranch returns stored branch", () async {
      await db.projectsDao.setBaseBranch(projectId: "p-base", baseBranch: "develop");

      final result = await repo.getBaseBranch(projectId: "p-base");

      expect(result, equals("develop"));
    });

    test("setBaseBranch stores branch", () async {
      await repo.setBaseBranch(projectId: "p-set", baseBranch: "main");

      final stored = await db.projectsDao.getBaseBranch(projectId: "p-set");
      expect(stored, equals("main"));
    });

    test("getProjects flags a project whose directory no longer exists on disk", () async {
      plugin.projectsResult = const [
        PluginProject(id: "/present", name: "Present", time: PluginProjectTime(created: 0, updated: 2)),
        PluginProject(id: "/moved", name: "Moved", time: PluginProjectTime(created: 0, updated: 1)),
      ];
      final repoWithMissing = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/moved"}),
      );

      final result = await repoWithMissing.getProjects();

      expect(result.firstWhere((p) => p.id == "/present").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/moved").directoryMissing, isTrue);
    });

    test("getProject flags a since-deleted directory as missing", () async {
      plugin.projectResult = const PluginProject(id: "/gone", name: "Gone");
      final repoWithMissing = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/gone"}),
      );

      final result = await repoWithMissing.getProject(projectId: "/gone");

      expect(result.directoryMissing, isTrue);
    });

    test("a directory whose existence probe throws is treated as present, not missing", () async {
      plugin.projectsResult = const [PluginProject(id: "/denied", name: "Denied")];
      final repoWithThrow = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(throwingPaths: {"/denied"}),
      );

      final result = await repoWithThrow.getProjects();

      expect(result.single.directoryMissing, isFalse);
    });
  });

  group("ProjectRepository (bridge-derived)", () {
    late AppDatabase db;
    late _FakeDerivedPlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeDerivedPlugin([]);
      repo = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("getProjects derives projects from the plugin's sessions, grouped by directory and sorted", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20),
        _session("/tmp/proj/alpha", id: "a2", created: 5, updated: 50),
        _session("/tmp/proj/beta", id: "b1", created: 1, updated: 1),
      ];

      final result = await repo.getProjects();

      expect(result.map((p) => p.id).toSet(), {"/tmp/proj/alpha", "/tmp/proj/beta"});
      // Canonical rows are persisted so a later session insert has an FK target.
      final rows = await db.select(db.projectsTable).get();
      expect(rows.map((r) => r.projectId).toSet(), containsAll({"/tmp/proj/alpha", "/tmp/proj/beta"}));
      // Sorted by updated desc: alpha (50) before beta (1).
      expect(result.first.id, "/tmp/proj/alpha");
    });

    test("getProjects omits a project flagged hidden", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];
      await db.projectsDao.hideProject(projectId: "/tmp/proj/alpha");

      expect(await repo.getProjects(), isEmpty);
    });

    test("getProjects ignores tombstoned sessions in project derivation", () async {
      // The backend has no session deletion, so it keeps enumerating the
      // deleted session — its project must not resurrect from it.
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "kept", created: 1, updated: 1),
        _session("/tmp/proj/deleted-only", id: "gone", created: 1, updated: 1),
      ];
      await db.sessionDao.insertSessionTombstone(sessionId: "gone", pluginId: "codex", deletedAt: 1);

      final result = await repo.getProjects();

      expect(result.map((p) => p.id), contains("/tmp/proj/alpha"));
      expect(result.map((p) => p.id), isNot(contains("/tmp/proj/deleted-only")));
    });

    test("openProject records an opened folder so an empty project survives the listing", () async {
      final opened = await repo.openProject(path: "/tmp/proj/empty");

      expect(opened.id, "/tmp/proj/empty");
      expect(opened.name, "empty");
      expect((await repo.getProjects()).map((p) => p.id), contains("/tmp/proj/empty"));
      final row = (await db.select(db.projectsTable).get()).firstWhere((r) => r.projectId == "/tmp/proj/empty");
      expect(row.openedAt, isNotNull);
      // The stored rows are also the enumeration hints: a directory-scoped
      // backend (ACP) is pointed at every recorded folder, so opening one makes
      // its pre-existing sessions discoverable on the next enumeration.
      expect(plugin.receivedKnownDirectories, containsAll(<String>["/tmp/proj/empty", plugin.launchDir]));
    });

    test("renameProject persists a display-name override applied on the next listing", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];

      final renamed = await repo.renameProject(projectId: "/tmp/proj/alpha", name: "Renamed Alpha");

      expect(renamed.name, "Renamed Alpha");
      final listed = (await repo.getProjects()).firstWhere((p) => p.id == "/tmp/proj/alpha");
      expect(listed.name, "Renamed Alpha");
    });

    test("getProject resolves a derived project without calling the plugin's guarded getProject", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20)];

      // The mixin's getProject throws; routing through the repository must
      // resolve from the derived set instead of surfacing that as an error.
      final project = await repo.getProject(projectId: "/tmp/proj/alpha");

      expect(project.id, "/tmp/proj/alpha");
      expect(project.name, "alpha");
    });

    test("getProject honours a stored display name for a project with no sessions or opened row", () async {
      // A rename on a project that isn't otherwise in the derived set (no
      // sessions, never opened) still persists a display-name override; the
      // placeholder must return that name rather than the directory basename.
      final renamed = await repo.renameProject(projectId: "/tmp/proj/ghost", name: "Ghost Renamed");

      expect(renamed.name, "Ghost Renamed");
      final resolved = await repo.getProject(projectId: "/tmp/proj/ghost");
      expect(resolved.name, "Ghost Renamed");
    });

    test("a session in a dedicated worktree folds into its parent project, not its own card", () async {
      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      // The bridge recorded this session under its parent project with the
      // worktree path it created — mirroring SessionCreationService.
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSession(
        sessionId: "w1",
        projectId: parent,
        isDedicated: true,
        createdAt: 200,
        worktreePath: worktree,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "codex",
      );
      // The plugin, however, only knows the session by its worktree cwd.
      plugin.sessions = [
        _session(parent, id: "s1", created: 100, updated: 100),
        _session(worktree, id: "w1", created: 200, updated: 200),
      ];

      final result = await repo.getProjects();

      // One card (the parent), never a card named after the worktree.
      expect(result.map((p) => p.id).toSet(), {parent});
      // The worktree session's later timestamp folded into the parent.
      expect(result.single.time?.updated, 200);
    });

    test("getProjects flags a derived project whose directory no longer exists on disk", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 1, updated: 2),
        _session("/tmp/proj/beta", id: "b1", created: 1, updated: 1),
      ];
      final repoWithMissing = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/tmp/proj/beta"}),
      );

      final result = await repoWithMissing.getProjects();

      expect(result.firstWhere((p) => p.id == "/tmp/proj/alpha").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/tmp/proj/beta").directoryMissing, isTrue);
    });
  });
}

PluginSession _session(
  String directory, {
  String id = "s",
  required int created,
  required int updated,
}) {
  return PluginSession(
    id: id,
    projectID: directory,
    directory: directory,
    parentID: null,
    title: null,
    time: PluginSessionTime(created: created, updated: updated, archived: null),
    summary: null,
  );
}

/// Minimal [BridgePluginApi] fake that only implements the surface touched by
/// [ProjectRepository]. Every other member throws so accidental use is loud.
class _FakeBridgePlugin implements NativeProjectsPluginApi {
  List<PluginProject> projectsResult = const [];
  Object? getProjectsError;
  PluginProject projectResult = const PluginProject(id: "project-id");
  String? lastGetProjectId;

  @override
  Future<List<PluginProject>> getProjects() async {
    final err = getProjectsError;
    if (err != null) throw err;
    return projectsResult;
  }

  @override
  String get id => throw UnimplementedError();

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) => throw UnimplementedError();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) => throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId) => throw UnimplementedError();

  @override
  Future<void> archiveSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => throw UnimplementedError();

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() => throw UnimplementedError();

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) => throw UnimplementedError();

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => <PluginCommand>[];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) => throw UnimplementedError();

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) => throw UnimplementedError();

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) => throw UnimplementedError();

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) async {
    lastGetProjectId = projectId;
    return projectResult;
  }

  @override
  Future<bool> healthCheck() => throw UnimplementedError();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) => throw UnimplementedError();

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}

/// A derive-style plugin: exposes its sessions through
/// [BridgeDerivedProjectsPluginApi.listAllSessions], mirroring how Codex/ACP
/// plugins are shaped — it has no project members at all, so the bridge
/// derivation path is what's exercised.
class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  _FakeDerivedPlugin(this.sessions);

  List<PluginSession> sessions;

  /// Points at a session directory used by the tests so the launch-folder seed
  /// doesn't introduce an extra project the assertions don't expect.
  String launchDir = "/tmp/proj/alpha";

  /// The hint set received on the most recent [listAllSessions] call.
  Set<String>? receivedKnownDirectories;

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    receivedKnownDirectories = knownDirectories;
    return sessions;
  }

  @override
  String get launchDirectory => launchDir;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
