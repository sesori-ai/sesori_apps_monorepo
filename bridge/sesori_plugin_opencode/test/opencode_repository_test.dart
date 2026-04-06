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

  group("OpenCodeRepository.getProjects", () {
    test("merges timestamps from real-project sessions into project", () async {
      // A real project whose own timestamp is old (set at OpenCode startup).
      // A session belonging to that project has a much more recent timestamp
      // (updated when user sent a message via Session.touch()).
      final api = _FakeApi(
        projects: [
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000),
          ),
        ],
        globalSessions: [
          const GlobalSession(
            id: "s1",
            projectID: "my-project",
            directory: "/repo",
            time: SessionTime(created: 1500, updated: 9000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.time?.updated, equals(9000));
      // created should be the earliest across project and sessions.
      expect(projects.first.time?.created, equals(1000));
    });

    test("merges timestamps from global sessions into matching real project", () async {
      // Orphaned global sessions under a directory that also has a real project.
      final api = _FakeApi(
        projects: [
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 2000),
          ),
        ],
        globalSessions: [
          const GlobalSession(
            id: "orphan",
            projectID: "global",
            directory: "/repo",
            time: SessionTime(created: 500, updated: 3000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      // updated = max(2000, 3000)
      expect(projects.first.time?.updated, equals(3000));
      // created = min(1000, 500)
      expect(projects.first.time?.created, equals(500));
    });

    test("uses project's own timestamp when no sessions exist", () async {
      final api = _FakeApi(
        projects: [
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 2000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.time?.updated, equals(2000));
      expect(projects.first.time?.created, equals(1000));
    });

    test("merges timestamps from both global and real-project sessions", () async {
      // Project has sessions from both the real project ID and the global
      // project ID (pre-git-init orphans). Both should contribute to the
      // merged timestamp.
      final api = _FakeApi(
        projects: [
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000),
          ),
        ],
        globalSessions: [
          const GlobalSession(
            id: "real-session",
            projectID: "my-project",
            directory: "/repo",
            time: SessionTime(created: 2000, updated: 5000),
          ),
          const GlobalSession(
            id: "orphan-session",
            projectID: "global",
            directory: "/repo",
            time: SessionTime(created: 500, updated: 8000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      // updated = max(1000, 5000, 8000)
      expect(projects.first.time?.updated, equals(8000));
      // created = min(1000, 2000, 500)
      expect(projects.first.time?.created, equals(500));
    });

    test("creates virtual projects only from global sessions", () async {
      // A directory with only global sessions (no real project entry) should
      // produce a virtual project.
      final api = _FakeApi(
        projects: [
          const Project(
            id: "other-project",
            worktree: "/other-repo",
            time: ProjectTime(created: 1000, updated: 1000),
          ),
        ],
        globalSessions: [
          const GlobalSession(
            id: "orphan",
            projectID: "global",
            directory: "/no-git-repo",
            time: SessionTime(created: 500, updated: 3000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      // Should have the real project + a virtual one.
      expect(projects, hasLength(2));
      final virtual = projects.where((p) => p.worktree == "/no-git-repo");
      expect(virtual, hasLength(1));
      expect(virtual.first.time?.updated, equals(3000));
    });

    test("does not create virtual project for real-project sessions without matching project", () async {
      // Sessions belonging to a non-global project ID should not produce
      // virtual projects — they already belong to a real project even if the
      // project entry wasn't returned by the API (edge case).
      final api = _FakeApi(
        projects: [],
        globalSessions: [
          const GlobalSession(
            id: "s1",
            projectID: "some-real-project",
            directory: "/repo",
            time: SessionTime(created: 500, updated: 3000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      // No virtual project should be created for non-global sessions.
      expect(projects, isEmpty);
    });

    test("merges timestamps from sessions in subdirectories of the worktree", () async {
      // A session started from a subdirectory of the project (e.g. the user
      // ran OpenCode from /repo/packages/foo). The project worktree is /repo.
      // The session's timestamp should still contribute to the project's
      // merged "last updated".
      final api = _FakeApi(
        projects: [
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 1000, updated: 1000),
          ),
        ],
        globalSessions: [
          const GlobalSession(
            id: "sub-session",
            projectID: "my-project",
            directory: "/repo/packages/foo",
            time: SessionTime(created: 2000, updated: 9000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      // The subdirectory session's updated (9000) should be picked up.
      expect(projects.first.time?.updated, equals(9000));
      expect(projects.first.time?.created, equals(1000));
    });

    test("excludes global meta-project from results", () async {
      final api = _FakeApi(
        projects: [
          const Project(
            id: "global",
            worktree: "/home/user",
            time: ProjectTime(created: 1000, updated: 1000),
          ),
          const Project(
            id: "my-project",
            worktree: "/repo",
            time: ProjectTime(created: 2000, updated: 2000),
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final projects = await repository.getProjects();

      expect(projects, hasLength(1));
      expect(projects.first.worktree, equals("/repo"));
    });
  });
}

class _FakeApi implements OpenCodeApi {
  final List<Session> _sessions;
  final List<GlobalSession> _globalSessions;
  final List<Project> _projects;

  _FakeApi({
    List<Session>? sessions,
    List<GlobalSession>? globalSessions,
    List<Project>? projects,
  }) : _sessions = sessions ?? [],
       _globalSessions = globalSessions ?? [],
       _projects = projects ?? [];

  @override
  String get serverURL => "http://fake";

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<Project>> listProjects() async => _projects;

  @override
  Future<List<Session>> listRootSessions() async => _sessions;

  @override
  Future<List<Session>> listSessions({String? directory}) async => _sessions;

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
  Future<List<GlobalSession>> listAllSessions({
    required String? directory,
    required bool roots,
  }) async => _globalSessions;

  @override
  Future<List<MessageWithParts>> getMessages({required String sessionId, required String? directory}) async => [];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
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
    required String response,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId}) async {}

  @override
  Future<Project> getProject({required String directory}) async => throw UnimplementedError();

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses() async => {};

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaults: {}, connected: []);

  @override
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async => throw UnimplementedError();

  @override
  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async => throw UnimplementedError();
}
