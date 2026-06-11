import "dart:async";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("SessionPromptService command dispatch", () {
    const fastFailWindow = Duration(milliseconds: 50);

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
      );
      service = SessionPromptService(
        sessionRepository: sessionRepository,
        sseManager: FakeSSEManager(),
        commandDispatchFastFailWindow: fastFailWindow,
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

    test("completes when the command finishes within the window", () async {
      await sendCommand();

      expect(plugin.lastSendCommandSessionId, equals("s1"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("extra args"));
    });

    test("propagates a failure raised within the window", () async {
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;
      completer.completeError(StateError("unknown command"));

      await expectLater(sendCommand(), throwsA(isA<StateError>()));
    });

    test("propagates a TimeoutException raised by the send chain within the window", () async {
      // Must not be conflated with the fast-fail window elapsing: a timeout
      // thrown by the send chain itself is a genuine dispatch failure.
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;
      completer.completeError(TimeoutException("inner send timeout"));

      await expectLater(sendCommand(), throwsA(isA<TimeoutException>()));
    });

    test("completes after the window when the command run keeps going", () async {
      // Simulates OpenCode's synchronous /command endpoint: the HTTP response
      // only arrives after the full agent run. The service must not hold the
      // phone's request open that long.
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;

      final stopwatch = Stopwatch()..start();
      await sendCommand();
      stopwatch.stop();

      expect(plugin.lastSendCommand, equals("review"));
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: "dispatch must detach instead of awaiting the full run",
      );

      completer.complete();
    });

    test("swallows and logs a failure raised after the window", () async {
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;

      await sendCommand();

      completer.completeError(StateError("run failed mid-flight"));
      // Flush microtasks — an unhandled async error would fail the test zone.
      await Future<void>.delayed(Duration.zero);
    });

    test("still updates prompt defaults when the command run outlives the window", () async {
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
      final completer = Completer<void>();
      plugin.sendCommandCompleter = completer;

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

      completer.complete();
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
