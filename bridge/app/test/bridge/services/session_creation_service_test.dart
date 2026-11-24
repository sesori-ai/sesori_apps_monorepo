import "dart:async";
import "dart:convert";
import "dart:io";

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/daos/new_session_defaults_dao.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/repositories/new_session_defaults_repository.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/scratch_repository.dart";
import "package:sesori_bridge/src/repositories/session_metadata_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/session_abort_service.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_deletion_service.dart";
import "package:sesori_bridge/src/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/stale_session_prompt_options_exception.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show buildScheduledRunContext, buildWorktreeSystemContext;
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";
import "../../helpers/fake_session_options_service.dart";
import "../../helpers/fakes/deletion_worktree_service_fake.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/session_interruption_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../../helpers/test_drive_roots_api.dart";

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
    late FakeSessionOptionsService sessionOptionsService;
    late Directory scratchParent;
    late String scratchRoot;
    late ProjectCatalogIdentityCalculator calculator;
    late ScratchRepository scratchRepository;
    late String uploadsRoot;
    late TestPluginRuntime runtime;
    late List<LocalSessionMutation> mutations;

    setUp(() async {
      db = createTestDatabase();
      scratchParent = await Directory.systemTemp.createTemp("session-creation-scratch-");
      scratchRoot = p.join(scratchParent.path, "scratch");
      uploadsRoot = p.join(scratchParent.path, "uploads");
      calculator = ProjectCatalogIdentityCalculator(scratchRoot: scratchRoot, pathContext: p.context);
      scratchRepository = testScratchRepository(db: db, scratchRoot: scratchRoot);
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo", scratchRoot]);
      defaultsRepository = NewSessionDefaultsRepository(
        dao: NewSessionDefaultsDao(database: db),
      );
      plugin = _FakePlugin();
      metadataRepository = _FakeSessionMetadataRepository();
      sessionOptionsService = FakeSessionOptionsService();
      worktreeService = _FakeWorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          worktreesDirectory: "/worktrees",
          projectsDao: db.projectsDao,
          gitApi: GitCliApi(
            streamingProcessRunner: const StreamingProcessRunner(),
            processRunner: NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: plugin,
        ),
      );
      runtime = createTestPluginRuntime(plugins: [plugin]);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        unseenCalculator: const SessionUnseenCalculator(),
        runtime: runtime,
      );
      operationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      mutationDispatcher = SessionMutationDispatcher(
        interruptions: const NoSessionInterruptions(),
        sessionRepository: repository,
        sessionOperationDispatcher: operationDispatcher,
      );
      mutations = [];
      mutationDispatcher.mutations.listen(mutations.add);
      service = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: mutationDispatcher,
        sessionOptionsService: sessionOptionsService,
        scratchRepository: scratchRepository,
        projectCatalogIdentityCalculator: calculator,
        promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: uploadsRoot),
        sessionDeletionService: _deletionService(
          sessionRepository: repository,
          operationDispatcher: operationDispatcher,
          mutationDispatcher: mutationDispatcher,
          scratchRepository: scratchRepository,
          uploadsParent: scratchParent.path,
        ),
      );
    });

    tearDown(() async {
      await service.drain();
      await operationDispatcher.dispose();
      await mutationDispatcher.dispose();
      await db.close();
      await scratchParent.delete(recursive: true);
    });

    test("validates the project before plugin and creation side effects", () async {
      await expectLater(
        service.createSession(
          request: const CreateSessionRequest(
            commandSource: null,
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
      final useStarted = Completer<void>();
      final generateStarted = Completer<void>();
      final runtime = createTestPluginRuntime(plugins: [plugin])
        ..useStarted = useStarted
        ..useGate = pluginGate.future;
      metadataRepository
        ..generateStarted = generateStarted
        ..generateGate = metadataGate.future;
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        unseenCalculator: const SessionUnseenCalculator(),
        runtime: runtime,
      );
      final localOperationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final localMutationDispatcher = SessionMutationDispatcher(
        interruptions: const NoSessionInterruptions(),
        sessionRepository: repository,
        sessionOperationDispatcher: localOperationDispatcher,
      );
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: localMutationDispatcher,
        sessionOptionsService: sessionOptionsService,
        scratchRepository: scratchRepository,
        projectCatalogIdentityCalculator: calculator,
        promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
        sessionDeletionService: _UnusedSessionDeletionService(),
      );

      final creation = localService.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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

      await useStarted.future;
      expect(metadataRepository.generateCalls, isZero);
      pluginGate.complete();
      await generateStarted.future;
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
          commandSource: null,
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

    test("generates metadata from a dictated message's plain words and sends the agent the marked form", () async {
      final marked = wrapDictatedText(text: "Build it");

      await service.createSession(
        request: CreateSessionRequest(
          commandSource: null,
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: marked)],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );
      await service.drain();

      expect(metadataRepository.lastFirstMessage, "Build it");
      expect(plugin.lastCreateUserVisibleText, marked);
    });

    test("shutdown aborts and drains the underlying metadata workflow", () async {
      final generateStarted = Completer<void>();
      metadataRepository
        ..generateStarted = generateStarted
        ..abortOnShutdown = true
        ..shutdownObserved = Completer<void>();

      final created = await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
      await generateStarted.future;

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
            commandSource: null,
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
        unseenCalculator: const SessionUnseenCalculator(),
        runtime: runtime,
      );
      final localOperationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final localMutationDispatcher = SessionMutationDispatcher(
        interruptions: const NoSessionInterruptions(),
        sessionRepository: repository,
        sessionOperationDispatcher: localOperationDispatcher,
      );
      final localService = SessionCreationService(
        sessionMetadataRepository: metadataRepository,
        worktreeService: worktreeService,
        sessionRepository: repository,
        newSessionDefaultsRepository: defaultsRepository,
        sessionMutationDispatcher: localMutationDispatcher,
        sessionOptionsService: sessionOptionsService,
        scratchRepository: scratchRepository,
        projectCatalogIdentityCalculator: calculator,
        promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
        sessionDeletionService: _UnusedSessionDeletionService(),
      );

      final creation = localService.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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

    test("maps stale command selections during creation to a typed rejection", () async {
      plugin.sendCommandError = const PluginStaleOptionsException(
        operation: "sendCommand",
        message: "unsupported command model",
      );

      await expectLater(
        service.createSession(
          request: const CreateSessionRequest(
            commandSource: null,
            projectId: "/repo",
            pluginId: "fake",
            dedicatedWorktree: false,
            parts: [PromptPart.text(text: "Review it")],
            variant: SessionVariant(id: "high"),
            agent: null,
            model: PromptModel(providerID: "provider", modelID: "withdrawn"),
            command: "review",
          ),
        ),
        throwsA(
          isA<StaleSessionPromptOptionsException>().having(
            (error) => error.cause,
            "cause",
            isA<PluginStaleOptionsException>(),
          ),
        ),
      );
      expect(metadataRepository.generateCalls, isZero);
      expect(await defaultsRepository.read(pluginId: "fake"), isNull);
      expect(sessionOptionsService.explicitInvalidations, [(pluginId: "fake", projectId: "/repo")]);
      // The refused session is deleted, and the deletion event removes its row.
      expect(plugin.deletedSessionIds, ["backend-session"]);
      expect(mutations.whereType<SessionDeleted>().map((mutation) => mutation.session.id), hasLength(1));
      expect(await db.sessionDao.getSession(sessionId: mutations.single.session.id), isNull);
    });

    test("a scheduled run whose command is refused as stale deletes the session before the retry", () async {
      plugin.sendCommandError = const PluginStaleOptionsException(
        operation: "sendCommand",
        message: "unsupported command model",
      );

      await expectLater(
        service.createScheduledRunSession(
          request: const CreateSessionRequest(
            commandSource: null,
            projectId: "/repo",
            pluginId: "fake",
            dedicatedWorktree: false,
            parts: [PromptPart.text(text: "Review it")],
            variant: SessionVariant(id: "high"),
            agent: null,
            model: PromptModel(providerID: "provider", modelID: "withdrawn"),
            command: "review",
          ),
          scheduledRun: (taskId: "stk_nightly", approvalOverride: SessionApprovalMode.yolo),
          runContext: null,
        ),
        throwsA(isA<StaleSessionPromptOptionsException>()),
      );

      expect(plugin.deletedSessionIds, ["backend-session"]);
      expect(mutations.whereType<SessionDeleted>(), hasLength(1));
      expect(await db.sessionDao.getSession(sessionId: mutations.single.session.id), isNull);
    });

    test("stores the created root and remembers its complete plugin-scoped selection", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-one",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final created = await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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

      final stored = await db.sessionDao.getSession(sessionId: created.id) ?? fail("missing stored session");
      expect(created.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(created.id, isNot("backend-session"));
      expect(stored.backendSessionId, "backend-session");
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

    test("a scheduled run links its task and approval mode and remembers no picks", () async {
      final task = await ScheduledTaskRepository(dao: ScheduledTaskDao(database: db)).create(
        definition: const ScheduledTaskDefinition(
          name: "Nightly",
          prompt: ScheduledTaskPrompt.text(text: "Build it"),
          projectId: "/repo",
          pluginId: "fake",
          agent: "build",
          model: null,
          variant: null,
          fastMode: false,
          dedicatedWorktree: false,
          schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)),
          timeZone: "UTC",
          missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
          runMode: TaskRunMode.newSession(),
          approvalMode: TaskApprovalMode.approveAll,
        ),
        nextDueAt: null,
        now: DateTime.utc(2026, 11, 15),
      );
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-one",
        baseBranch: "main",
        baseCommit: "abc123",
      );
      final runNote = buildScheduledRunContext(taskName: "Nightly", taskId: task.id);

      final created = await service.createScheduledRunSession(
        request: const CreateSessionRequest(
          commandSource: null,
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: true,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: "build",
          model: null,
          command: null,
        ),
        scheduledRun: (taskId: task.id, approvalOverride: SessionApprovalMode.yolo),
        runContext: runNote,
      );
      await pumpEventQueue();

      final stored = await db.sessionDao.getSession(sessionId: created.id) ?? fail("missing stored session");
      expect(stored.scheduledTaskId, task.id);
      expect(stored.approvalOverride, SessionApprovalMode.yolo);
      expect(await defaultsRepository.read(pluginId: "fake"), isNull);
      // The run note follows the worktree note, for the harness only.
      expect(plugin.lastCreateParts, [
        PluginPromptPart.text(
          text: buildWorktreeSystemContext(worktreePath: "/repo/.worktrees/session-one", baseBranch: "main"),
        ),
        PluginPromptPart.text(text: runNote),
        const PluginPromptPart.text(text: "Build it"),
      ]);
      expect(plugin.lastCreateUserVisibleText, "Build it");
    });

    test("a scheduled run whose task was deleted meanwhile still binds, as an ordinary session", () async {
      final created = await service.createScheduledRunSession(
        request: const CreateSessionRequest(
          commandSource: null,
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.text(text: "Build it")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
        scheduledRun: (taskId: "stk_deleted", approvalOverride: SessionApprovalMode.yolo),
        runContext: null,
      );

      final stored = await db.sessionDao.getSession(sessionId: created.id) ?? fail("missing stored session");
      expect(stored.scheduledTaskId, isNull);
      expect(stored.approvalOverride, SessionApprovalMode.yolo);
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
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        newSessionDefaultsRepository: gatedDefaultsRepository,
        sessionMutationDispatcher: mutationDispatcher,
        sessionOptionsService: sessionOptionsService,
        scratchRepository: scratchRepository,
        projectCatalogIdentityCalculator: calculator,
        promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
        sessionDeletionService: _UnusedSessionDeletionService(),
      );
      var creationCompleted = false;
      final creation = localService.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        newSessionDefaultsRepository: _ThrowingNewSessionDefaultsRepository(),
        sessionMutationDispatcher: mutationDispatcher,
        sessionOptionsService: sessionOptionsService,
        scratchRepository: scratchRepository,
        projectCatalogIdentityCalculator: calculator,
        promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
        sessionDeletionService: _UnusedSessionDeletionService(),
      );
      late Session created;

      final output = await _captureWarningLog(() async {
        created = await localService.createSession(
          request: const CreateSessionRequest(
            commandSource: null,
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

    test("stores no branch for a dedicated session and tells the agent to create one", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/blue-otter",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final created = await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
      expect(stored?.isDedicated, isTrue);
      expect(stored?.worktreePath, "/repo/.worktrees/blue-otter");
      expect(stored?.branchName, isNull);
      expect(stored?.baseBranch, "main");
      expect(stored?.title, "Generated title");
      expect(
        plugin.lastCreateParts?.first,
        isA<PluginPromptPartText>().having(
          (part) => part.text,
          "text",
          allOf(
            contains("- Worktree path: /repo/.worktrees/blue-otter"),
            contains("This worktree is on a detached HEAD at the latest commit of main."),
            contains("Before your first commit, create a branch for this task"),
            contains("Do NOT create another worktree or working directory"),
            isNot(contains("Branch:")),
          ),
        ),
      );
    });

    test("projects every nonblank user text part without bridge-owned context", () async {
      worktreeService.prepareResult = WorktreeSuccess(
        path: "/repo/.worktrees/session-one",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
      expect(
        plugin.lastCreateParts?.first,
        isA<PluginPromptPartText>().having((part) => part.text, "text", contains("SYSTEM CONTEXT")),
      );
    });

    test("saves a file under the id the session is committed with and notes it in place", () async {
      final created = await service.createSession(
        request: CreateSessionRequest(
          commandSource: null,
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [
            const PromptPart.text(text: "Read this"),
            PromptPart.fileData(
              mime: "application/octet-stream",
              base64: base64Encode(utf8.encode("notes")),
              filename: "notes.txt",
            ),
            const PromptPart.text(text: "Then summarize it"),
          ],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
      );
      await service.drain();

      final savedFolders = Directory(p.join(uploadsRoot, created.id)).listSync();
      expect(savedFolders, hasLength(1));
      final savedPath = p.join(savedFolders.single.path, "notes.txt");
      expect(File(savedPath).readAsStringSync(), "notes");
      final note = 'Attached file "notes.txt": `$savedPath`';
      expect(plugin.lastCreateParts, [_pluginText("Read this"), _pluginText(note), _pluginText("Then summarize it")]);
      expect(plugin.lastCreateUserVisibleText, "Read this\n\n$note\n\nThen summarize it");
      expect(metadataRepository.lastFirstMessage, "Read this");
    });

    test("passes an image inline to a plugin that takes images", () async {
      await service.createSession(request: _imageOnlyRequest);

      expect(plugin.lastCreateParts, [isA<PluginPromptPartFileData>()]);
      expect(Directory(uploadsRoot).existsSync(), isFalse);
    });

    test("saves an image for a plugin that doesn't take images", () async {
      runtime.promptAttachmentPluginIds.remove("fake");

      final created = await service.createSession(request: _imageOnlyRequest);
      await service.drain();

      expect(plugin.lastCreateParts, [_pluginText(startsWith('Attached file "shot.png": `'))]);
      expect(Directory(p.join(uploadsRoot, created.id)).listSync(), hasLength(1));
    });

    test("saves nothing for a create that sends a command", () async {
      await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
          projectId: "/repo",
          pluginId: "fake",
          dedicatedWorktree: false,
          parts: [PromptPart.fileData(mime: "application/octet-stream", base64: "bm90ZXM=", filename: "notes.txt")],
          variant: null,
          agent: null,
          model: null,
          command: "review",
        ),
      );
      await service.drain();

      expect(Directory(uploadsRoot).existsSync(), isFalse);
    });

    test("stores the HEAD commit for an in-place session", () async {
      worktreeService.headCommit = "abc123";

      final created = await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
          commandSource: null,
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

    test("runs a scratch session in a new dated folder and ignores a dedicated-worktree request", () async {
      final created = await withClock(
        Clock.fixed(DateTime(2026, 3, 7, 23, 30)),
        () => service.createSession(
          request: CreateSessionRequest(
            commandSource: null,
            projectId: scratchRoot,
            pluginId: "fake",
            dedicatedWorktree: true,
            parts: const [PromptPart.text(text: "Build it")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
        ),
      );

      final folders = Directory(scratchRoot).listSync();
      expect(folders, hasLength(1));
      final folder = folders.single;
      expect(folder, isA<Directory>());
      expect(p.dirname(folder.path), scratchRoot);
      expect(p.basename(folder.path), startsWith("2026-03-07-"));
      expect(plugin.lastCreateDirectory, folder.path);
      expect(plugin.lastCreateParts, [const PluginPromptPart.text(text: "Build it")]);
      expect(worktreeService.prepareCalls, isZero);
      expect(worktreeService.resolveCalls, isZero);
      final stored = await db.sessionDao.getSession(sessionId: created.id);
      expect(stored?.projectId, scratchRoot);
      expect(stored?.directory, folder.path);
      expect(stored?.isDedicated, isFalse);
      expect(stored?.worktreePath, isNull);
      expect(stored?.branchName, isNull);
      expect(stored?.baseCommit, isNull);
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
        fastMode: false,
        sessionId: "backend-session",
        backendSessionId: "backend-session",
        pluginId: "other",
        projectId: "/retained",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final created = await service.createSession(
        request: const CreateSessionRequest(
          commandSource: null,
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
  String? lastFirstMessage;
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
    lastFirstMessage = firstMessage;
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
    return (title: "Generated title");
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

  @override
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
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

const _imageOnlyRequest = CreateSessionRequest(
  commandSource: null,
  projectId: "/repo",
  pluginId: "fake",
  dedicatedWorktree: false,
  parts: [PromptPart.fileData(mime: "image/png", base64: "iVBORw0KGgo=", filename: "shot.png")],
  variant: null,
  agent: null,
  model: null,
  command: null,
);

Matcher _pluginText(Object? text) => isA<PluginPromptPartText>().having((part) => part.text, "text", text);

class _FakePlugin() implements NativeProjectsPluginApi {
  int createCalls = 0;
  String? lastCreateDirectory;
  String? lastCreateUserVisibleText;
  List<PluginPromptPart>? lastCreateParts;
  Object? sendCommandError;
  final List<String> deletedSessionIds = [];

  @override
  Future<void> deleteSession(String sessionId) async => deletedSessionIds.add(sessionId);

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
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (userVisibleText == null && variant != null) throw StateError("command variant applied during creation");
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
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendCommandError != null && variant?.id != "high") throw StateError("missing command variant");
    if (sendCommandError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SessionDeletionService _deletionService({
  required SessionRepository sessionRepository,
  required SessionOperationDispatcher operationDispatcher,
  required SessionMutationDispatcher mutationDispatcher,
  required ScratchRepository scratchRepository,
  required String uploadsParent,
}) {
  final chatHistory = createTestChatHistory();
  return SessionDeletionService(
    sessionLifecycleService: SessionLifecycleService(
      continuations: const EmptySessionContinuations(),
      mutations: const UnusedContinuationMutations(),
      views: const PassThroughSessionViews(),
      abortService: SessionAbortService(
        sessionRepository: sessionRepository,
        dispatcher: operationDispatcher,
        continuations: const EmptySessionContinuations(),
        views: const PassThroughSessionViews(),
        mutations: const UnusedContinuationMutations(),
      ),
      stopDeadline: Duration.zero,
      worktreeService: DeletionWorktreeServiceFake(),
      sessionRepository: sessionRepository,
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      ),
      sessionOperationDispatcher: operationDispatcher,
      archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
      chatHistoryService: chatHistory.service,
    ),
    sessionMutationDispatcher: mutationDispatcher,
    chatHistoryService: chatHistory.service,
    scratchRepository: scratchRepository,
    promptUploadRepository: PromptUploadRepository(
      filesystemApi: const FilesystemApi(),
      uploadsRoot: p.join(uploadsParent, "uploads"),
    ),
    transcriptRepository: PromptUploadRepository(
      filesystemApi: const FilesystemApi(),
      uploadsRoot: p.join(uploadsParent, "transcripts"),
    ),
    pageImageRepository: PromptUploadRepository(
      filesystemApi: const FilesystemApi(),
      uploadsRoot: p.join(uploadsParent, "page-images"),
    ),
    commandOutputRepository: PromptUploadRepository(
      filesystemApi: const FilesystemApi(),
      uploadsRoot: p.join(uploadsParent, "command-output"),
    ),
  );
}

class _UnusedSessionDeletionService() implements SessionDeletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
