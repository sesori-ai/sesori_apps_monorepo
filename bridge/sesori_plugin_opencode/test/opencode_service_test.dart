import "dart:async";
import "dart:io" as io;

import "package:opencode_plugin/opencode_plugin.dart" hide Message, MessageError, MessageErrorData, MessageWithParts;
import "package:opencode_plugin/src/models/message.dart" as plugin_msg;
import "package:opencode_plugin/src/models/message_with_parts.dart" as plugin;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show ActiveSession, ProjectActivitySummary;
import "package:test/test.dart";

void main() {
  group("OpenCodeService.getProjects", () {
    test("delegates to repository and returns result", () async {
      final repository = FakeOpenCodeRepository(
        projects: [
          const Project(id: "p1", worktree: "/repo-a"),
          const Project(id: "p2", worktree: "/repo-b"),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final projects = await service.getProjects();

      expect(repository.getProjectsCalls, equals(1));
      expect(projects.map((p) => p.id).toList(), equals(["p1", "p2"]));
    });
  });

  group("OpenCodeService.getCommands", () {
    test("returns upstream commands alongside the synthetic compact command", () async {
      final repository = FakeOpenCodeRepository(
        commands: const [
          PluginCommand(name: "review-work", provider: "openai", source: PluginCommandSource.skill),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final commands = await service.getCommands(projectId: "/repo");

      expect(repository.lastCommandsProjectId, equals("/repo"));
      expect(
        commands.map((command) => command.name),
        containsAll(["review-work", OpenCodeService.compactionCommandName]),
      );
    });

    test("appends a compact command carrying display metadata", () async {
      final service = OpenCodeService(FakeOpenCodeRepository(), FakeActiveSessionTracker());

      final commands = await service.getCommands(projectId: "/repo");

      final compact = commands.singleWhere(
        (command) => command.name == OpenCodeService.compactionCommandName,
      );
      expect(compact.description, isNotNull);
      expect(compact.source, equals(PluginCommandSource.command));
    });

    test("does not duplicate compact when the project already defines one", () async {
      final repository = FakeOpenCodeRepository(
        commands: const [
          PluginCommand(name: "compact", provider: null, source: PluginCommandSource.command),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final commands = await service.getCommands(projectId: "/repo");

      expect(
        commands.where((command) => command.name == OpenCodeService.compactionCommandName),
        hasLength(1),
      );
    });
  });

  group("OpenCodeService.getAgents", () {
    test("passes the projectId through as the directory", () async {
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await service.getAgents(projectId: "/repo");

      expect(repository.lastAgentsDirectory, equals("/repo"));
    });

    test("falls back to the current working directory when projectId is null", () async {
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await service.getAgents(projectId: null);

      expect(repository.lastAgentsDirectory, equals(io.Directory.current.path));
    });
  });

  group("OpenCodeService.getSessions", () {
    final sessions = [
      const Session(id: "s1", projectID: "p1", directory: "/repo"),
      const Session(id: "s2", projectID: "p1", directory: "/repo"),
      const Session(id: "s3", projectID: "p1", directory: "/repo"),
      const Session(id: "s4", projectID: "p1", directory: "/repo"),
    ];

    test("returns all sessions when no start/limit", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo");

      expect(repository.lastWorktree, equals("/repo"));
      expect(
        result.map((s) => s.id).toList(),
        equals(["s1", "s2", "s3", "s4"]),
      );
    });

    test("applies start correctly", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo", start: 2);

      expect(result.map((s) => s.id).toList(), equals(["s3", "s4"]));
    });

    test("applies limit correctly", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo", limit: 2);

      expect(result.map((s) => s.id).toList(), equals(["s1", "s2"]));
    });

    test("applies both start and limit", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(
        worktree: "/repo",
        start: 1,
        limit: 2,
      );

      expect(result.map((s) => s.id).toList(), equals(["s2", "s3"]));
    });

    test("start beyond list length returns empty", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo", start: 10);

      expect(result, isEmpty);
    });

    test("limit of 0 returns all", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo", limit: 0);

      expect(
        result.map((s) => s.id).toList(),
        equals(["s1", "s2", "s3", "s4"]),
      );
    });

    test("start of 0 returns all", () async {
      final repository = FakeOpenCodeRepository(sessions: sessions);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getSessions(worktree: "/repo", start: 0);

      expect(
        result.map((s) => s.id).toList(),
        equals(["s1", "s2", "s3", "s4"]),
      );
    });
  });

  group("OpenCodeService.getMessages", () {
    test("returns all messages from api", () async {
      final repository = FakeOpenCodeRepository(
        messages: [
          _msg("assistant", "m1"),
          _msg("user", "m2"),
          _msg("assistant", "m3"),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getMessages(sessionId: "ses-1", directory: null);

      expect(result.map(_messageId).toList(), equals(["m1", "m2", "m3"]));
      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
    });

    test("passes directory to api when provided", () async {
      final repository = FakeOpenCodeRepository(messages: [_msg("user", "m1")]);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await service.getMessages(sessionId: "ses-1", directory: "/repo");

      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
      expect(repository.api.lastRequestedDirectory, equals("/repo"));
    });

    test("empty list returns empty", () async {
      final repository = FakeOpenCodeRepository(messages: const []);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getMessages(sessionId: "ses-1", directory: null);

      expect(result, isEmpty);
    });

    test("surfaces upstream decode failures as PluginApiException 502", () async {
      final repository = FakeOpenCodeRepository(
        messagesError: const FormatException("invalid message payload"),
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await expectLater(
        () => service.getMessages(sessionId: "ses-1", directory: null),
        throwsA(
          isA<PluginApiException>()
              .having((error) => error.statusCode, "statusCode", equals(502))
              .having((error) => error.endpoint, "endpoint", equals("GET /session/ses-1/message")),
        ),
      );
      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
    });

    test("rethrows unexpected non-decode bugs", () async {
      final repository = FakeOpenCodeRepository(
        messagesError: StateError("unexpected bug"),
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await expectLater(
        () => service.getMessages(sessionId: "ses-1", directory: null),
        throwsA(isA<StateError>().having((error) => error.message, "message", equals("unexpected bug"))),
      );
      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
    });
  });

  group("OpenCodeService.getPendingQuestionsForSession", () {
    test("returns root-session question with known directory", () async {
      final repository = FakeOpenCodeRepository(
        pendingQuestionsByDirectory: {
          "/repo": [_question(id: "q-root", sessionId: "root")],
        },
      );
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"root": "/repo"});
      final service = OpenCodeService(repository, tracker);

      final questions = await service.getPendingQuestionsForSession(sessionId: "root");

      expect(questions.map((question) => question.id), equals(["q-root"]));
      expect(repository.pendingQuestionDirectories, equals(["/repo"]));
      expect(repository.getSessionCalls, equals(0));
    });

    test("resolves unknown directory via getSession, registers it, and returns question", () async {
      final repository = FakeOpenCodeRepository(
        sessions: const [Session(id: "root", projectID: "p1", directory: "/repo")],
        pendingQuestionsByDirectory: {
          "/repo": [_question(id: "q-root", sessionId: "root")],
        },
      );
      final tracker = FakeActiveSessionTracker();
      final service = OpenCodeService(repository, tracker);

      final questions = await service.getPendingQuestionsForSession(sessionId: "root");

      expect(questions.map((question) => question.id), equals(["q-root"]));
      expect(repository.lastGetSessionId, equals("root"));
      expect(repository.lastGetSessionDirectory, isNull);
      expect(tracker.lastRegisteredSessionId, equals("root"));
      expect(tracker.lastRegisteredDirectory, equals("/repo"));
      expect(repository.pendingQuestionDirectories, equals(["/repo"]));
    });

    test("excludes sibling-root questions in the same directory", () async {
      final repository = FakeOpenCodeRepository(
        pendingQuestionsByDirectory: {
          "/repo": [
            _question(id: "q-root", sessionId: "root"),
            _question(id: "q-sibling", sessionId: "sibling"),
          ],
        },
      );
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"root": "/repo"});
      final service = OpenCodeService(repository, tracker);

      final questions = await service.getPendingQuestionsForSession(sessionId: "root");

      expect(questions.map((question) => question.id), equals(["q-root"]));
    });
  });

  group("OpenCodeService.createSession", () {
    test("creates session, registers tracker directory, sends first prompt, and returns canonical project", () async {
      final tracker = FakeActiveSessionTracker(resolvedWorktree: "/canonical-repo");
      final repository = FakeOpenCodeRepository(
        createdSession: const PluginSession(
          id: "ses-new",
          projectID: "/repo",
          directory: "/repo/subdir",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      );
      final service = OpenCodeService(repository, tracker);
      const parts = [PluginPromptPart.text(text: "Start")];

      final session = await service.createSession(
        directory: "/repo",
        parentSessionId: "parent-1",
        parts: parts,
        agent: "build",
        variant: const PluginSessionVariant(id: "low"),
        model: (providerID: "openai", modelID: "gpt-5.4"),
      );

      expect(repository.lastCreateDirectory, equals("/repo"));
      expect(repository.lastCreateParentSessionId, equals("parent-1"));
      expect(tracker.lastRegisteredSessionId, equals("ses-new"));
      expect(tracker.lastRegisteredDirectory, equals("/repo/subdir"));
      expect(repository.lastPromptSessionId, equals("ses-new"));
      expect(repository.lastPromptDirectory, equals("/repo/subdir"));
      expect(repository.lastPromptParts, equals(parts));
      expect(repository.lastPromptAgent, equals("build"));
      expect(repository.lastPromptVariant, equals("low"));
      expect(repository.lastPromptModel?.providerID, equals("openai"));
      expect(repository.lastPromptModel?.modelID, equals("gpt-5.4"));
      expect(session.id, equals("ses-new"));
      expect(session.projectID, equals("/repo"));
    });

    test("skips first prompt when create session parts are empty", () async {
      final tracker = FakeActiveSessionTracker(resolvedWorktree: "/canonical-repo");
      final repository = FakeOpenCodeRepository(
        createdSession: const PluginSession(
          id: "ses-new",
          projectID: "/repo",
          directory: "/repo/subdir",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      );
      final service = OpenCodeService(repository, tracker);

      final session = await service.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        agent: null,
        variant: null,
        model: null,
      );

      expect(repository.lastPromptSessionId, isNull);
      expect(session.id, equals("ses-new"));
    });

    test("returns created session when first prompt send fails", () async {
      final tracker = FakeActiveSessionTracker();
      final repository = FakeOpenCodeRepository(
        createdSession: const PluginSession(
          id: "ses-new",
          projectID: "/repo",
          directory: "/repo/subdir",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      )..sendPromptError = StateError("prompt failed");
      final service = OpenCodeService(repository, tracker);

      await expectLater(
        () => service.createSession(
          directory: "/repo",
          parentSessionId: null,
          parts: const [PluginPromptPart.text(text: "Start")],
          agent: "build",
          variant: const PluginSessionVariant(id: "xhigh"),
          model: null,
        ),
        throwsA(isA<StateError>()),
      );

      expect(tracker.lastRegisteredSessionId, isNull);
      expect(repository.lastDeletedSessionId, equals("ses-new"));
      expect(repository.lastDeletedDirectory, equals("/repo/subdir"));
    });
  });

  group("OpenCodeService.sendPrompt", () {
    test("resolves session directory from tracker before delegating", () async {
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, tracker);
      const parts = [PluginPromptPart.text(text: "Continue")];

      await service.sendPrompt(
        sessionId: "ses-1",
        parts: parts,
        agent: null,
        variant: null,
        model: null,
      );

      expect(repository.lastPromptSessionId, equals("ses-1"));
      expect(repository.lastPromptDirectory, equals("/repo"));
      expect(repository.lastPromptParts, equals(parts));
      expect(repository.lastPromptVariant, isNull);
    });
  });

  group("OpenCodeService.sendCommand", () {
    test("resolves session directory from tracker before delegating", () async {
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, tracker);

      await service.sendCommand(
        sessionId: "ses-1",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: const PluginSessionVariant(id: "xhigh"),
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(repository.lastCommandSessionId, equals("ses-1"));
      expect(repository.lastCommandDirectory, equals("/repo"));
      expect(repository.lastCommandName, equals("/review-work"));
      expect(repository.lastCommandArguments, equals("recent changes"));
      expect(repository.lastCommandAgent, equals("reviewer"));
      expect(repository.lastCommandVariant, equals("xhigh"));
      expect(repository.lastCommandModel, equals((providerID: "openai", modelID: "gpt-4.1")));
    });

    test("routes the artificial compact command to the summarize endpoint", () async {
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, tracker);

      await service.sendCommand(
        sessionId: "ses-1",
        command: OpenCodeService.compactionCommandName,
        arguments: "",
        agent: null,
        variant: null,
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(repository.summarizeCalls, equals(1));
      expect(repository.lastSummarizeSessionId, equals("ses-1"));
      expect(repository.lastSummarizeDirectory, equals("/repo"));
      expect(repository.lastSummarizeModel, equals((providerID: "openai", modelID: "gpt-4.1")));
      // The real command endpoint must never be hit for compaction.
      expect(repository.lastCommandName, isNull);
    });

    test("throws and skips summarize when compact is invoked without a model", () async {
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final repository = FakeOpenCodeRepository();
      final service = OpenCodeService(repository, tracker);

      await expectLater(
        service.sendCommand(
          sessionId: "ses-1",
          command: OpenCodeService.compactionCommandName,
          arguments: "",
          agent: null,
          variant: null,
          model: null,
        ),
        throwsA(isA<PluginApiException>()),
      );
      expect(repository.summarizeCalls, equals(0));
    });

    group("dispatch fast-fail window", () {
      const fastFailWindow = Duration(milliseconds: 50);

      late FakeOpenCodeRepository repository;
      late OpenCodeService service;

      setUp(() {
        repository = FakeOpenCodeRepository();
        service = OpenCodeService(
          repository,
          FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"}),
          commandDispatchFastFailWindow: fastFailWindow,
        );
      });

      Future<void> sendCommand() {
        return service.sendCommand(
          sessionId: "ses-1",
          command: "/review-work",
          arguments: "",
          agent: null,
          variant: null,
          model: null,
        );
      }

      test("propagates a failure raised within the window", () async {
        final completer = Completer<void>();
        repository.sendCommandCompleter = completer;
        completer.completeError(StateError("unknown command"));

        await expectLater(sendCommand(), throwsA(isA<StateError>()));
      });

      test("propagates a TimeoutException raised by the send chain within the window", () async {
        // Must not be conflated with the fast-fail window elapsing: a timeout
        // thrown by the send chain itself is a genuine dispatch failure.
        final completer = Completer<void>();
        repository.sendCommandCompleter = completer;
        completer.completeError(TimeoutException("inner send timeout"));

        await expectLater(sendCommand(), throwsA(isA<TimeoutException>()));
      });

      test("completes after the window when the command run keeps going", () async {
        // Simulates OpenCode's synchronous /command endpoint: the HTTP
        // response only arrives after the full agent run. The plugin must
        // complete sendCommand once the command is considered accepted.
        final completer = Completer<void>();
        repository.sendCommandCompleter = completer;

        final stopwatch = Stopwatch()..start();
        await sendCommand();
        stopwatch.stop();

        expect(repository.lastCommandName, equals("/review-work"));
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 5)),
          reason: "dispatch must detach instead of awaiting the full run",
        );

        completer.complete();
      });

      test("swallows and logs a failure raised after the window", () async {
        final completer = Completer<void>();
        repository.sendCommandCompleter = completer;

        await sendCommand();

        completer.completeError(StateError("run failed mid-flight"));
        // Flush microtasks — an unhandled async error would fail the test zone.
        await Future<void>.delayed(Duration.zero);
      });
    });
  });

  group("OpenCodeService.handleSseEvent", () {
    late ActiveSessionTracker tracker;
    late OpenCodeService service;

    setUp(() async {
      final repository = FakeOpenCodeRepository(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );
      tracker = ActiveSessionTracker(repository);
      await tracker.coldStart();
      service = OpenCodeService(repository, tracker);
    });

    test("status change with count delta returns changed=true", () {
      service.handleSseEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "s1", projectID: "p1", directory: "/repo"),
        ),
        null,
      );

      final changed = service.handleSseEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.busy(),
        ),
        null,
      );

      expect(changed, isTrue);
    });

    test("status change without count delta returns changed=false", () {
      service.handleSseEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "s1", projectID: "p1", directory: "/repo"),
        ),
        null,
      );
      service.handleSseEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.busy(),
        ),
        null,
      );

      final changed = service.handleSseEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.busy(),
        ),
        null,
      );

      expect(changed, isFalse);
    });

    test("unknown event type returns changed=false", () {
      final changed = service.handleSseEvent(
        const SseEventData.serverHeartbeat(),
        null,
      );
      expect(changed, isFalse);
    });

    test("session created updated and deleted events are handled", () {
      final created = service.handleSseEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "s1", projectID: "p1", directory: "/repo"),
        ),
        null,
      );
      expect(created, isFalse);

      final updated = service.handleSseEvent(
        const SseEventData.sessionUpdated(
          info: Session(id: "s1", projectID: "p1", directory: "/repo/sub"),
        ),
        null,
      );
      expect(updated, isFalse);

      service.handleSseEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.busy(),
        ),
        null,
      );
      final deleted = service.handleSseEvent(
        const SseEventData.sessionDeleted(
          info: Session(id: "s1", projectID: "p1", directory: "/repo/sub"),
        ),
        null,
      );

      expect(deleted, isTrue);
    });
  });

  group("OpenCodeService tracker delegation", () {
    test("coldStart delegates to tracker", () async {
      final tracker = FakeActiveSessionTracker();
      final service = OpenCodeService(FakeOpenCodeRepository(), tracker);

      await service.coldStart();

      expect(tracker.coldStartCalls, equals(1));
    });

    test("reset delegates to tracker", () {
      final tracker = FakeActiveSessionTracker();
      final service = OpenCodeService(FakeOpenCodeRepository(), tracker);

      service.reset();

      expect(tracker.resetCalls, equals(1));
    });

    test("buildSummary delegates to tracker", () {
      final tracker = FakeActiveSessionTracker(
        summary: const [
          ProjectActivitySummary(
            id: "/repo",
            activeSessions: [
              ActiveSession(id: "s1"),
              ActiveSession(id: "s2"),
              ActiveSession(id: "s3"),
            ],
          ),
        ],
      );
      final service = OpenCodeService(FakeOpenCodeRepository(), tracker);

      final result = service.buildSummary();

      expect(tracker.buildSummaryCalls, equals(1));
      expect(result, equals(tracker.summary));
    });
  });

  group("OpenCodeService pending input actions", () {
    test("replyToQuestion 200 clears tracker and returns change", () async {
      final repository = FakeOpenCodeRepository();
      final tracker = FakeActiveSessionTracker(
        sessionDirectories: const {"ses-1": "/repo"},
        clearPendingQuestionChanged: true,
      );
      final service = OpenCodeService(repository, tracker);

      final result = await service.replyToQuestion(
        questionId: "q1",
        sessionId: "ses-1",
        answers: const [
          ["yes"],
        ],
      );

      expect(result.summaryChanged, isTrue);
      expect(repository.lastReplyQuestionId, equals("q1"));
      expect(repository.lastReplyQuestionDirectory, equals("/repo"));
      expect(
        repository.lastReplyQuestionBody?.toJson(),
        equals({
          "answers": const [
            ["yes"],
          ],
        }),
      );
      expect(tracker.lastClearedQuestionId, equals("q1"));
      expect(tracker.lastClearedQuestionSessionId, equals("ses-1"));
    });

    test("regression: question reply without SSE echo clears awaitingInput", () async {
      final repository = FakeOpenCodeRepository(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );
      final tracker = ActiveSessionTracker(repository);
      await tracker.coldStart();
      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "ses-1", projectID: "p1", directory: "/repo"),
        ),
        null,
      );
      tracker.handleEvent(const SseEventData.sessionStatus(sessionID: "ses-1", status: SessionStatus.busy()), null);
      tracker.handleEvent(_questionAsked("q1", "ses-1"), null);
      final service = OpenCodeService(repository, tracker);

      expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

      final result = await service.replyToQuestion(
        questionId: "q1",
        sessionId: "ses-1",
        answers: const [
          ["yes"],
        ],
      );

      expect(result.summaryChanged, isTrue);
      expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isFalse);
    });

    test("replyToQuestion 404 clears tracker and returns change", () async {
      final repository = FakeOpenCodeRepository(
        replyToQuestionError: OpenCodeApiException("POST /question/q1/reply", 404),
      );
      final tracker = FakeActiveSessionTracker(
        sessionDirectories: const {"ses-1": "/repo"},
        clearPendingQuestionChanged: true,
      );
      final service = OpenCodeService(repository, tracker);

      final result = await service.replyToQuestion(questionId: "q1", sessionId: "ses-1", answers: const []);

      expect(result.summaryChanged, isTrue);
      expect(tracker.lastClearedQuestionId, equals("q1"));
    });

    test("replyToQuestion non-404 does not clear and rethrows", () async {
      final error = OpenCodeApiException("POST /question/q1/reply", 500);
      final repository = FakeOpenCodeRepository(replyToQuestionError: error);
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final service = OpenCodeService(repository, tracker);

      await expectLater(
        service.replyToQuestion(questionId: "q1", sessionId: "ses-1", answers: const []),
        throwsA(same(error)),
      );
      expect(tracker.lastClearedQuestionId, isNull);
    });

    test("replyToQuestion timeout does not clear and rethrows", () async {
      final error = TimeoutException("timed out");
      final repository = FakeOpenCodeRepository(replyToQuestionError: error);
      final tracker = FakeActiveSessionTracker(sessionDirectories: const {"ses-1": "/repo"});
      final service = OpenCodeService(repository, tracker);

      await expectLater(
        service.replyToQuestion(questionId: "q1", sessionId: "ses-1", answers: const []),
        throwsA(same(error)),
      );
      expect(tracker.lastClearedQuestionId, isNull);
    });

    test("rejectQuestion 404 clears tracker using optional sessionId", () async {
      final repository = FakeOpenCodeRepository(
        rejectQuestionError: OpenCodeApiException("POST /question/q1/reject", 404),
      );
      final tracker = FakeActiveSessionTracker(clearPendingQuestionChanged: true);
      final service = OpenCodeService(repository, tracker);

      final result = await service.rejectQuestion(questionId: "q1", sessionId: null);

      expect(result.summaryChanged, isTrue);
      expect(tracker.lastClearedQuestionId, equals("q1"));
      expect(tracker.lastClearedQuestionSessionId, isNull);
    });

    test("replyToPermission 200 clears tracker and returns change", () async {
      final repository = FakeOpenCodeRepository();
      final tracker = FakeActiveSessionTracker(clearPendingPermissionChanged: true);
      final service = OpenCodeService(repository, tracker);

      final result = await service.replyToPermission(
        requestId: "perm-1",
        sessionId: "ses-1",
        reply: PluginPermissionReply.once,
      );

      expect(result.summaryChanged, isTrue);
      expect(repository.lastReplyPermissionRequestId, equals("perm-1"));
      expect(tracker.lastClearedPermissionRequestId, equals("perm-1"));
      expect(tracker.lastClearedPermissionSessionId, equals("ses-1"));
    });

    test("replyToPermission 400 does not clear and rethrows", () async {
      final error = OpenCodeApiException("POST /permission/perm-1/reply", 400);
      final repository = FakeOpenCodeRepository(replyToPermissionError: error);
      final tracker = FakeActiveSessionTracker();
      final service = OpenCodeService(repository, tracker);

      await expectLater(
        service.replyToPermission(requestId: "perm-1", sessionId: "ses-1", reply: PluginPermissionReply.once),
        throwsA(same(error)),
      );
      expect(tracker.lastClearedPermissionRequestId, isNull);
    });
  });
}

plugin.MessageWithParts _msg(String role, String id) {
  return plugin.MessageWithParts(
    info: plugin_msg.Message(
      role: role,
      id: id,
      sessionID: "ses-1",
      parentID: null,
      agent: null,
      modelID: null,
      providerID: null,
      cost: null,
      tokens: null,
      time: null,
      finish: null,
      error: null,
    ),
    parts: const [],
  );
}

String? _messageId(plugin.MessageWithParts message) {
  return message.info.id;
}

PendingQuestion _question({required String id, required String sessionId}) {
  return PendingQuestion(id: id, sessionID: sessionId, questions: const []);
}

SseEventData _questionAsked(String id, String sessionId) {
  return SseEventData.questionAsked(
    id: id,
    sessionID: sessionId,
    questions: const [],
  );
}

class FakeOpenCodeApi implements OpenCodeApi {
  List<plugin.MessageWithParts> messages;
  Object? messagesError;
  String? lastRequestedSessionId;
  String? lastRequestedDirectory;

  FakeOpenCodeApi({this.messages = const [], this.messagesError});

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<plugin.MessageWithParts>> getMessages({required String sessionId, required String? directory}) async {
    lastRequestedSessionId = sessionId;
    lastRequestedDirectory = directory;
    if (messagesError != null) throw messagesError!;
    return messages;
  }

  @override
  Future<List<Command>> listCommands({required String? directory}) async => const [];

  @override
  Future<Session> createSession({required String directory, String? parentSessionId}) async =>
      throw UnimplementedError();

  @override
  Future<Session> getSession({required String sessionId, required String? directory}) async =>
      throw UnimplementedError();

  @override
  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async => throw UnimplementedError();

  @override
  Future<List<Session>> getChildren({
    required String sessionId,
    required String? directory,
  }) async => [];

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async => {};

  @override
  Future<void> deleteSession({required String sessionId, required String? directory}) async {}

  @override
  Future<void> removeWorktree({
    required String directory,
    required String worktreePath,
  }) async {}

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    required String? directory,
  }) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {}

  @override
  Future<void> summarize({
    required String sessionId,
    required SummarizeBody body,
    required String? directory,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<AgentInfo>> listAgents({required String directory}) async => [];

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String? directory}) async => [];

  @override
  Future<List<PendingPermission>> getPendingPermissions({required String? directory}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId}) async {}

  @override
  Future<Project> getProject({required String directory}) async => throw UnimplementedError();

  @override
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async => throw UnimplementedError();

  @override
  Future<List<GlobalSession>> listAllSessions({
    required String? directory,
    required bool roots,
  }) async => [];

  @override
  Future<List<Project>> listProjects() async => [];

  @override
  Future<List<Session>> listRootSessions() async => [];

  @override
  Future<List<Session>> listSessions({String? directory, required bool roots}) async => [];

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(providers: [], defaults: {}, connected: []);

  @override
  Future<ProviderListResponse> listConfigProviders({required String? directory}) async =>
      const ProviderListResponse(providers: [], defaults: {}, connected: []);

  @override
  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async => throw UnimplementedError();
}

class FakeOpenCodeRepository extends OpenCodeRepository {
  @override
  final FakeOpenCodeApi api;

  final List<Project> _projects;
  final List<Session> _sessions;
  final List<PluginCommand> _commands;
  final PluginSession? _createdSession;
  final Map<String, List<PendingQuestion>> _pendingQuestionsByDirectory;
  final Map<String, List<PendingPermission>> _pendingPermissionsByDirectory;
  int getProjectsCalls = 0;
  int getSessionsCalls = 0;
  String? lastWorktree;
  String? lastCommandsProjectId;
  String? lastAgentsDirectory;
  String? lastCreateDirectory;
  String? lastCreateParentSessionId;
  String? lastPromptSessionId;
  String? lastPromptDirectory;
  List<PluginPromptPart>? lastPromptParts;
  String? lastPromptAgent;
  String? lastPromptVariant;
  ({String providerID, String modelID})? lastPromptModel;
  Object? sendPromptError;
  String? lastCommandSessionId;
  String? lastCommandDirectory;
  String? lastCommandName;
  String? lastCommandArguments;
  String? lastCommandAgent;
  String? lastCommandVariant;
  ({String providerID, String modelID})? lastCommandModel;
  Completer<void>? sendCommandCompleter;
  int summarizeCalls = 0;
  String? lastSummarizeSessionId;
  String? lastSummarizeDirectory;
  ({String providerID, String modelID})? lastSummarizeModel;
  String? lastDeletedSessionId;
  String? lastDeletedDirectory;
  String? lastReplyQuestionId;
  String? lastReplyQuestionDirectory;
  QuestionReplyBody? lastReplyQuestionBody;
  Object? replyToQuestionError;
  String? lastRejectQuestionId;
  Object? rejectQuestionError;
  String? lastReplyPermissionRequestId;
  String? lastReplyPermissionSessionId;
  PluginPermissionReply? lastReplyPermissionReply;
  Object? replyToPermissionError;
  int getSessionCalls = 0;
  String? lastGetSessionId;
  String? lastGetSessionDirectory;
  final List<String?> pendingQuestionDirectories = [];
  final List<String?> pendingPermissionDirectories = [];

  FakeOpenCodeRepository({
    List<Project> projects = const [],
    List<Session> sessions = const [],
    List<PluginCommand> commands = const [],
    PluginSession? createdSession,
    List<plugin.MessageWithParts> messages = const [],
    Object? messagesError,
    this.replyToQuestionError,
    this.rejectQuestionError,
    this.replyToPermissionError,
    Map<String, List<PendingQuestion>> pendingQuestionsByDirectory = const {},
    Map<String, List<PendingPermission>> pendingPermissionsByDirectory = const {},
  }) : _projects = projects,
       _sessions = sessions,
       _commands = commands,
       _createdSession = createdSession,
       _pendingQuestionsByDirectory = pendingQuestionsByDirectory,
       _pendingPermissionsByDirectory = pendingPermissionsByDirectory,
       api = FakeOpenCodeApi(messages: messages, messagesError: messagesError),
       super(FakeOpenCodeApi(messages: messages, messagesError: messagesError));

  @override
  Future<List<Project>> getProjects() async {
    getProjectsCalls += 1;
    return _projects;
  }

  @override
  Future<List<Session>> getSessions({required String worktree}) async {
    getSessionsCalls += 1;
    lastWorktree = worktree;
    return _sessions;
  }

  @override
  Future<List<PluginAgent>> getAgents({required String directory}) async {
    lastAgentsDirectory = directory;
    return const [];
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    lastCommandsProjectId = projectId;
    return _commands;
  }

  @override
  Future<PluginSession> createSession({required String directory, required String? parentSessionId}) async {
    lastCreateDirectory = directory;
    lastCreateParentSessionId = parentSessionId;
    return _createdSession ??
        const PluginSession(
          id: "created",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        );
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String? directory,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendPromptError case final error?) {
      throw error;
    }
    lastPromptSessionId = sessionId;
    lastPromptDirectory = directory;
    lastPromptParts = parts;
    lastPromptAgent = agent;
    lastPromptVariant = variant?.id;
    lastPromptModel = model;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String? directory,
    required String command,
    required String arguments,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) async {
    lastCommandSessionId = sessionId;
    lastCommandDirectory = directory;
    lastCommandName = command;
    lastCommandArguments = arguments;
    lastCommandAgent = agent;
    lastCommandVariant = variant?.id;
    lastCommandModel = model;
    if (sendCommandCompleter case final completer?) {
      await completer.future;
    }
  }

  @override
  Future<void> summarize({
    required String sessionId,
    required String? directory,
    required ({String providerID, String modelID}) model,
  }) async {
    summarizeCalls += 1;
    lastSummarizeSessionId = sessionId;
    lastSummarizeDirectory = directory;
    lastSummarizeModel = model;
  }

  @override
  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) async {
    lastDeletedSessionId = sessionId;
    lastDeletedDirectory = directory;
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) async {
    if (replyToQuestionError case final error?) {
      throw error;
    }
    lastReplyQuestionId = questionId;
    lastReplyQuestionDirectory = directory;
    lastReplyQuestionBody = body;
  }

  @override
  Future<void> rejectQuestion({required String questionId}) async {
    if (rejectQuestionError case final error?) {
      throw error;
    }
    lastRejectQuestionId = questionId;
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    if (replyToPermissionError case final error?) {
      throw error;
    }
    lastReplyPermissionRequestId = requestId;
    lastReplyPermissionSessionId = sessionId;
    lastReplyPermissionReply = reply;
  }

  @override
  Future<Session> getSession({
    required String sessionId,
    required String? directory,
  }) async {
    getSessionCalls += 1;
    lastGetSessionId = sessionId;
    lastGetSessionDirectory = directory;
    return _sessions.firstWhere((session) => session.id == sessionId);
  }

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String? directory}) async {
    pendingQuestionDirectories.add(directory);
    return _pendingQuestionsByDirectory[directory] ?? const [];
  }

  @override
  Future<List<PendingPermission>> getPendingPermissions({required String? directory}) async {
    pendingPermissionDirectories.add(directory);
    return _pendingPermissionsByDirectory[directory] ?? const [];
  }
}

class FakeActiveSessionTracker extends ActiveSessionTracker {
  int coldStartCalls = 0;
  int resetCalls = 0;
  int buildSummaryCalls = 0;
  List<ProjectActivitySummary> summary;
  final Map<String, String> _sessionDirectories;
  final String? resolvedWorktree;
  String? lastRegisteredSessionId;
  String? lastRegisteredDirectory;
  List<PendingQuestion> populatedQuestions = const [];
  List<PendingPermission> populatedPermissions = const [];
  final bool clearPendingQuestionFound;
  final bool clearPendingQuestionChanged;
  final bool clearPendingPermissionFound;
  final bool clearPendingPermissionChanged;
  String? lastClearedQuestionId;
  String? lastClearedQuestionSessionId;
  String? lastClearedPermissionRequestId;
  String? lastClearedPermissionSessionId;

  FakeActiveSessionTracker({
    this.summary = const [],
    Map<String, String> sessionDirectories = const {},
    this.resolvedWorktree,
    this.clearPendingQuestionFound = false,
    this.clearPendingQuestionChanged = false,
    this.clearPendingPermissionFound = false,
    this.clearPendingPermissionChanged = false,
  }) : _sessionDirectories = Map<String, String>.from(sessionDirectories),
       super(OpenCodeRepository(FakeOpenCodeApi()));

  @override
  Future<void> coldStart() async {
    coldStartCalls += 1;
  }

  @override
  void reset() {
    resetCalls += 1;
  }

  @override
  void registerSession({required String sessionId, required String directory}) {
    lastRegisteredSessionId = sessionId;
    lastRegisteredDirectory = directory;
    _sessionDirectories[sessionId] = directory;
  }

  @override
  String? getSessionDirectory({required String sessionId}) {
    return _sessionDirectories[sessionId];
  }

  @override
  String? resolveProjectWorktree({required String directory}) {
    return resolvedWorktree;
  }

  @override
  void populatePendingQuestions({required List<PendingQuestion> questions}) {
    populatedQuestions = questions;
  }

  @override
  void populatePendingPermissions({required List<PendingPermission> permissions}) {
    populatedPermissions = permissions;
  }

  @override
  ({bool found, bool summaryChanged}) clearPendingQuestion({required String questionId, String? sessionId}) {
    lastClearedQuestionId = questionId;
    lastClearedQuestionSessionId = sessionId;
    return (found: clearPendingQuestionFound, summaryChanged: clearPendingQuestionChanged);
  }

  @override
  ({bool found, bool summaryChanged}) clearPendingPermission({required String sessionId, required String requestId}) {
    lastClearedPermissionSessionId = sessionId;
    lastClearedPermissionRequestId = requestId;
    return (found: clearPendingPermissionFound, summaryChanged: clearPendingPermissionChanged);
  }

  @override
  List<ProjectActivitySummary> buildSummary() {
    buildSummaryCalls += 1;
    return summary;
  }
}
