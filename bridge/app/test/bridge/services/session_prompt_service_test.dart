import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("SessionPromptService command dispatch", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late CommandDispatcher commandDispatcher;
    late SessionPromptService service;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      final commandStack = TestCommandStack(db);
      sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      commandDispatcher = commandStack.dispatcher(
        plugin: plugin,
        sessionRepository: sessionRepository,
      );
      service = SessionPromptService(
        sessionRepository: sessionRepository,
        commandDispatcher: commandDispatcher,
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
      await commandDispatcher.dispose();
      await plugin.close();
      await db.close();
    });

    Future<void> sendCommand({String command = "review"}) {
      return service.sendPrompt(
        sessionId: "s1",
        parts: const [PromptPart.text(text: "extra args")],
        variant: null,
        agent: null,
        model: null,
        command: command,
      );
    }

    test("normalizes the command name and records its arguments", () async {
      await sendCommand(command: "  review  ");

      expect(plugin.lastSendCommandSessionId, equals("backend-s1"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("extra args"));
      final stored = await db.commandInvocationDao.getInvocationsForSession(
        pluginId: "fake",
        sessionId: "s1",
      );
      expect(stored.single.name, "review");
      expect(stored.single.arguments, "extra args");
    });

    test("records blank command arguments as absent", () async {
      await service.sendPrompt(
        sessionId: "s1",
        parts: const [PromptPart.text(text: "   ")],
        variant: null,
        agent: null,
        model: null,
        command: "review",
      );

      expect(plugin.lastSendCommandArguments, isEmpty);
      final stored = await db.commandInvocationDao.getInvocationsForSession(
        pluginId: "fake",
        sessionId: "s1",
      );
      expect(stored.single.arguments, isNull);
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

    test("plain prompts are unaffected and delegate to sendPrompt", () async {
      await service.sendPrompt(
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
  });
}
