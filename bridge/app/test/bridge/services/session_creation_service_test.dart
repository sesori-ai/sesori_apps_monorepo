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
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_creation_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
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
    late SessionMutationDispatcher mutationDispatcher;
    late TestCommandStack commandStack;
    late CommandDispatcher commandDispatcher;
    late SessionCreationService service;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      plugin = _FakePlugin();
      metadataService = _FakeMetadataService();
      worktreeService = _FakeWorktreeService(
        worktreeRepository: WorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: GitCliApi(
            processRunner: _NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: plugin,
        ),
      );
      commandStack = TestCommandStack(db);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      commandDispatcher = commandStack.dispatcher(
        plugin: plugin,
        sessionRepository: repository,
      );
      mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
      service = SessionCreationService(
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionRepository: repository,
        commandDispatcher: commandDispatcher,
        sessionMutationDispatcher: mutationDispatcher,
      );
    });

    tearDown(() async {
      await mutationDispatcher.dispose();
      await commandDispatcher.dispose();
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
          parts: [],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final stored = await db.sessionDao.getSession(sessionId: "backend-session");
      expect(created.id, "backend-session");
      expect(stored, isNotNull);
      expect(stored!.backendSessionId, "backend-session");
      expect(stored.pluginId, "fake");
      expect(stored.projectId, "/repo");
      expect(stored.directory, "/repo/.worktrees/session-one");
      expect(stored.worktreePath, "/repo/.worktrees/session-one");
      expect(plugin.lastCreateDirectory, "/repo/.worktrees/session-one");
    });

    test("rejects a cross-plugin stable id collision without changing the retained binding", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: "/retained",
        path: "/retained",
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

      await expectLater(
        service.createSession(
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
        ),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.statusCode, "statusCode", 409)
              .having((error) => error.operation, "operation", "createSession"),
        ),
      );

      final retained = await db.sessionDao.getSession(sessionId: "backend-session");
      expect(plugin.createCalls, 1);
      expect(retained?.pluginId, "other");
      expect(retained?.backendSessionId, "backend-session");
      expect(retained?.projectId, "/retained");
    });

    test("rejected initial command rolls back session and only its requested worktree", () async {
      final rejection = StateError("command rejected");
      plugin.dispatchError = rejection;
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/rejected",
        branchName: "rejected",
        baseBranch: "main",
        baseCommit: "abc123",
      );
      final deletedEvents = <Session>[];
      final subscription = mutationDispatcher.deletedSessions.listen(deletedEvents.add);
      addTearDown(subscription.cancel);

      await expectLater(
        service.createSession(
          request: const CreateSessionRequest(
            projectId: "/repo",
            pluginId: "fake",
            dedicatedWorktree: true,
            parts: [PromptPart.text(text: "Review this")],
            variant: null,
            agent: null,
            model: null,
            command: "review",
          ),
        ),
        throwsA(same(rejection)),
      );

      expect(await db.sessionDao.getSession(sessionId: "backend-session"), isNull);
      expect(await db.sessionDao.getTombstonedSessionIds(pluginId: "fake"), isEmpty);
      expect(plugin.deletedSessionIds, ["backend-session"]);
      expect(worktreeService.removedWorktrees, [
        (projectId: "/repo", worktreePath: "/repo/.worktrees/rejected", force: true),
      ]);
      expect(worktreeService.deletedBranches, [
        (projectId: "/repo", branchName: "rejected", force: true),
      ]);
      expect(deletedEvents, [isA<Session>().having((session) => session.projectID, "projectID", "/repo")]);
    });

    test("initial worktree command hides backend context from durable arguments", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/review",
        branchName: "review",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Review this")],
          variant: null,
          agent: null,
          model: null,
          command: "review",
        ),
      );

      expect(plugin.lastCommandArguments, contains("Branch: review"));
      expect(plugin.lastCommandArguments, contains("Worktree path: /repo/.worktrees/review"));
      expect(plugin.lastCommandArguments, endsWith("Review this"));
      final invocation = (await commandStack.repository.getForSession(
        pluginId: "fake",
        sessionId: "backend-session",
      )).single;
      expect(invocation.arguments, "Review this");
    });
  });
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
  final List<({String projectId, String worktreePath, bool force})> removedWorktrees = [];
  final List<({String projectId, String branchName, bool force})> deletedBranches = [];

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
  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectId,
  }) async {
    resolveCalls++;
    return null;
  }

  @override
  Future<bool> removeWorktree({
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async {
    removedWorktrees.add((projectId: projectId, worktreePath: worktreePath, force: force));
    return true;
  }

  @override
  Future<bool> deleteBranch({
    required String projectId,
    required String branchName,
    required bool force,
  }) async {
    deletedBranches.add((projectId: projectId, branchName: branchName, force: force));
    return true;
  }
}

class _FakePlugin implements NativeProjectsPluginApi {
  int createCalls = 0;
  String? lastCreateDirectory;
  Object? dispatchError;
  String? lastCommandArguments;
  final List<String> deletedSessionIds = [];

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    createCalls++;
    lastCreateDirectory = directory;
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
  Future<PluginCommandDispatch> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastCommandArguments = arguments;
    final error = dispatchError;
    if (error != null) throw error;
    return const PluginCommandDispatch(backendMessageId: null);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deletedSessionIds.add(sessionId);
  }

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
