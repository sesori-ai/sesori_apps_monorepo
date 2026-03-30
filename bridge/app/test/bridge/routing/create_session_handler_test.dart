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
        sessionDao: db.sessionDao,
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

    test("dedicated=true and WorktreeSuccess injects system prompt and stores worktree metadata", () async {
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
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(
              projectId: "/repo",
              dedicatedWorktree: true,
              parts: [PromptPart.text(text: "Start")],
              agent: null,
              model: null,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.prepareCallCount, equals(1));
      expect(plugin.lastCreateSessionDirectory, equals("/repo/.worktrees/session-001"));
      expect(plugin.lastCreateSessionParts, isNotNull);
      expect(plugin.lastCreateSessionParts, hasLength(2));
      expect(
        plugin.lastCreateSessionParts![0],
        equals(
          PluginPromptPart.text(
            text: buildWorktreeSystemPrompt(
              branchName: "session-001",
              worktreePath: "/repo/.worktrees/session-001",
              baseBranch: "main",
            ),
          ),
        ),
      );
      expect(plugin.lastCreateSessionParts![1], equals(const PluginPromptPart.text(text: "Start")));

      final dbSession = await db.sessionDao.getSession(sessionId: "s1");
      expect(dbSession, isNotNull);
      expect(dbSession!.projectId, equals("/repo"));
      expect(dbSession.isDedicated, isTrue);
      expect(dbSession.worktreePath, equals("/repo/.worktrees/session-001"));
      expect(dbSession.branchName, equals("session-001"));
      expect(dbSession.baseBranch, equals("main"));
      expect(dbSession.baseCommit, equals("abc123def456"));
      expect(dbSession.createdAt, greaterThan(0));
    });

    test("dedicated=false skips worktree prep and stores resolved base branch metadata", () async {
      plugin.createSessionResult = const PluginSession(
        id: "simple-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Simple",
        time: null,
        summary: null,
      );
      worktreeService.resolveBaseBranchAndCommitResult = (
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(
              projectId: "/repo",
              dedicatedWorktree: false,
              parts: [PromptPart.text(text: "Start")],
              agent: null,
              model: null,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.prepareCallCount, equals(0));
      expect(worktreeService.resolveBaseBranchAndCommitCallCount, equals(1));
      expect(worktreeService.lastResolveBaseBranchProjectPath, equals("/repo"));
      expect(plugin.lastCreateSessionDirectory, equals("/repo"));
      expect(plugin.lastCreateSessionParts, equals(const [PluginPromptPart.text(text: "Start")]));

      final dbSession = await db.sessionDao.getSession(sessionId: "simple-1");
      expect(dbSession, isNotNull);
      expect(dbSession!.projectId, equals("/repo"));
      expect(dbSession.isDedicated, isFalse);
      expect(dbSession.worktreePath, isNull);
      expect(dbSession.branchName, isNull);
      expect(dbSession.baseBranch, equals("main"));
      expect(dbSession.baseCommit, equals("abc123def456"));
      expect(dbSession.createdAt, greaterThan(0));
    });

    test(
      "dedicated=true and WorktreeFallback has no system prompt and stores dedicated row with null worktree fields",
      () async {
        plugin.createSessionResult = const PluginSession(
          id: "fallback-1",
          projectID: "p1",
          directory: "/repo",
          parentID: null,
          title: "Fallback",
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
              const CreateSessionRequest(
                projectId: "/repo",
                dedicatedWorktree: true,
                parts: [PromptPart.text(text: "Start")],
                agent: null,
                model: null,
              ).toJson(),
            ),
          ),
          pathParams: {},
          queryParams: {},
        );

        expect(response.status, equals(200));
        expect(worktreeService.prepareCallCount, equals(1));
        expect(plugin.lastCreateSessionDirectory, equals("/repo"));
        expect(plugin.lastCreateSessionParts, equals(const [PluginPromptPart.text(text: "Start")]));

        final dbSession = await db.sessionDao.getSession(sessionId: "fallback-1");
        expect(dbSession, isNotNull);
        expect(dbSession!.projectId, equals("/repo"));
        expect(dbSession.isDedicated, isTrue);
        expect(dbSession.worktreePath, isNull);
        expect(dbSession.branchName, isNull);
        expect(dbSession.baseBranch, isNull);
        expect(dbSession.baseCommit, isNull);
        expect(dbSession.createdAt, greaterThan(0));
      },
    );

    test("buildWorktreeSystemPrompt includes branch, path, and base branch", () {
      final prompt = buildWorktreeSystemPrompt(
        branchName: "session-017",
        worktreePath: "/repo/.worktrees/session-017",
        baseBranch: "develop",
      );

      expect(prompt, contains("session-017"));
      expect(prompt, contains("/repo/.worktrees/session-017"));
      expect(prompt, contains("develop"));
      expect(prompt, contains("Do NOT create new worktrees"));
    });

    test("plugin failure is propagated and no session row is inserted", () async {
      final failingPlugin = _ThrowingCreateSessionPlugin();
      final localHandler = CreateSessionHandler(
        plugin: failingPlugin,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      await expectLater(
        () => localHandler.handle(
          makeRequest(
            "POST",
            "/session",
            body: jsonEncode(
              const CreateSessionRequest(
                projectId: "/repo",
                dedicatedWorktree: true,
                parts: [PromptPart.text(text: "Start")],
                agent: null,
                model: null,
              ).toJson(),
            ),
          ),
          pathParams: {},
          queryParams: {},
        ),
        throwsA(isA<StateError>()),
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s1");
      expect(dbSession, isNull);
      await failingPlugin.close();
    });

    test("response format remains unchanged", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: "parent-1",
        title: "Created",
        time: PluginSessionTime(created: 11, updated: 22, archived: 33),
        summary: PluginSessionSummary(additions: 1, deletions: 2, files: 3),
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(
              projectId: "/repo",
              dedicatedWorktree: false,
              parts: [PromptPart.text(text: "Start")],
              agent: null,
              model: null,
            ).toJson(),
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
      expect(body["directory"], equals("/repo"));
      expect(body["parentID"], equals("parent-1"));
      expect(body["title"], equals("Created"));
      expect(body["time"], equals({"created": 11, "updated": 22, "archived": 33}));
      expect(body["summary"], equals({"additions": 1, "deletions": 2, "files": 3}));
    });

    test("passes parts, agent, and model to plugin", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(
              projectId: "/tmp",
              dedicatedWorktree: false,
              parts: [PromptPart.text(text: "Hello")],
              agent: "architect",
              model: PromptModel(providerID: "openai", modelID: "gpt-5"),
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastCreateSessionProjectId, equals("/tmp"));
      expect(plugin.lastCreateSessionDirectory, equals("/tmp"));
      expect(plugin.lastCreateSessionParts, equals([const PluginPromptPart.text(text: "Hello")]));
      expect(plugin.lastCreateSessionAgent, equals("architect"));
      expect(plugin.lastCreateSessionModel, equals((providerID: "openai", modelID: "gpt-5")));
    });

    test("returns 400 when parts are missing", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode({"projectId": "/tmp", "dedicatedWorktree": false, "agent": null, "model": null}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
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
  String? lastResolveBaseBranchProjectPath;
  int prepareCallCount = 0;
  int resolveBaseBranchAndCommitCallCount = 0;
  WorktreeResult prepareResult = WorktreeFallback(
    originalPath: "/repo",
    reason: "default",
  );
  ({String baseBranch, String baseCommit})? resolveBaseBranchAndCommitResult;

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
  Future<({String baseBranch, String baseCommit})?> resolveBaseBranchAndCommit({
    required String projectPath,
  }) async {
    resolveBaseBranchAndCommitCallCount++;
    lastResolveBaseBranchProjectPath = projectPath;
    return resolveBaseBranchAndCommitResult;
  }
}

class _ThrowingCreateSessionPlugin extends FakeBridgePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    throw StateError("createSession failed");
  }
}
