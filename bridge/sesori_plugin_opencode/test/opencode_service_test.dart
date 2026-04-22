import "package:opencode_plugin/opencode_plugin.dart";
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
    test("delegates to repository and returns plugin commands", () async {
      final repository = FakeOpenCodeRepository(
        commands: const [
          PluginCommand(name: "/review-work", provider: "openai", source: PluginCommandSource.skill),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final commands = await service.getCommands(projectId: "/repo");

      expect(repository.lastCommandsProjectId, equals("/repo"));
      expect(commands, hasLength(1));
      expect(commands.single.name, equals("/review-work"));
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
        effort: PluginEffort.low,
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
      expect(repository.lastPromptEffort, equals(PluginEffort.low));
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
        effort: null,
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
          effort: PluginEffort.max,
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
        effort: PluginEffort.medium,
        model: null,
      );

      expect(repository.lastPromptSessionId, equals("ses-1"));
      expect(repository.lastPromptDirectory, equals("/repo"));
      expect(repository.lastPromptParts, equals(parts));
      expect(repository.lastPromptEffort, equals(PluginEffort.medium));
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
        effort: PluginEffort.max,
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(repository.lastCommandSessionId, equals("ses-1"));
      expect(repository.lastCommandDirectory, equals("/repo"));
      expect(repository.lastCommandName, equals("/review-work"));
      expect(repository.lastCommandArguments, equals("recent changes"));
      expect(repository.lastCommandAgent, equals("reviewer"));
      expect(repository.lastCommandEffort, equals(PluginEffort.max));
      expect(repository.lastCommandModel, equals((providerID: "openai", modelID: "gpt-4.1")));
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
}

MessageWithParts _msg(String role, String id) {
  return MessageWithParts(
    info: Message(role: role, id: id, sessionID: "ses-1"),
    parts: const [],
  );
}

String? _messageId(MessageWithParts message) {
  return message.info.id;
}

class FakeOpenCodeApi implements OpenCodeApi {
  @override
  String get serverURL => "http://fake";

  List<MessageWithParts> messages;
  Object? messagesError;
  String? lastRequestedSessionId;
  String? lastRequestedDirectory;

  FakeOpenCodeApi({this.messages = const [], this.messagesError});

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<MessageWithParts>> getMessages({required String sessionId, required String? directory}) async {
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
  Future<void> deleteSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<Session>> getChildren({required String sessionId, required String? directory}) async => [];

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async =>
      <String, SessionStatus>{};

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
  Future<void> abortSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<AgentInfo>> listAgents() async => [];

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String? directory}) async => [];

  @override
  Future<List<PendingPermission>> getPendingPermissions({required String? directory}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required Map<String, dynamic> body,
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
  Future<List<Session>> listSessions({String? directory}) async => [];

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaults: {}, connected: []);

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
  int getProjectsCalls = 0;
  int getSessionsCalls = 0;
  String? lastWorktree;
  String? lastCommandsProjectId;
  String? lastCreateDirectory;
  String? lastCreateParentSessionId;
  String? lastPromptSessionId;
  String? lastPromptDirectory;
  List<PluginPromptPart>? lastPromptParts;
  String? lastPromptAgent;
  PluginEffort? lastPromptEffort;
  ({String providerID, String modelID})? lastPromptModel;
  Object? sendPromptError;
  String? lastCommandSessionId;
  String? lastCommandDirectory;
  String? lastCommandName;
  String? lastCommandArguments;
  String? lastCommandAgent;
  PluginEffort? lastCommandEffort;
  ({String providerID, String modelID})? lastCommandModel;
  String? lastDeletedSessionId;
  String? lastDeletedDirectory;

  FakeOpenCodeRepository({
    List<Project> projects = const [],
    List<Session> sessions = const [],
    List<PluginCommand> commands = const [],
    PluginSession? createdSession,
    List<MessageWithParts> messages = const [],
    Object? messagesError,
  }) : _projects = projects,
        _sessions = sessions,
        _commands = commands,
        _createdSession = createdSession,
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
    required PluginEffort? effort,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendPromptError case final error?) {
      throw error;
    }
    lastPromptSessionId = sessionId;
    lastPromptDirectory = directory;
    lastPromptParts = parts;
    lastPromptAgent = agent;
    lastPromptEffort = effort;
    lastPromptModel = model;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String? directory,
    required String command,
    required String arguments,
    required String? agent,
    required PluginEffort? effort,
    required ({String providerID, String modelID})? model,
  }) async {
    lastCommandSessionId = sessionId;
    lastCommandDirectory = directory;
    lastCommandName = command;
    lastCommandArguments = arguments;
    lastCommandAgent = agent;
    lastCommandEffort = effort;
    lastCommandModel = model;
  }

  @override
  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) async {
    lastDeletedSessionId = sessionId;
    lastDeletedDirectory = directory;
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

  FakeActiveSessionTracker({
    this.summary = const [],
    Map<String, String> sessionDirectories = const {},
    this.resolvedWorktree,
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
  List<ProjectActivitySummary> buildSummary() {
    buildSummaryCalls += 1;
    return summary;
  }
}
