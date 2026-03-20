import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeRepository.getSessions", () {
    test("excludes child sessions (non-null parentID)", () async {
      final api = _FakeApi(
        sessions: [
          const Session(id: "parent-1", projectID: "p1", directory: "/repo"),
          const Session(
            id: "child-1",
            projectID: "p1",
            directory: "/repo",
            parentID: "parent-1",
          ),
          const Session(id: "parent-2", projectID: "p1", directory: "/repo"),
          const Session(
            id: "child-2",
            projectID: "p1",
            directory: "/repo",
            parentID: "parent-2",
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, containsAll(["parent-1", "parent-2"]));
      expect(ids, isNot(contains("child-1")));
      expect(ids, isNot(contains("child-2")));
    });

    test("includes sessions with null parentID", () async {
      final api = _FakeApi(
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/repo"),
          const Session(id: "s2", projectID: "p1", directory: "/repo"),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["s1", "s2"]));
    });

    test("excludes child sessions from global sessions too", () async {
      final api = _FakeApi(
        globalSessions: [
          const GlobalSession(
            id: "g-parent",
            projectID: "global",
            directory: "/repo",
          ),
          const GlobalSession(
            id: "g-child",
            projectID: "global",
            directory: "/repo",
            parentID: "g-parent",
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, contains("g-parent"));
      expect(ids, isNot(contains("g-child")));
    });

    test("filters by worktree directory", () async {
      final api = _FakeApi(
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/repo"),
          const Session(id: "s2", projectID: "p1", directory: "/other"),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["s1"]));
    });

    test("sorts by updated time descending", () async {
      final api = _FakeApi(
        sessions: [
          const Session(
            id: "old",
            projectID: "p1",
            directory: "/repo",
            time: SessionTime(created: 100, updated: 100),
          ),
          const Session(
            id: "new",
            projectID: "p1",
            directory: "/repo",
            time: SessionTime(created: 200, updated: 200),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      expect(sessions.map((s) => s.id).toList(), equals(["new", "old"]));
    });

    test("deduplicates standard and global sessions", () async {
      final api = _FakeApi(
        sessions: [const Session(id: "dup", projectID: "p1", directory: "/repo")],
        globalSessions: [
          const GlobalSession(id: "dup", projectID: "global", directory: "/repo"),
          const GlobalSession(id: "unique", projectID: "global", directory: "/repo"),
        ],
      );
      final repository = OpenCodeRepository(api);

      final sessions = await repository.getSessions(worktree: "/repo");

      final ids = sessions.map((s) => s.id).toList();
      expect(ids, containsAll(["dup", "unique"]));
      expect(ids.where((id) => id == "dup").length, equals(1));
    });
  });
}

class _FakeApi implements OpenCodeApi {
  final List<Session> _sessions;
  final List<GlobalSession> _globalSessions;

  _FakeApi({List<Session>? sessions, List<GlobalSession>? globalSessions})
    : _sessions = sessions ?? [],
      _globalSessions = globalSessions ?? [];

  @override
  String get serverURL => "http://fake";

  @override
  Future<List<Project>> listProjects() async => [];

  @override
  Future<List<Session>> listRootSessions() async => _sessions;

  @override
  Future<List<Session>> listSessions({String? directory}) async => _sessions;

  @override
  Future<Session> createSession(String directory) async => throw UnimplementedError();

  @override
  Future<Session> updateSession(String sessionId, Map<String, dynamic> body) async => throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<Session>> getChildren(String sessionId) async => [];

  @override
  Future<List<GlobalSession>> listGlobalSessions({
    String? directory,
    bool roots = false,
  }) async => _globalSessions;

  @override
  Future<List<MessageWithParts>> getMessages(String sessionId) async => [];

  @override
  Future<void> sendPrompt(String sessionId, {required Map<String, dynamic> body}) async {}

  @override
  Future<void> abortSession(String sessionId) async {}

  @override
  Future<List<AgentInfo>> listAgents() async => [];

  @override
  Future<List<PendingQuestion>> getPendingQuestions() async => [];

  @override
  Future<void> replyToQuestion(String questionId, {required Map<String, dynamic> body}) async {}

  @override
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<Project> getCurrentProject(String directory) async => throw UnimplementedError();

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses() async => {};

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaults: {}, connected: []);
}
