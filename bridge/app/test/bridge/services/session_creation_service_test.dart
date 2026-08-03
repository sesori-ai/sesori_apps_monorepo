import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart" as bridge_metadata;
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_creation_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionCreationService", () {
    late AppDatabase db;
    late _FakePlugin plugin;
    late _FakeMetadataService metadataService;
    late _FakeWorktreeService worktreeService;
    late SessionRepository repository;
    late SessionOperationDispatcher operationDispatcher;
    late SessionMutationDispatcher mutationDispatcher;
    late SessionCreationService service;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      plugin = _FakePlugin();
      metadataService = _FakeMetadataService();
      worktreeService = _FakeWorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: GitCliApi(
            processRunner: _NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: plugin,
        ),
      );
      repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      operationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      mutationDispatcher = SessionMutationDispatcher(
        sessionRepository: repository,
        sessionOperationDispatcher: operationDispatcher,
      );
      service = SessionCreationService(
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionRepository: repository,
        sessionOperationDispatcher: operationDispatcher,
        sessionMutationDispatcher: mutationDispatcher,
      );
    });

    tearDown(() async {
      await operationDispatcher.dispose();
      await mutationDispatcher.dispose();
      await db.close();
    });

    test("validates the requested plugin before project and creation side effects", () async {
      await expectLater(
        service.createSession(
          request: const CreateSessionRequest(
            projectId: "/missing-project",
            pluginId: "other",
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Build it")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        ),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.statusCode, "statusCode", 503)
              .having((error) => error.operation, "operation", "createSession"),
        ),
      );

      expect(metadataService.generateCalls, isZero);
      expect(worktreeService.prepareCalls, isZero);
      expect(worktreeService.resolveCalls, isZero);
      expect(plugin.createCalls, isZero);
      expect(await db.sessionDao.getSession(sessionId: "backend-session"), isNull);
    });

    test("stores the created root with its explicit plugin and backend binding", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-one",
        branchName: "session-one",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final created = await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(created.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(created.id, isNot("backend-session"));
      expect(stored, isNotNull);
      expect(stored!.backendSessionId, "backend-session");
      expect(stored.pluginId, "fake");
      expect(stored.projectId, "/repo");
      expect(stored.directory, "/repo/.worktrees/session-one");
      expect(stored.worktreePath, "/repo/.worktrees/session-one");
      expect(plugin.lastCreateDirectory, "/repo/.worktrees/session-one");
      expect(plugin.lastCreateUserVisibleText, "Build it");
      expect(plugin.lastCreateParts, hasLength(2));
      expect(plugin.lastCreateParts?.last, const PluginPromptPart.text(text: "Build it"));
    });

    test("projects every nonblank user text part without bridge-owned context", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-one",
        branchName: "session-one",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: true,
          parts: [
            PromptPart.text(text: "Build it"),
            PromptPart.text(text: "  "),
            PromptPart.text(text: "Then test it"),
          ],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      expect(plugin.lastCreateUserVisibleText, "Build it\n\nThen test it");
      expect(plugin.lastCreateUserVisibleText, isNot(contains("SYSTEM CONTEXT")));
      expect(plugin.lastCreateParts, hasLength(4));
      expect(plugin.lastCreateParts?.first, isA<PluginPromptPartText>());
      expect((plugin.lastCreateParts!.first as PluginPromptPartText).text, contains("SYSTEM CONTEXT"));
    });

    test("stores the HEAD commit for an in-place session", () async {
      worktreeService.headCommit = "abc123";

      final created = await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(stored?.worktreePath, isNull);
      expect(stored?.branchName, isNull);
      expect(stored?.baseBranch, isNull);
      expect(stored?.baseCommit, "abc123");
      expect(worktreeService.resolveCalls, 1);
    });

    test("allocates around a cross-plugin backend-id collision without changing the retained binding", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: "/retained",
        path: "/retained",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      await db.sessionDao.insertSession(
        sessionId: "backend-session",
        backendSessionId: "backend-session",
        pluginId: "other",
        projectId: "/retained",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final created = await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final retained = await db.sessionDao.getSession(sessionId: "backend-session");
      final createdBinding = await db.sessionDao.getSession(sessionId: created.id);
      expect(plugin.createCalls, 1);
      expect(retained?.pluginId, "other");
      expect(retained?.backendSessionId, "backend-session");
      expect(retained?.projectId, "/retained");
      expect(created.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(createdBinding?.pluginId, "fake");
      expect(createdBinding?.backendSessionId, "backend-session");
      expect(createdBinding?.projectId, "/repo");
    });

    test("reveals exactly once after a delayed initial command fails", () async {
      final commandStarted = Completer<void>();
      final releaseCommand = Completer<void>();
      final failure = StateError("initial command failed");
      plugin
        ..commandStarted = commandStarted
        ..releaseCommand = releaseCommand.future
        ..commandError = failure;
      final commits = <SessionBindingsCommitted>[];
      final subscription = repository.bindingCommits.listen(commits.add);
      addTearDown(subscription.cancel);

      final creation = service.createSession(
        request: _request(
          text: "private prompt",
          command: "review",
        ),
      );
      await commandStarted.future;
      final stored = await db.sessionDao.getSessionByBinding(
        pluginId: plugin.id,
        backendSessionId: "backend-session",
      );
      expect(stored, isNotNull);
      expect(commits, isEmpty);
      expect(await repository.getCatalogSession(sessionId: stored!.sessionId), isNull);

      releaseCommand.complete();
      await expectLater(creation, throwsA(same(failure)));

      expect((await repository.getCatalogSession(sessionId: stored.sessionId))?.id, stored.sessionId);
      expect(commits, hasLength(1));
    });
  });
}

CreateSessionRequest _request({required String text, required String? command}) {
  return CreateSessionRequest(
    projectId: "/repo",
    pluginId: "fake",
    dedicatedWorktree: false,
    parts: [PromptPart.text(text: text)],
    variant: null,
    agent: null,
    model: null,
    command: command,
  );
}

class _FakeMetadataService extends MetadataService {
  int generateCalls = 0;

  _FakeMetadataService()
    : super(
        client: http.Client(),
        baseUrl: "http://localhost",
        tokenRefresher: _FakeTokenRefresher(),
      );

  @override
  Future<bridge_metadata.SessionMetadata?> generate({required String firstMessage}) async {
    generateCalls++;
    return null;
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}

class _FakeWorktreeService extends WorktreeService {
  int prepareCalls = 0;
  int resolveCalls = 0;
  WorktreeResult prepareResult = WorktreeFallback(originalPath: "/repo", reason: "fallback");
  String? headCommit;

  _FakeWorktreeService({required super.worktreeRepository});

  @override
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    prepareCalls++;
    return prepareResult;
  }

  @override
  Future<String?> resolveHeadCommit({
    required String projectId,
  }) async {
    resolveCalls++;
    return headCommit;
  }
}

class _FakePlugin implements NativeProjectsPluginApi {
  int createCalls = 0;
  String? lastCreateDirectory;
  String? lastCreateUserVisibleText;
  List<PluginPromptPart>? lastCreateParts;
  Completer<void>? commandStarted;
  Future<void>? releaseCommand;
  Object? commandError;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    createCalls++;
    lastCreateDirectory = directory;
    lastCreateUserVisibleText = userVisibleText;
    lastCreateParts = parts;
    return PluginSession(
      id: "backend-session",
      projectID: "/repo",
      directory: directory,
      parentID: null,
      title: null,
      time: null,
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (commandStarted case final started? when !started.isCompleted) started.complete();
    if (releaseCommand case final release?) await release;
    if (commandError case final error?) throw error;
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopProcessRunner implements ProcessRunner {
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
