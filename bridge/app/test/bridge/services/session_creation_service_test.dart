import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/database/daos/new_session_defaults_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/repositories/new_session_defaults_repository.dart";
import "package:sesori_bridge/src/repositories/session_metadata_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";

void main() {
  group("SessionCreationService", () {
    late AppDatabase db;
    late _FakePlugin plugin;
    late _FakeSessionMetadataRepository metadataRepository;
    late _FakeWorktreeService worktreeService;
    late SessionOperationDispatcher operationDispatcher;
    late SessionMutationDispatcher mutationDispatcher;
    late NewSessionDefaultsRepository defaultsRepository;
    late SessionCreationService service;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      defaultsRepository = NewSessionDefaultsRepository(
        dao: NewSessionDefaultsDao(database: db),
      );
      plugin = _FakePlugin();
      metadataRepository = _FakeSessionMetadataRepository();
      worktreeService = _FakeWorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: GitCliApi(
            processRunner: NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: plugin,
        ),
      );
      final repository = singlePluginSessionRepository(
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
        worktreeService: worktreeService,
      );
      service = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: mutationDispatcher,
      );
    });

    tearDown(() async {
      await service.drain();
      await operationDispatcher.dispose();
      await mutationDispatcher.dispose();
      await db.close();
    });

    test("validates the project before plugin and creation side effects", () async {
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
          isA<ProjectNotFoundException>(),
        ),
      );

      expect(metadataRepository.generateCalls, isZero);
      expect(worktreeService.prepareCalls, isZero);
      expect(worktreeService.resolveCalls, isZero);
      expect(plugin.createCalls, isZero);
      expect(await db.sessionDao.getSession(sessionId: "backend-session"), isNull);
    });

    test("starts metadata only after backend creation is accepted", () async {
      final pluginGate = Completer<void>();
      final metadataGate = Completer<void>();
      final runtime = createTestPluginRuntime(plugins: [plugin])
        ..useStarted = Completer<void>()
        ..useGate = pluginGate.future;
      metadataRepository
        ..generateStarted = Completer<void>()
        ..generateGate = metadataGate.future;
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
        runtime: runtime,
      );
      final localOperationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final localMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: repository,
        sessionOperationDispatcher: localOperationDispatcher,
        worktreeService: worktreeService,
      );
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: localMutationDispatcher,
      );

      final creation = localService.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      await runtime.useStarted!.future;
      expect(metadataRepository.generateCalls, isZero);
      pluginGate.complete();
      await metadataRepository.generateStarted!.future;
      final created = await creation;
      expect(await db.sessionDao.getSession(sessionId: created.id), isNotNull);
      metadataGate.complete();
      await localService.drain();
      await localOperationDispatcher.dispose();
      await localMutationDispatcher.dispose();
      await runtime.dispose();
    });

    test("returns a queryable session without waiting for metadata", () async {
      final metadataGate = Completer<void>();
      metadataRepository
        ..generateStarted = Completer<void>()
        ..generateGate = metadataGate.future;
      final creation = service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final created = await creation.timeout(const Duration(seconds: 1));
      expect(metadataRepository.generateStarted?.isCompleted, isTrue);
      expect(await db.sessionDao.getSession(sessionId: created.id), isNotNull);
      metadataGate.complete();
      await service.drain();
    });

    test("shutdown aborts and drains the underlying metadata workflow", () async {
      metadataRepository
        ..generateStarted = Completer<void>()
        ..abortOnShutdown = true
        ..shutdownObserved = Completer<void>();

      final created = await service.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );
      await metadataRepository.generateStarted!.future;

      service.beginShutdown();
      await service.drain().timeout(const Duration(seconds: 1));

      expect(metadataRepository.shutdownObserved?.isCompleted, isTrue);
      expect((await db.sessionDao.getSession(sessionId: created.id))?.title, isNull);
    });

    test("logs the underlying invalid metadata response", () async {
      const innerError = FormatException("invalid metadata response marker");
      final innerStackTrace = StackTrace.fromString("inner metadata response stack marker");
      metadataRepository.failure = SessionMetadataInvalidResponseException(
        cause: StateError("invalid metadata API response"),
        causeStackTrace: StackTrace.current,
        innerError: innerError,
        innerStackTrace: innerStackTrace,
      );

      final output = await _captureWarningLog(() async {
        await service.createSession(
          request: const CreateSessionRequest(
            projectId: "/repo",
            pluginId: "fake",
            dedicatedWorktree: false,
            parts: [PromptPart.text(text: "Build it")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        );
        await service.drain();
      });

      expect(output, contains(innerError.message));
      expect(output, contains("inner metadata response stack marker"));
    });

    test("surfaces plugin startup failures without starting metadata", () async {
      final runtime = createTestPluginRuntime(plugins: const <BridgePluginApi>[]);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
        runtime: runtime,
      );
      final localOperationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final localMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: repository,
        sessionOperationDispatcher: localOperationDispatcher,
        worktreeService: worktreeService,
      );
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: localMutationDispatcher,
      );

      final creation = localService.createSession(
        request: const CreateSessionRequest(
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );

      final failure = expectLater(
        creation.timeout(const Duration(milliseconds: 100)),
        throwsA(isA<PluginOperationException>()),
      );
      await failure;
      expect(metadataRepository.generateCalls, isZero);
      await localService.drain();
      await localOperationDispatcher.dispose();
      await localMutationDispatcher.dispose();
      await runtime.dispose();
    });

    test("maps stale command selections during creation to a generic bad request", () async {
      plugin.sendCommandError = const PluginStaleOptionsException(
        "sendCommand",
        message: "unsupported command model",
      );

      await expectLater(
        service.createSession(
          request: const CreateSessionRequest(
            projectId: "/repo",
            pluginId: "fake",
            dedicatedWorktree: false,
            parts: [PromptPart.text(text: "Review it")],
            variant: null,
            agent: null,
            model: PromptModel(providerID: "provider", modelID: "withdrawn"),
            command: "review",
          ),
        ),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.statusCode, "status", 400)
              .having((error) => error.cause, "cause", isA<PluginStaleOptionsException>()),
        ),
      );
      expect(metadataRepository.generateCalls, isZero);
      expect(await defaultsRepository.read(pluginId: "fake"), isNull);
    });

    test("stores the created root and remembers its complete plugin-scoped selection", () async {
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
          variant: SessionVariant(id: "high"),
          agent: "build",
          model: PromptModel(providerID: "provider", modelID: "model"),
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
      expect(
        await defaultsRepository.read(pluginId: "fake"),
        const SessionPromptDefaults(
          agent: "build",
          model: AgentModel(providerID: "provider", modelID: "model", variant: "high"),
        ),
      );
      expect(stored.directory, "/repo/.worktrees/session-one");
      expect(stored.worktreePath, "/repo/.worktrees/session-one");
      expect(plugin.lastCreateDirectory, "/repo/.worktrees/session-one");
      expect(plugin.lastCreateUserVisibleText, "Build it");
      expect(plugin.lastCreateParts, hasLength(2));
      expect(plugin.lastCreateParts?.last, const PluginPromptPart.text(text: "Build it"));
    });

    test("returns without waiting for defaults persistence", () async {
      final gatedDefaultsRepository = _GatedNewSessionDefaultsRepository();
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        newSessionDefaultsRepository: gatedDefaultsRepository,
        sessionMutationDispatcher: mutationDispatcher,
      );
      var creationCompleted = false;
      final creation = localService.createSession(
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
      unawaited(creation.then((_) => creationCompleted = true));
      addTearDown(() {
        if (!gatedDefaultsRepository.writeGate.isCompleted) {
          gatedDefaultsRepository.writeGate.complete();
        }
      });

      await gatedDefaultsRepository.writeStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(creationCompleted, isTrue);
      gatedDefaultsRepository.writeGate.complete();
      await creation;
      await localService.drain();
    });

    test("a defaults write failure does not turn a durable creation into a retryable failure", () async {
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        newSessionDefaultsRepository: _ThrowingNewSessionDefaultsRepository(),
        sessionMutationDispatcher: mutationDispatcher,
      );
      late Session created;

      final output = await _captureWarningLog(() async {
        created = await localService.createSession(
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
        await Future<void>.delayed(Duration.zero);
      });

      expect(await db.sessionDao.getSession(sessionId: created.id), isNotNull);
      expect(output, contains("Failed to remember new-session defaults for plugin fake"));
      expect(output, contains("defaults write failed"));
      await localService.drain();
    });

    test("applies dedicated-session metadata after returning the initial branch", () async {
      final metadataGate = Completer<void>();
      metadataRepository.generateGate = metadataGate.future;
      worktreeService
        ..prepareResult = WorktreeSuccess(
          path: "/repo/.worktrees/blue-otter",
          branchName: "blue-otter",
          baseBranch: "main",
          baseCommit: "abc123",
        )
        ..renameResult = GeneratedBranchRenamed(branchName: "generated-branch");

      final created = await service
          .createSession(
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
          )
          .timeout(const Duration(seconds: 1));

      expect((await db.sessionDao.getSession(sessionId: created.id))?.branchName, "blue-otter");
      expect(worktreeService.renameCalls, isZero);

      metadataGate.complete();
      await service.drain();

      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(stored?.branchName, "generated-branch");
      expect(stored?.currentBranchName, "generated-branch");
      expect(stored?.title, "Generated title");
      expect(worktreeService.renamedWorktreePath, "/repo/.worktrees/blue-otter");
      expect(worktreeService.renamedInitialBranchName, "blue-otter");
    });

    test("still applies the generated title when branch rename fails", () async {
      worktreeService
        ..prepareResult = WorktreeSuccess(
          path: "/repo/.worktrees/blue-otter",
          branchName: "blue-otter",
          baseBranch: "main",
          baseCommit: "abc123",
        )
        ..renameError = StateError("branch rename failed");

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
      await service.drain();

      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(stored?.branchName, "blue-otter");
      expect(stored?.title, "Generated title");
    });

    test("applies the generated title without waiting for branch refinement", () async {
      final renameStarted = Completer<void>();
      final renameGate = Completer<void>();
      worktreeService
        ..prepareResult = WorktreeSuccess(
          path: "/repo/.worktrees/blue-otter",
          branchName: "blue-otter",
          baseBranch: "main",
          baseCommit: "abc123",
        )
        ..renameStarted = renameStarted
        ..renameGate = renameGate.future;

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
      await renameStarted.future;

      try {
        final whileBranchBlocked = await db.sessionDao.getSession(sessionId: created.id);
        expect(whileBranchBlocked?.title, "Generated title");
        expect(whileBranchBlocked?.branchName, "blue-otter");
      } finally {
        renameGate.complete();
        await service.drain();
      }
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

    test("stores a dedicated-worktree fallback as in-place with the HEAD commit", () async {
      worktreeService
        ..prepareResult = WorktreeFallback(originalPath: "/fallback/repo", reason: "not git")
        ..headCommit = "fallback-head";

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

      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(plugin.lastCreateDirectory, "/fallback/repo");
      expect(stored?.directory, "/fallback/repo");
      expect(stored?.isDedicated, isFalse);
      expect(stored?.worktreePath, isNull);
      expect(stored?.baseCommit, "fallback-head");
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
        preservePullRequestScope: false,
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
  });
}

class _FakeSessionMetadataRepository() implements SessionMetadataRepository {
  int generateCalls = 0;
  Completer<void>? generateStarted;
  Future<void>? generateGate;
  bool abortOnShutdown = false;
  Completer<void>? shutdownObserved;
  Object? failure;
  final Completer<void> _shutdown = Completer<void>();

  @override
  void beginShutdown() {
    if (!_shutdown.isCompleted) _shutdown.complete();
  }

  @override
  Future<GeneratedSessionMetadata> generateMetadata({required String firstMessage}) async {
    generateCalls++;
    if (generateStarted case final started? when !started.isCompleted) started.complete();
    if (abortOnShutdown) {
      await _shutdown.future;
      shutdownObserved?.complete();
      throw SessionMetadataRequestAbortedException(
        innerError: StateError("metadata request aborted"),
        innerStackTrace: StackTrace.current,
      );
    }
    if (generateGate case final gate?) await gate;
    if (failure case final error?) throw error;
    return (
      title: "Generated title",
      branchName: "generated-branch",
    );
  }
}

Future<String> _captureWarningLog(Future<void> Function() action) async {
  final output = BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = LogLevel.warning;
    await IOOverrides.runZoned(action, stderr: () => output);
  } finally {
    Log.level = previousLevel;
  }
  return output.text;
}

class _FakeWorktreeService({required super.worktreeRepository}) extends WorktreeService {
  int prepareCalls = 0;
  int resolveCalls = 0;
  Completer<void>? prepareStarted;
  WorktreeResult prepareResult = WorktreeFallback(originalPath: "/repo", reason: "fallback");
  String? headCommit;
  GeneratedBranchRenameResult renameResult = GeneratedBranchRenameSkipped(
    reason: GeneratedBranchRenameSkipReason.initialBranchChanged,
  );
  Object? renameError;
  int renameCalls = 0;
  int rollbackCalls = 0;
  String? renamedWorktreePath;
  String? renamedInitialBranchName;
  String? renamedGeneratedBranchName;
  Completer<void>? renameStarted;
  Future<void>? renameGate;

  @override
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
  }) async {
    prepareCalls++;
    if (prepareStarted case final started? when !started.isCompleted) started.complete();
    return prepareResult;
  }

  @override
  Future<String?> resolveHeadCommit({
    required String projectId,
  }) async {
    resolveCalls++;
    return headCommit;
  }

  @override
  Future<GeneratedBranchRenameResult> renameGeneratedBranch({
    required String worktreePath,
    required String initialBranchName,
    required String generatedBranchName,
  }) async {
    renameCalls++;
    renamedWorktreePath = worktreePath;
    renamedInitialBranchName = initialBranchName;
    renamedGeneratedBranchName = generatedBranchName;
    renameStarted?.complete();
    if (renameGate case final gate?) await gate;
    if (renameError case final error?) throw error;
    return renameResult;
  }

  @override
  Future<void> rollbackGeneratedBranchRename({
    required String worktreePath,
    required String generatedBranchName,
    required String initialBranchName,
  }) async {
    rollbackCalls++;
  }
}

class _GatedNewSessionDefaultsRepository() implements NewSessionDefaultsRepository {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeGate = Completer<void>();

  @override
  Future<void> write({required String pluginId, required SessionPromptDefaults defaults}) async {
    writeStarted.complete();
    await writeGate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingNewSessionDefaultsRepository() implements NewSessionDefaultsRepository {
  @override
  Future<void> write({required String pluginId, required SessionPromptDefaults defaults}) {
    return Future.error(StateError("defaults write failed"));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlugin() implements NativeProjectsPluginApi {
  int createCalls = 0;
  String? lastCreateDirectory;
  String? lastCreateUserVisibleText;
  List<PluginPromptPart>? lastCreateParts;
  Object? sendCommandError;

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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    return PluginSession(
      id: sessionId,
      projectID: "/repo",
      directory: lastCreateDirectory ?? "/repo",
      parentID: null,
      title: title,
      time: null,
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendCommandError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
