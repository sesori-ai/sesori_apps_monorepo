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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
      service = SessionCreationService(
        metadataService: metadataService,
        worktreeService: worktreeService,
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
      );
    });

    tearDown(() async {
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
}

class _FakePlugin implements NativeProjectsPluginApi {
  int createCalls = 0;
  String? lastCreateDirectory;

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
