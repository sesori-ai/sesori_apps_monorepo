import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_bridge/src/bridge/services/session_abort_service.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_bridge/src/bridge/services/stale_session_prompt_options_exception.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_session_options_service.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("SessionPromptService command dispatch", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late SessionOperationDispatcher dispatcher;
    late FakeSessionOptionsService optionsService;
    late SessionPromptService service;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      optionsService = FakeSessionOptionsService();
      service = SessionPromptService(
        sessionRepository: sessionRepository,
        dispatcher: dispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
        sessionOptionsService: optionsService,
      );
      await sessionRepository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
    });

    tearDown(() async {
      await service.dispose();
      await dispatcher.dispose();
      await plugin.close();
      await db.close();
    });

    Future<void> sendCommand({String command = "review"}) {
      return service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s1",
        parts: const [PromptPart.text(text: "extra args")],
        variant: null,
        agent: null,
        model: null,
        command: command,
      );
    }

    test("sends the command and records normalized arguments", () async {
      await sendCommand();

      expect(plugin.lastSendCommandSessionId, equals("backend-s1"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("extra args"));
      expect(plugin.lastSendCommandUserVisibleArguments, equals("extra args"));
    });

    test("refuses a prompt to an archived session without reaching the plugin", () async {
      await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

      await expectLater(
        service.sendPrompt(
          promptId: "prompt-1",
          sessionId: "s1",
          parts: const [PromptPart.text(text: "hello")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
        throwsA(
          isA<SessionArchivedReadOnlyException>().having(
            (e) => e.rejection,
            "rejection",
            const SessionArchivedRejection(sessionId: "s1", reason: SessionArchivedReason.archivedReadOnly),
          ),
        ),
      );
      expect(plugin.lastSendPromptSessionId, isNull);
    });

    test("refuses a command to an archived session without reaching the plugin", () async {
      await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

      await expectLater(sendCommand(), throwsA(isA<SessionArchivedReadOnlyException>()));
      expect(plugin.lastSendCommandSessionId, isNull);
    });

    test("propagates a command dispatch failure", () async {
      // The fast-fail dispatch window lives inside the OpenCode plugin (see
      // OpenCodeService) — the bridge stays plugin-agnostic and simply
      // surfaces whatever the plugin throws.
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;

      // Attach the expectation first, then wait until the plugin has reached
      // and started awaiting its injected future before failing it.
      final pending = expectLater(sendCommand(), throwsA(isA<StateError>()));
      while (plugin.lastSendCommandSessionId == null) {
        await Future<void>.delayed(Duration.zero);
      }
      completer.completeError(StateError("unknown command"));
      await pending;
    });

    test("updates prompt defaults after the command is dispatched", () async {
      await sessionRepository.insertStoredSession(
        sessionId: "s-defaults-command",
        backendSessionId: "backend-defaults-command",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: "old-agent",
        agentModel: null,
      );
      await service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s-defaults-command",
        parts: const [PromptPart.text(text: "")],
        variant: const SessionVariant(id: "low"),
        agent: "planner",
        model: const PromptModel(providerID: "openai", modelID: "gpt-4o"),
        command: "review",
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s-defaults-command");
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("planner"));
      expect(dbSession.lastAgentModel?.providerID, equals("openai"));
      expect(dbSession.lastAgentModel?.modelID, equals("gpt-4o"));
      expect(dbSession.lastAgentModel?.variant, equals("low"));
    });

    test("emits committed prompt default changes", () async {
      await sessionRepository.insertStoredSession(
        sessionId: "s-defaults-event",
        backendSessionId: "backend-defaults-event",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      final changeFuture = service.promptDefaultsChanges.first;

      await service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s-defaults-event",
        parts: const [PromptPart.text(text: "Hello")],
        variant: const SessionVariant(id: "high"),
        agent: "planner",
        model: const PromptModel(providerID: "openai", modelID: "gpt-5"),
        command: null,
      );

      final change = await changeFuture;
      expect(change.sessionId, "s-defaults-event");
      expect(change.promptDefaults.agent, "planner");
      expect(change.promptDefaults.model?.providerID, "openai");
      expect(change.promptDefaults.model?.modelID, "gpt-5");
      expect(change.promptDefaults.model?.variant, "high");
    });

    test("suppresses completion immediately while backend actions retain arrival order", () async {
      final abortService = SessionAbortService(
        sessionRepository: sessionRepository,
        dispatcher: dispatcher,
      );
      addTearDown(abortService.dispose);
      final events = <String>[];
      final defaultsSubscription = service.promptDefaultsChanges.listen(
        (change) => events.add("defaults:${change.promptDefaults.agent}"),
      );
      final abortSubscription = abortService.abortStartedSessions.listen(
        (_) => events.add("abort"),
      );
      addTearDown(defaultsSubscription.cancel);
      addTearDown(abortSubscription.cancel);
      final commandGate = Completer<void>();
      plugin.sendCommandCompleter = commandGate;

      final command = service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s1",
        parts: const [PromptPart.text(text: "arguments")],
        variant: null,
        agent: "first",
        model: null,
        command: "review",
      );
      while (plugin.lastSendCommandSessionId == null) {
        await Future<void>.delayed(Duration.zero);
      }
      final abort = abortService.abortSession(sessionId: "s1");
      final prompt = service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s1",
        parts: const [PromptPart.text(text: "later")],
        variant: null,
        agent: "second",
        model: null,
        command: null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, ["abort"]);
      expect(plugin.lastAbortSessionId, isNull);
      expect(plugin.lastSendPromptSessionId, isNull);

      commandGate.complete();
      await Future.wait([command, abort, prompt]);
      expect(events, ["abort", "defaults:first", "defaults:second"]);
      expect((await db.sessionDao.getSession(sessionId: "s1"))!.lastAgent, "second");
    });

    test("plain prompts are unaffected and delegate to sendPrompt", () async {
      await service.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s1",
        parts: const [PromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: null,
        command: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("backend-s1"));
      expect(plugin.lastSendCommand, isNull);
    });

    test("invalidates the options cache and rethrows when the plugin reports stale options", () async {
      plugin.sendPromptError = const PluginStaleOptionsException("sendPrompt", message: "unsupported agent");

      await expectLater(
        service.sendPrompt(
          promptId: "prompt-1",
          sessionId: "s1",
          parts: const [PromptPart.text(text: "Hello")],
          variant: null,
          agent: "removed-agent",
          model: null,
          command: null,
        ),
        throwsA(
          isA<StaleSessionPromptOptionsException>().having(
            (error) => error.cause,
            "cause",
            isA<PluginStaleOptionsException>(),
          ),
        ),
      );

      expect(optionsService.explicitInvalidations.single, (pluginId: "fake", projectId: "/repo"));
      // The rejected selection is not persisted as the session's defaults.
      expect((await db.sessionDao.getSession(sessionId: "s1"))!.lastAgent, isNull);
    });
  });
}
