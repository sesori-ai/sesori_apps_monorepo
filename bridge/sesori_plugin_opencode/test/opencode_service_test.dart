import "package:opencode_plugin/opencode_plugin.dart";
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

  group("OpenCodeService.getLastExchange", () {
    test("returns from last user message onwards", () async {
      final repository = FakeOpenCodeRepository(
        messages: [
          _msg("assistant", "m1"),
          _msg("user", "m2"),
          _msg("assistant", "m3"),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result.map(_messageId).toList(), equals(["m2", "m3"]));
      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
    });

    test("passes directory to api when provided", () async {
      final repository = FakeOpenCodeRepository(messages: [_msg("user", "m1")]);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      await service.getLastExchange(sessionId: "ses-1", directory: "/repo");

      expect(repository.api.lastRequestedSessionId, equals("ses-1"));
      expect(repository.api.lastRequestedDirectory, equals("/repo"));
    });

    test("multiple user messages returns from last user", () async {
      final repository = FakeOpenCodeRepository(
        messages: [
          _msg("user", "m1"),
          _msg("assistant", "m2"),
          _msg("user", "m3"),
          _msg("assistant", "m4"),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result.map(_messageId).toList(), equals(["m3", "m4"]));
    });

    test("no user message returns empty", () async {
      final repository = FakeOpenCodeRepository(
        messages: [_msg("assistant", "m1"), _msg("assistant", "m2")],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result, isEmpty);
    });

    test("empty list returns empty", () async {
      final repository = FakeOpenCodeRepository(messages: const []);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result, isEmpty);
    });

    test("single user message returns one element", () async {
      final repository = FakeOpenCodeRepository(messages: [_msg("user", "m1")]);
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result.map(_messageId).toList(), equals(["m1"]));
    });

    test("non-user roles before last user are excluded from result", () async {
      final repository = FakeOpenCodeRepository(
        messages: [
          _msg("system", "m0"),
          _msg("user", "m1"),
          _msg("assistant", "m2"),
        ],
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result, hasLength(2));
      expect(_messageId(result.first), equals("m1"));
    });

    test("api throw returns empty", () async {
      final repository = FakeOpenCodeRepository(
        messagesError: Exception("boom"),
      );
      final service = OpenCodeService(repository, FakeActiveSessionTracker());

      final result = await service.getLastExchange(sessionId: "ses-1", directory: null);

      expect(result, isEmpty);
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
  Future<List<MessageWithParts>> getMessages({required String sessionId, required String? directory}) async {
    lastRequestedSessionId = sessionId;
    lastRequestedDirectory = directory;
    if (messagesError != null) throw messagesError!;
    return messages;
  }

  @override
  Future<Session> createSession({required String directory, String? parentSessionId}) async =>
      throw UnimplementedError();

  @override
  Future<Session> getSession({required String sessionId, required String? directory}) async =>
      throw UnimplementedError();

  @override
  Future<Session> forkSession({required String sessionId, required String? directory}) async =>
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
  Future<Map<String, SessionStatus>> getSessionStatuses() async => <String, SessionStatus>{};

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<AgentInfo>> listAgents() async => [];

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String? directory}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required Map<String, dynamic> body,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId}) async {}

  @override
  Future<Project> getProject({required String directory}) async => throw UnimplementedError();

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
}

class FakeOpenCodeRepository extends OpenCodeRepository {
  @override
  final FakeOpenCodeApi api;

  final List<Project> _projects;
  final List<Session> _sessions;
  int getProjectsCalls = 0;
  int getSessionsCalls = 0;
  String? lastWorktree;

  FakeOpenCodeRepository({
    List<Project> projects = const [],
    List<Session> sessions = const [],
    List<MessageWithParts> messages = const [],
    Object? messagesError,
  }) : _projects = projects,
       _sessions = sessions,
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
}

class FakeActiveSessionTracker extends ActiveSessionTracker {
  int coldStartCalls = 0;
  int resetCalls = 0;
  int buildSummaryCalls = 0;
  List<ProjectActivitySummary> summary;

  FakeActiveSessionTracker({this.summary = const []}) : super(OpenCodeRepository(FakeOpenCodeApi()));

  @override
  Future<void> coldStart() async {
    coldStartCalls += 1;
  }

  @override
  void reset() {
    resetCalls += 1;
  }

  @override
  List<ProjectActivitySummary> buildSummary() {
    buildSummaryCalls += 1;
    return summary;
  }
}
