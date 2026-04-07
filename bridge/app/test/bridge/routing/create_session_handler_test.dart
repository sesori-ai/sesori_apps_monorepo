import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart" as bridge_metadata;
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/create_session_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("CreateSessionHandler", () {
    late FakeBridgePlugin plugin;
    late FakeMetadataService metadataService;
    late _FakeWorktreeService worktreeService;
    late CreateSessionHandler handler;
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      metadataService = FakeMetadataService();
      worktreeService = _FakeWorktreeService(database: db);
      handler = CreateSessionHandler(
        plugin: plugin,
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session/create", () {
      expect(handler.canHandle(makeRequest("POST", "/session/create")), isTrue);
    });

    test("does not handle GET /session/create", () {
      expect(handler.canHandle(makeRequest("GET", "/session/create")), isFalse);
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

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
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
        startPoint: "main",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("simple-1"));
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

        final result = await handler.handle(
          makeRequest("POST", "/session/create"),
          body: const CreateSessionRequest(
            projectId: "/repo",
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Start")],
            agent: null,
            model: null,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        );

        expect(result.id, equals("fallback-1"));
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
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        ),
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      await expectLater(
        () => localHandler.handle(
          makeRequest("POST", "/session/create"),
          body: const CreateSessionRequest(
            projectId: "/repo",
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Start")],
            agent: null,
            model: null,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<StateError>()),
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s1");
      expect(dbSession, isNull);
      await failingPlugin.close();
    });

    test("returns mapped Session fields", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: "parent-1",
        title: "Created",
        time: PluginSessionTime(created: 11, updated: 22, archived: 33),
        summary: PluginSessionSummary(additions: 1, deletions: 2, files: 3),
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(result.projectID, equals("p1"));
      expect(result.directory, equals("/repo"));
      expect(result.parentID, equals("parent-1"));
      expect(result.title, equals("Created"));
      expect(result.time?.created, equals(11));
      expect(result.time?.updated, equals(22));
      expect(result.time?.archived, equals(33));
      expect(result.summary?.additions, equals(1));
      expect(result.summary?.deletions, equals(2));
      expect(result.summary?.files, equals(3));
    });

    test("hasWorktree is true when WorktreeSuccess", () async {
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
        baseCommit: "abc123",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isTrue);
    });

    test("hasWorktree is false when dedicated=false", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Created",
        time: null,
        summary: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isFalse);
    });

    test("hasWorktree is false when WorktreeFallback", () async {
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

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isFalse);
    });

    test("passes parts, agent, and model to plugin", () async {
      await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/tmp",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Hello")],
          agent: "architect",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastCreateSessionDirectory, equals("/tmp"));
      expect(plugin.lastCreateSessionParts, equals([const PluginPromptPart.text(text: "Hello")]));
      expect(plugin.lastCreateSessionAgent, equals("architect"));
      expect(plugin.lastCreateSessionModel, equals((providerID: "openai", modelID: "gpt-5")));
    });

    test("AI naming succeeds — preferred branch name and rename used", () async {
      metadataService.generateResult = const bridge_metadata.SessionMetadata(
        title: "Fix Login Bug",
        branchName: "fix-login-bug",
        worktreeName: "fix-login-bug",
      );
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/fix-login-bug",
        parentID: null,
        title: "Session",
        time: null,
        summary: null,
      );
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/fix-login-bug",
        parentID: null,
        title: "Fix Login Bug",
        time: null,
        summary: null,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/fix-login-bug",
        branchName: "fix-login-bug",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Fix the login bug")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(metadataService.lastGenerateMessage, equals("Fix the login bug"));
      expect(worktreeService.lastPreparePreferredBranchName, equals("fix-login-bug"));
      expect(plugin.lastRenameSessionTitle, equals("Fix Login Bug"));
    });

    test("AI naming returns null — no preferred branch and no rename", () async {
      metadataService.generateResult = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Session",
        time: null,
        summary: null,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(worktreeService.lastPreparePreferredBranchName, isNull);
      expect(plugin.lastRenameSessionId, isNull);
    });

    test("no text parts — metadata generation skipped", () async {
      metadataService.lastGenerateMessage = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: null,
        time: null,
        summary: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.fileData(mime: "image/png", base64: "abc", filename: "img.png")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(metadataService.lastGenerateMessage, isNull);
    });

    test("whitespace-only text parts skipped — metadata generation skipped", () async {
      metadataService.lastGenerateMessage = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: null,
        time: null,
        summary: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "   ")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(metadataService.lastGenerateMessage, isNull);
    });

    test("creates session for first-time project (no prior projects_table row)", () async {
      plugin.createSessionResult = const PluginSession(
        id: "new-sess-1",
        projectID: "brand-new-proj",
        directory: "brand-new-proj",
        parentID: null,
        title: "New Session",
        time: null,
        summary: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "brand-new-proj",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Hello")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      // (a) handler returns success
      expect(result.id, equals("new-sess-1"));

      // (b) projects_table has 1 row "brand-new-proj"
      // getHiddenProjectIds returns hidden ones, so verify existence indirectly
      // by checking the persisted session's projectId.
      final dbSession = await db.sessionDao.getSession(sessionId: "new-sess-1");
      expect(dbSession, isNotNull);
      expect(dbSession!.projectId, equals("brand-new-proj"));

      // (c) sessions_table has 1 session row
      expect(dbSession.sessionId, equals("new-sess-1"));
    });

    test("rename fails — session still returned successfully", () async {
      final throwingPlugin = _ThrowingRenameSessionPlugin();
      metadataService.generateResult = const bridge_metadata.SessionMetadata(
        title: "Fix Login Bug",
        branchName: "fix-login-bug",
        worktreeName: "fix-login-bug",
      );
      throwingPlugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Session",
        time: null,
        summary: null,
      );
      final localHandler = CreateSessionHandler(
        plugin: throwingPlugin,
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        ),
      );

      final result = await localHandler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Fix the login bug")],
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      await throwingPlugin.close();
    });
  });
}

class _FakeWorktreeService extends WorktreeService {
  String? lastPrepareProjectId;
  String? lastPrepareParentSessionId;
  String? lastPreparePreferredBranchName;
  String? lastResolveBaseBranchProjectPath;
  int prepareCallCount = 0;
  int resolveBaseBranchAndCommitCallCount = 0;
  WorktreeResult prepareResult = WorktreeFallback(
    originalPath: "/repo",
    reason: "default",
  );
  ({String baseBranch, String baseCommit, String startPoint})? resolveBaseBranchAndCommitResult;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        processRunner: _NoopProcessRunner(),
        gitPathExists: ({required String gitPath}) => true,
      );

  @override
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    prepareCallCount++;
    lastPrepareProjectId = projectId;
    lastPrepareParentSessionId = parentSessionId;
    lastPreparePreferredBranchName = preferredBranchAndWorktreeName?.branchName;
    return prepareResult;
  }

  @override
  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectPath,
  }) async {
    resolveBaseBranchAndCommitCallCount++;
    lastResolveBaseBranchProjectPath = projectPath;
    return resolveBaseBranchAndCommitResult;
  }
}

class _NoopProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError("_NoopProcessRunner should never execute git commands");
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

class _ThrowingRenameSessionPlugin extends FakeBridgePlugin {
  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) {
    throw StateError("renameSession failed");
  }
}
