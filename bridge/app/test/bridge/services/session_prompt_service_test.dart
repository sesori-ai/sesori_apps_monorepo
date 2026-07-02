import "dart:async";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
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
    late SessionPromptService service;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      service = SessionPromptService(
        sessionRepository: sessionRepository,
        sseManager: FakeSSEManager(),
      );
    });

    tearDown(() async {
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

    test("sends the command and records normalized arguments", () async {
      await sendCommand();

      expect(plugin.lastSendCommandSessionId, equals("s1"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("extra args"));
    });

    test("propagates a command dispatch failure", () async {
      // The fast-fail dispatch window lives inside the OpenCode plugin (see
      // OpenCodeService) — the bridge stays plugin-agnostic and simply
      // surfaces whatever the plugin throws.
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;
      completer.completeError(StateError("unknown command"));

      await expectLater(sendCommand(), throwsA(isA<StateError>()));
    });

    test("updates prompt defaults after the command is dispatched", () async {
      await sessionRepository.insertStoredSession(
        sessionId: "s-defaults-command",
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

    test("plain prompts are unaffected and delegate to sendPrompt", () async {
      await service.sendPrompt(
        sessionId: "s1",
        parts: const [PromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: null,
        command: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("s1"));
      expect(plugin.lastSendCommand, isNull);
    });
  });
}
