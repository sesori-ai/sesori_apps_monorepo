import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart" show SessionDto;
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/create_session_handler.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

String _expectedWorktreeSystemPrompt({
  required String branchName,
  required String worktreePath,
  required String baseBranch,
}) {
  return '''
[SYSTEM CONTEXT — IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: $branchName
- Worktree path: $worktreePath
- Based on: $baseBranch

IMPORTANT: Perform all work for this task in this dedicated worktree. You may use the initial branch above, or switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---
''';
}

void _expectRandomSesoriId({required String sessionId, required String backendSessionId}) {
  expect(sessionId, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
  expect(sessionId, isNot(backendSessionId));
}

Future<SessionDto> _expectStoredBinding({
  required AppDatabase database,
  required String sessionId,
  required String backendSessionId,
  required String pluginId,
}) async {
  final row = await database.sessionDao.getSession(sessionId: sessionId);
  expect(row, isNotNull);
  expect(row!.backendSessionId, backendSessionId);
  expect(row.pluginId, pluginId);
  return row;
}

void main() {
  group("CreateSessionHandler", () {
    late _OpenCodeFakeBridgePlugin plugin;
    late FakeSessionMetadataRepository metadataRepository;
    late _FakeWorktreeService worktreeService;
    late SessionRepository sessionRepository;
    late SessionOperationDispatcher sessionOperationDispatcher;
    late SessionMutationDispatcher sessionMutationDispatcher;
    late SessionCreationService sessionCreationService;
    late CreateSessionHandler handler;
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo", "/tmp"]);
      plugin = _OpenCodeFakeBridgePlugin();
      metadataRepository = FakeSessionMetadataRepository();
      worktreeService = _FakeWorktreeService(database: db);
      sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      sessionOperationDispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      sessionMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: sessionRepository,
        sessionOperationDispatcher: sessionOperationDispatcher,
        worktreeService: worktreeService,
      );
      sessionCreationService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionMutationDispatcher,
      );
      handler = CreateSessionHandler(sessionCreationService: sessionCreationService);
    });

    tearDown(() async {
      await sessionCreationService.drain();
      await sessionOperationDispatcher.dispose();
      await sessionMutationDispatcher.dispose();
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session/create", () {
      expect(handler.canHandle(makeRequest("POST", "/session/create")), isTrue);
    });

    test("does not handle GET /session/create", () {
      expect(handler.canHandle(makeRequest("GET", "/session/create")), isFalse);
    });

    test("accepts a request body without pluginId", () async {
      final response = await handler.routeForTest(
        makeRequest(
          "POST",
          "/session/create",
          body: jsonEncode({
            "projectId": "/repo",
            "parts": <Object>[],
            "agent": null,
            "model": null,
            "command": null,
            "variant": null,
            "dedicatedWorktree": false,
          }),
        ),
      );

      expect(response.status, equals(200));
      expect(plugin.lastCreateSessionDirectory, equals("/repo"));
    });

    test("dedicated=true and WorktreeSuccess injects system prompt and stores worktree metadata", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Created",
        time: null,
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
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          variant: SessionVariant(id: "xhigh"),
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(worktreeService.prepareCallCount, equals(1));
      expect(plugin.lastCreateSessionDirectory, equals("/repo/.worktrees/session-001"));
      expect(plugin.lastCreateSessionParts, isNotNull);
      expect(plugin.lastCreateSessionParts, hasLength(2));
      expect(plugin.lastCreateSessionUserVisibleText, "Start");
      expect(plugin.lastCreateSessionVariant, equals("xhigh"));
      expect(
        plugin.lastCreateSessionParts![0],
        equals(
          PluginPromptPart.text(
            text: _expectedWorktreeSystemPrompt(
              branchName: "session-001",
              worktreePath: "/repo/.worktrees/session-001",
              baseBranch: "main",
            ),
          ),
        ),
      );
      expect(plugin.lastCreateSessionParts![1], equals(const PluginPromptPart.text(text: "Start")));

      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "s1",
        pluginId: plugin.id,
      );
      expect(dbSession.projectId, equals("/repo"));
      expect(dbSession.isDedicated, isTrue);
      expect(dbSession.worktreePath, equals("/repo/.worktrees/session-001"));
      expect(dbSession.branchName, equals("session-001"));
      expect(dbSession.baseBranch, equals("main"));
      expect(dbSession.baseCommit, equals("abc123def456"));
      expect(dbSession.createdAt, greaterThan(0));
    });

    test("stores prompt defaults from creation request", () async {
      plugin.createSessionResult = const PluginSession(
        id: "defaults-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Defaults",
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          variant: SessionVariant(id: "xhigh"),
          agent: "architect",
          model: PromptModel(providerID: "anthropic", modelID: "claude-sonnet"),
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "defaults-1");
      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "defaults-1",
        pluginId: plugin.id,
      );
      expect(dbSession.lastAgent, equals("architect"));
      expect(dbSession.lastAgentModel?.providerID, equals("anthropic"));
      expect(dbSession.lastAgentModel?.modelID, equals("claude-sonnet"));
      expect(dbSession.lastAgentModel?.variant, equals("xhigh"));
    });

    test("dedicated=false skips worktree prep and stores the HEAD commit", () async {
      plugin.createSessionResult = const PluginSession(
        id: "simple-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Simple",
        time: null,
      );
      worktreeService.resolveHeadCommitResult = "abc123def456";

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "simple-1");
      expect(worktreeService.prepareCallCount, equals(0));
      expect(worktreeService.resolveHeadCommitCallCount, equals(1));
      expect(worktreeService.lastResolveHeadProjectId, equals("/repo"));
      expect(plugin.lastCreateSessionDirectory, equals("/repo"));
      expect(plugin.lastCreateSessionParts, equals(const [PluginPromptPart.text(text: "Start")]));

      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "simple-1",
        pluginId: plugin.id,
      );
      expect(dbSession.projectId, equals("/repo"));
      expect(dbSession.isDedicated, isFalse);
      expect(dbSession.worktreePath, isNull);
      expect(dbSession.branchName, isNull);
      expect(dbSession.baseBranch, isNull);
      expect(dbSession.baseCommit, equals("abc123def456"));
      expect(dbSession.createdAt, greaterThan(0));
    });

    test("moved project: session cwd is the live directory, stored attribution keeps the id", () async {
      // The folder moved from /repo to /moved/repo and was re-opened there.
      await db.projectsDao.recordOpenedProject(
        projectId: "/repo",
        path: "/moved/repo",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      plugin.createSessionResult = const PluginSession(
        id: "moved-1",
        projectID: "p1",
        directory: "/moved/repo",
        parentID: null,
        title: "Moved",
        time: null,
      );
      worktreeService.resolveHeadCommitResult = "abc123def456";

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "moved-1");
      // The backend gets the live directory as the session cwd...
      expect(plugin.lastCreateSessionDirectory, equals("/moved/repo"));
      // ...while the starting-commit lookup and the stored session→project
      // attribution stay keyed on the stable identifier.
      expect(worktreeService.lastResolveHeadProjectId, equals("/repo"));
      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "moved-1",
        pluginId: plugin.id,
      );
      expect(dbSession.projectId, equals("/repo"));
      // The response is re-keyed to the stable id too — the plugin can only
      // echo the directory it created the session in.
      expect(result.projectID, equals("/repo"));
    });

    test(
      "dedicated=true and WorktreeFallback persists an in-place session with HEAD",
      () async {
        plugin.createSessionResult = const PluginSession(
          id: "fallback-1",
          projectID: "p1",
          directory: "/repo",
          parentID: null,
          title: "Fallback",
          time: null,
        );
        worktreeService.prepareResult = WorktreeFallback(
          originalPath: "/repo",
          reason: "not git",
        );
        worktreeService.resolveHeadCommitResult = "fallback-head";

        final result = await handler.handle(
          makeRequest("POST", "/session/create"),
          body: const CreateSessionRequest(
            projectId: "/repo",
            pluginId: legacyMissingPluginId,
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Start")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        );

        _expectRandomSesoriId(sessionId: result.id, backendSessionId: "fallback-1");
        expect(worktreeService.prepareCallCount, equals(1));
        expect(plugin.lastCreateSessionDirectory, equals("/repo"));
        expect(plugin.lastCreateSessionParts, equals(const [PluginPromptPart.text(text: "Start")]));

        final dbSession = await _expectStoredBinding(
          database: db,
          sessionId: result.id,
          backendSessionId: "fallback-1",
          pluginId: plugin.id,
        );
        expect(dbSession.projectId, equals("/repo"));
        expect(dbSession.isDedicated, isFalse);
        expect(dbSession.worktreePath, isNull);
        expect(dbSession.branchName, isNull);
        expect(dbSession.baseBranch, isNull);
        expect(dbSession.baseCommit, "fallback-head");
        expect(worktreeService.resolveHeadCommitCallCount, 1);
        expect(dbSession.createdAt, greaterThan(0));
      },
    );

    test("empty parts keep dedicated worktree metadata but skip system prompt injection", () async {
      plugin.createSessionResult = const PluginSession(
        id: "empty-1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-empty",
        parentID: null,
        title: "Empty",
        time: null,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-empty",
        branchName: "session-empty",
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: <PromptPart>[],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "empty-1");
      expect(plugin.lastCreateSessionDirectory, equals("/repo/.worktrees/session-empty"));
      expect(plugin.lastCreateSessionParts, isEmpty);

      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "empty-1",
        pluginId: plugin.id,
      );
      expect(dbSession.isDedicated, isTrue);
      expect(dbSession.worktreePath, equals("/repo/.worktrees/session-empty"));
      expect(dbSession.branchName, equals("session-empty"));
      expect(dbSession.baseBranch, equals("main"));
      expect(dbSession.baseCommit, equals("abc123def456"));
    });

    test("worktree system prompt requires the worktree but permits branch changes", () {
      final prompt = _expectedWorktreeSystemPrompt(
        branchName: "session-017",
        worktreePath: "/repo/.worktrees/session-017",
        baseBranch: "develop",
      );

      expect(prompt, contains("session-017"));
      expect(prompt, contains("/repo/.worktrees/session-017"));
      expect(prompt, contains("develop"));
      expect(prompt, contains("Perform all work for this task in this dedicated worktree"));
      expect(prompt, contains("use the initial branch above, or switch branches"));
      expect(prompt, contains("Do NOT create another worktree or working directory"));
    });

    test("plugin failure is propagated and no session row is inserted", () async {
      final failingPlugin = _ThrowingCreateSessionPlugin();
      final localRepository = singlePluginSessionRepository(
        plugin: failingPlugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final localOperationDispatcher = SessionOperationDispatcher(sessionRepository: localRepository);
      final localMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: localRepository,
        sessionOperationDispatcher: localOperationDispatcher,
        worktreeService: worktreeService,
      );
      final localCreationService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: localRepository,
        sessionMutationDispatcher: localMutationDispatcher,
      );
      final localHandler = CreateSessionHandler(sessionCreationService: localCreationService);
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
            pluginId: legacyMissingPluginId,
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Start")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s1");
      expect(dbSession, isNull);
      await localCreationService.drain();
      await localOperationDispatcher.dispose();
      await localMutationDispatcher.dispose();
      await failingPlugin.close();
    });

    test("returns mapped Session fields", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Created",
        time: PluginSessionTime(created: 11, updated: 22, archived: 33),
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "opencode",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(result.pluginId, equals("opencode"));
      // The created session belongs to the requested project by construction,
      // so the response is re-keyed to the request's stable projectId — the
      // plugin can only echo the directory it created the session in.
      expect(result.projectID, equals("/repo"));
      expect(result.directory, equals("/repo"));
      expect(result.parentID, isNull);
      expect(result.title, equals("Created"));
      expect(result.time?.created, equals(11));
      expect(result.time?.updated, equals(22));
      expect(result.time?.archived, isNull);
    });

    test("hasWorktree is true when WorktreeSuccess", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Created",
        time: null,
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
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      expect(result.hasWorktree, isTrue);
      expect(result.pullRequest, isNull);
    });

    test("hasWorktree is false when dedicated=false", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Created",
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
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
      );
      worktreeService.prepareResult = WorktreeFallback(
        originalPath: "/repo",
        reason: "not git",
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      expect(result.hasWorktree, isFalse);
    });

    test("passes parts, agent, and model to plugin", () async {
      await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/tmp",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: "architect",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
          command: null,
        ),
      );

      expect(plugin.lastCreateSessionDirectory, equals("/tmp"));
      expect(plugin.lastCreateSessionParts, equals([const PluginPromptPart.text(text: "Hello")]));
      expect(plugin.lastCreateSessionAgent, equals("architect"));
      expect(plugin.lastCreateSessionModel, equals((providerID: "openai", modelID: "gpt-5")));
    });

    test("AI metadata updates the title after the canonical response", () async {
      metadataRepository.generateResult = "Fix Login Bug";
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/fix-login-bug",
        parentID: null,
        title: "Session",
        time: null,
      );
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/fix-login-bug",
        parentID: null,
        title: "Fix Login Bug",
        time: null,
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
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Fix the login bug")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(metadataRepository.lastGenerateMessage, equals("Fix the login bug"));
      expect(worktreeService.prepareCallCount, 1);
      expect(result.title, equals("Session"));
      await sessionCreationService.drain();
      expect((await db.sessionDao.getSession(sessionId: result.id))?.title, equals("Fix Login Bug"));
      expect(plugin.lastRenameSessionTitle, equals("Fix Login Bug"));
    });

    test("missing AI metadata skips the session rename", () async {
      metadataRepository.generateResult = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Session",
        time: null,
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
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Start")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(plugin.lastRenameSessionId, isNull);
    });

    test("no text parts — metadata generation skipped", () async {
      metadataRepository.lastGenerateMessage = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: null,
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.fileData(mime: "image/png", base64: "abc", filename: "img.png")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(metadataRepository.lastGenerateMessage, isNull);
    });

    test("whitespace-only text parts skipped — metadata generation skipped", () async {
      metadataRepository.lastGenerateMessage = null;
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: null,
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "   ")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(metadataRepository.lastGenerateMessage, isNull);
    });

    test("command dispatched after session creation with new session ID", () async {
      plugin.createSessionResult = const PluginSession(
        id: "cmd-session-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Command Session",
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Review this code")],
          variant: SessionVariant(id: "low"),
          agent: null,
          model: null,
          command: "review",
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "cmd-session-1");
      expect(plugin.lastCreateSessionAgent, isNull);
      expect(plugin.lastCreateSessionModel, isNull);
      expect(plugin.lastCreateSessionParts, isEmpty);
      expect(plugin.lastCreateSessionUserVisibleText, isNull);
      expect(plugin.lastCreateSessionVariant, equals("low"));
      expect(plugin.lastSendCommandSessionId, equals("cmd-session-1"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("Review this code"));
      expect(plugin.lastSendCommandVariant, equals("low"));
    });

    test("slash-command acceptance gates response and late metadata", () async {
      final commandGate = Completer<void>();
      plugin
        ..createSessionResult = const PluginSession(
          id: "cmd-session-gated",
          projectID: "p1",
          directory: "/repo",
          parentID: null,
          title: "Command Session",
          time: null,
        )
        ..sendCommandStarted = Completer<void>()
        ..sendCommandCompleter = commandGate;
      metadataRepository.generateResult = "Generated command title";

      var responseCompleted = false;
      final response = handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Review this code")],
          variant: null,
          agent: null,
          model: null,
          command: "review",
        ),
      );
      unawaited(response.then<void>((_) => responseCompleted = true));

      await plugin.sendCommandStarted!.future;
      expect(responseCompleted, isFalse);
      expect(metadataRepository.lastGenerateMessage, isNull);

      commandGate.complete();
      final created = await response;
      expect(created.title, "Command Session");
      await sessionCreationService.drain();
      expect(metadataRepository.lastGenerateMessage, "Review this code");
    });

    test("slash-command rejection fails creation without starting metadata", () async {
      final commandGate = Completer<void>();
      plugin
        ..createSessionResult = const PluginSession(
          id: "cmd-session-rejected",
          projectID: "p1",
          directory: "/repo",
          parentID: null,
          title: "Command Session",
          time: null,
        )
        ..sendCommandStarted = Completer<void>()
        ..sendCommandCompleter = commandGate;
      metadataRepository.generateResult = "Must not be used";

      final response = handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Review this code")],
          variant: null,
          agent: null,
          model: null,
          command: "review",
        ),
      );
      await plugin.sendCommandStarted!.future;
      commandGate.completeError(StateError("command rejected"));

      await expectLater(response, throwsA(isA<StateError>()));
      expect(metadataRepository.lastGenerateMessage, isNull);
    });

    test("dedicated worktree command carries worktree guardrail in command arguments", () async {
      plugin.createSessionResult = const PluginSession(
        id: "cmd-dedicated-1",
        projectID: "p1",
        directory: "/repo/.worktrees/session-001",
        parentID: null,
        title: "Command Session",
        time: null,
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123def456",
      );

      await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Review this code")],
          variant: null,
          agent: null,
          model: null,
          command: "review",
        ),
      );

      expect(plugin.lastCreateSessionParts, isEmpty);
      expect(plugin.lastCreateSessionUserVisibleText, isNull);
      expect(plugin.lastSendCommandSessionId, equals("cmd-dedicated-1"));
      expect(plugin.lastSendCommandArguments, contains("session-001"));
      expect(plugin.lastSendCommandArguments, contains("/repo/.worktrees/session-001"));
      expect(plugin.lastSendCommandArguments, contains("Review this code"));
      expect(
        plugin.lastSendCommandUserVisibleArguments,
        equals("Review this code"),
      );
    });

    test("persists stored session before sending command", () async {
      final orderedPlugin = _OrderCheckingCommandPlugin(database: db)
        ..createSessionResult = const PluginSession(
          id: "ordered-session-1",
          projectID: "p1",
          directory: "/repo",
          parentID: null,
          title: "Ordered Session",
          time: null,
        );
      final orderedRepository = singlePluginSessionRepository(
        plugin: orderedPlugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final orderedOperationDispatcher = SessionOperationDispatcher(sessionRepository: orderedRepository);
      final orderedMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: orderedRepository,
        sessionOperationDispatcher: orderedOperationDispatcher,
        worktreeService: worktreeService,
      );
      final orderedCreationService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: orderedRepository,
        sessionMutationDispatcher: orderedMutationDispatcher,
      );
      final localHandler = CreateSessionHandler(sessionCreationService: orderedCreationService);

      await localHandler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Review this code")],
          variant: null,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
          command: "review",
        ),
      );

      expect(orderedPlugin.hadStoredRowWhenCommandSent, isTrue);
      expect(orderedPlugin.lastSendCommandAgent, equals("coder"));
      expect(orderedPlugin.lastSendCommandModel, equals((providerID: "openai", modelID: "gpt-5")));
      final dbSession = await db.sessionDao.getSessionByBinding(
        pluginId: orderedPlugin.id,
        backendSessionId: "ordered-session-1",
      );
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("coder"));
      expect(dbSession.lastAgentModel?.providerID, equals("openai"));
      expect(dbSession.lastAgentModel?.modelID, equals("gpt-5"));
      await orderedCreationService.drain();
      await orderedOperationDispatcher.dispose();
      await orderedMutationDispatcher.dispose();
      await orderedPlugin.close();
    });

    test("command-created session stores request defaults while plugin create receives null agent and model", () async {
      plugin.createSessionResult = const PluginSession(
        id: "cmd-defaults-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Command Defaults",
        time: null,
      );

      final result = await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Review this")],
          variant: SessionVariant(id: "xhigh"),
          agent: "reviewer",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
          command: "review",
        ),
      );

      expect(plugin.lastCreateSessionAgent, isNull);
      expect(plugin.lastCreateSessionModel, isNull);
      expect(plugin.lastSendCommandAgent, equals("reviewer"));
      expect(plugin.lastSendCommandModel, equals((providerID: "openai", modelID: "gpt-5")));
      final dbSession = await _expectStoredBinding(
        database: db,
        sessionId: result.id,
        backendSessionId: "cmd-defaults-1",
        pluginId: plugin.id,
      );
      expect(dbSession.lastAgent, equals("reviewer"));
      expect(dbSession.lastAgentModel?.providerID, equals("openai"));
      expect(dbSession.lastAgentModel?.modelID, equals("gpt-5"));
      expect(dbSession.lastAgentModel?.variant, equals("xhigh"));
    });

    test("rejects session creation for an unknown project id before plugin side effects", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/create"),
          body: const CreateSessionRequest(
            projectId: "brand-new-proj",
            pluginId: legacyMissingPluginId,
            dedicatedWorktree: false,
            parts: [PromptPart.text(text: "Hello")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        ),
        throwsA(isA<ProjectNotFoundException>()),
      );

      expect(plugin.lastCreateSessionDirectory, isNull);
      expect(await db.projectsDao.getProject(projectId: "brand-new-proj"), isNull);
      expect(await db.sessionDao.getSession(sessionId: "new-sess-1"), isNull);
    });

    test("no command — sendCommand not called", () async {
      plugin.createSessionResult = const PluginSession(
        id: "no-cmd-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "No Command",
        time: null,
      );

      await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      expect(plugin.lastSendCommandSessionId, isNull);
      expect(plugin.lastSendCommand, isNull);
    });

    test("blank command is treated like no command", () async {
      plugin.createSessionResult = const PluginSession(
        id: "blank-cmd-1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Blank Command",
        time: null,
      );

      await handler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          command: "   ",
        ),
      );

      expect(plugin.lastCreateSessionAgent, equals("coder"));
      expect(plugin.lastCreateSessionModel?.providerID, equals("openai"));
      expect(plugin.lastSendCommandSessionId, isNull);
    });

    test("plugin rename failure keeps the stored generated title", () async {
      final throwingPlugin = _ThrowingRenameSessionPlugin();
      metadataRepository.generateResult = "Fix Login Bug";
      throwingPlugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/repo",
        parentID: null,
        title: "Session",
        time: null,
      );
      final throwingRepository = singlePluginSessionRepository(
        plugin: throwingPlugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final throwingOperationDispatcher = SessionOperationDispatcher(sessionRepository: throwingRepository);
      final throwingDispatcher = SessionMutationDispatcher(
        sessionRepository: throwingRepository,
        sessionOperationDispatcher: throwingOperationDispatcher,
        worktreeService: worktreeService,
      );
      final localCreationService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: throwingRepository,
        sessionMutationDispatcher: throwingDispatcher,
      );
      final localHandler = CreateSessionHandler(sessionCreationService: localCreationService);

      final result = await localHandler.handle(
        makeRequest("POST", "/session/create"),
        body: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: legacyMissingPluginId,
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Fix the login bug")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      _expectRandomSesoriId(sessionId: result.id, backendSessionId: "s1");
      expect(result.title, "Session");
      await localCreationService.drain();
      expect((await db.sessionDao.getSession(sessionId: result.id))?.title, "Fix Login Bug");
      await throwingOperationDispatcher.dispose();
      await throwingDispatcher.dispose();
      await throwingPlugin.close();
    });
  });
}

class _FakeWorktreeService({required AppDatabase database}) extends WorktreeService {
  String? lastPrepareProjectId;
  String? lastPrepareParentSessionId;
  String? lastResolveHeadProjectId;
  int prepareCallCount = 0;
  int resolveHeadCommitCallCount = 0;
  WorktreeResult prepareResult = WorktreeFallback(
    originalPath: "/repo",
    reason: "default",
  );
  String? resolveHeadCommitResult;
  GeneratedBranchRenameResult renameResult = GeneratedBranchRenameSkipped(
    reason: GeneratedBranchRenameSkipReason.initialBranchChanged,
  );

  this
    : super(
        worktreeRepository: singlePluginWorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          gitApi: GitCliApi(
            processRunner: _NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: _FakeBridgePlugin(),
        ),
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
  Future<String?> resolveHeadCommit({
    required String projectId,
  }) async {
    resolveHeadCommitCallCount++;
    lastResolveHeadProjectId = projectId;
    return resolveHeadCommitResult;
  }

  @override
  Future<GeneratedBranchRenameResult> renameGeneratedBranch({
    required String worktreePath,
    required String initialBranchName,
    required String generatedBranchName,
  }) async => renameResult;
}

class _NoopProcessRunner() implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError("_NoopProcessRunner should never execute git commands");
  }
}

class _OpenCodeFakeBridgePlugin() extends FakeBridgePlugin {
  @override
  String get id => "opencode";
}

class _ThrowingCreateSessionPlugin() extends _OpenCodeFakeBridgePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    throw StateError("createSession failed");
  }
}

class _ThrowingRenameSessionPlugin() extends _OpenCodeFakeBridgePlugin {
  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) {
    throw StateError("renameSession failed");
  }
}

class _OrderCheckingCommandPlugin({required final AppDatabase _database}) extends _OpenCodeFakeBridgePlugin {
  bool hadStoredRowWhenCommandSent = false;

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final session = await _database.sessionDao.getSessionByBinding(
      pluginId: id,
      backendSessionId: sessionId,
    );
    hadStoredRowWhenCommandSent = session != null;
    await super.sendCommand(
      promptId: "prompt-1",
      sessionId: sessionId,
      command: command,
      arguments: arguments,
      userVisibleArguments: userVisibleArguments,
      variant: variant,
      agent: agent,
      model: model,
    );
  }
}

class _FakeBridgePlugin() extends _OpenCodeFakeBridgePlugin {
  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}
}
