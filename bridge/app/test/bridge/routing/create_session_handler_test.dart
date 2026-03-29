import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/create_session_handler.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("CreateSessionHandler", () {
    late FakeBridgePlugin plugin;
    late _FakeWorktreeService worktreeService;
    late CreateSessionHandler handler;
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      worktreeService = _FakeWorktreeService(database: db);
      handler = CreateSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session", () {
      expect(handler.canHandle(makeRequest("POST", "/session")), isTrue);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns 400 when request body is empty", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("worktree path is used and mapping is recorded", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Created",
        time: null,
        summary: null,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(projectId: "/repo", parentSessionId: null).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(worktreeService.lastPrepareProjectId, equals("/repo"));
      expect(worktreeService.lastPrepareParentSessionId, isNull);
      expect(plugin.lastCreateSessionDirectory, equals("/repo/.worktrees/session-001"));
      expect(plugin.lastCreateSessionParentId, isNull);
      expect(worktreeService.recordCalls, hasLength(1));
      expect(worktreeService.recordCalls.first.sessionId, equals("s1"));
      expect(worktreeService.recordCalls.first.projectId, equals("/repo"));
      expect(worktreeService.recordCalls.first.worktreePath, equals("/repo/.worktrees/session-001"));
      expect(worktreeService.recordCalls.first.branchName, equals("session-001"));
      expect(response.status, equals(200));
    });

    test("fallback path is used and mapping is not recorded", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s-fallback",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Created",
        time: null,
        summary: null,
      );
      worktreeService.prepareResult = WorktreeFallback(
        originalPath: "/repo",
        reason: "not git",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(projectId: "/repo", parentSessionId: null).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastCreateSessionDirectory, equals("/repo"));
      expect(plugin.lastCreateSessionParentId, isNull);
      expect(worktreeService.recordCalls, isEmpty);
      expect(response.status, equals(200));
    });

    test("parent session calls worktree service and passes result to plugin", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s-child",
        projectID: "p1",
        directory: "/repo",
        parentID: "parent-1",
        title: "Child",
        time: null,
        summary: null,
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(projectId: "/repo", parentSessionId: "parent-1").toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      // Worktree service IS called for parent sessions (it handles reuse logic).
      expect(worktreeService.prepareCallCount, equals(1));
      expect(worktreeService.lastPrepareProjectId, equals("/repo"));
      expect(plugin.lastCreateSessionDirectory, equals("/repo"));
      expect(plugin.lastCreateSessionParentId, equals("parent-1"));
      expect(response.status, equals(200));
    });

    test("plugin failure is propagated and no mapping is recorded", () async {
      final failingPlugin = _ThrowingCreateSessionPlugin();
      final localHandler = CreateSessionHandler(
        plugin: failingPlugin,
        worktreeService: worktreeService,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      await expectLater(
        () => localHandler.handle(
          makeRequest(
            "POST",
            "/session",
            body: jsonEncode(
              const CreateSessionRequest(projectId: "/repo", parentSessionId: null).toJson(),
            ),
          ),
          pathParams: {},
          queryParams: {},
        ),
        throwsA(isA<StateError>()),
      );
      expect(worktreeService.recordCalls, isEmpty);
      await failingPlugin.close();
    });

    test("response format remains unchanged", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: "parent-1",
        title: "Created",
        time: PluginSessionTime(created: 11, updated: 22, archived: 33),
        summary: PluginSessionSummary(additions: 1, deletions: 2, files: 3),
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(projectId: "/repo", parentSessionId: "parent-1").toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["id"], equals("s1"));
      expect(body["projectID"], equals("p1"));
      expect(body["directory"], equals("/repo/.worktrees/session-001"));
      expect(body["parentID"], equals("parent-1"));
      expect(body["title"], equals("Created"));
      expect(body["time"], equals({"created": 11, "updated": 22, "archived": 33}));
      expect(body["summary"], equals({"additions": 1, "deletions": 2, "files": 3}));
    });

    test("returns 400 on invalid JSON body", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: "not-json",
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });
  });
}

class _FakeWorktreeService extends WorktreeService {
  String? lastPrepareProjectId;
  String? lastPrepareParentSessionId;
  int prepareCallCount = 0;
  WorktreeResult prepareResult = WorktreeFallback(
    originalPath: "/repo",
    reason: "default",
  );
  final List<
    ({
      String sessionId,
      String projectId,
      String worktreePath,
      String branchName,
    })
  >
  recordCalls = [];

  _FakeWorktreeService({required AppDatabase database})
    : super(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
      );

  @override
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
  }) async {
    prepareCallCount++;
    lastPrepareProjectId = projectId;
    lastPrepareParentSessionId = parentSessionId;
    return prepareResult;
  }

  @override
  Future<void> recordSessionWorktree({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) async {
    recordCalls.add((
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
    ));
  }
}

class _ThrowingCreateSessionPlugin extends FakeBridgePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    String? parentSessionId,
  }) {
    throw StateError("createSession failed");
  }
}
