import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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

  group("OpenCodeRepository.getCommands", () {
    test("maps OpenCode commands to plugin commands in Layer 2", () async {
      final api = _FakeApi(
        commands: const [
          Command(
            name: "/review-work",
            template: "review {{input}}",
            hints: ["recent changes"],
            description: "Review current branch changes",
            agent: "review-work",
            model: "gpt-5.4",
            provider: "openai",
            source: CommandSource.skill,
            subtask: true,
          ),
        ],
      );
      final repository = OpenCodeRepository(api);

      final commands = await repository.getCommands(projectId: "/repo");

      expect(commands, hasLength(1));
      expect(
        commands.single,
        const PluginCommand(
          name: "/review-work",
          template: "review {{input}}",
          hints: ["recent changes"],
          description: "Review current branch changes",
          agent: "review-work",
          model: "gpt-5.4",
          provider: "openai",
          source: PluginCommandSource.skill,
          subtask: true,
        ),
      );
    });
  });

  group("OpenCodeRepository.createSession", () {
    test("trims directory before calling api and mapping projectID", () async {
      final api = _FakeApi(
        createdSession: const Session(
          id: "ses-1",
          projectID: "global",
          directory: "/repo",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      );
      final repository = OpenCodeRepository(api);

      final session = await repository.createSession(
        directory: "  /repo  ",
        parentSessionId: "parent-1",
      );

      expect(api.lastCreateDirectory, equals("/repo"));
      expect(api.lastCreateParentSessionId, equals("parent-1"));
      expect(session.projectID, equals("/repo"));
    });
  });

  group("OpenCodeRepository effort mapping", () {
    test("sendPrompt maps low effort to low variant", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        sessionId: "ses-1",
        directory: " /repo ",
        parts: const [PluginPromptPart.text(text: "Continue")],
        agent: "build",
        effort: PluginEffort.low,
        model: (providerID: "openai", modelID: "gpt-5.4"),
      );

      expect(api.lastPromptSessionId, equals("ses-1"));
      expect(api.lastPromptDirectory, equals("/repo"));
      expect(api.lastPromptBody?.toJson()["variant"], equals("low"));
    });

    test("sendPrompt maps medium and null effort to omitted variant", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendPrompt(
        sessionId: "ses-medium",
        directory: "/repo",
        parts: const [PluginPromptPart.text(text: "Medium")],
        agent: null,
        effort: PluginEffort.medium,
        model: null,
      );
      await repository.sendPrompt(
        sessionId: "ses-null",
        directory: "/repo",
        parts: const [PluginPromptPart.text(text: "Null")],
        agent: null,
        effort: null,
        model: null,
      );

      expect(api.promptBodies, hasLength(2));
      expect(api.promptBodies[0].toJson().containsKey("variant"), isFalse);
      expect(api.promptBodies[1].toJson().containsKey("variant"), isFalse);
    });

    test("sendCommand maps max effort to xhigh variant", () async {
      final api = _FakeApi();
      final repository = OpenCodeRepository(api);

      await repository.sendCommand(
        sessionId: "ses-1",
        directory: "/repo",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        effort: PluginEffort.max,
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(api.lastCommandSessionId, equals("ses-1"));
      expect(api.lastCommandDirectory, equals("/repo"));
      expect(api.lastCommandBody?.toJson()["variant"], equals("xhigh"));
    });
  });

  group("Send*Body toJson", () {
    test("SendPromptBody emits variant only when provided", () {
      final withVariant = const SendPromptBody(
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: "low",
        model: null,
      ).toJson();
      final withoutVariant = const SendPromptBody(
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: "build",
        variant: null,
        model: null,
      ).toJson();

      expect(withVariant["variant"], equals("low"));
      expect(withoutVariant.containsKey("variant"), isFalse);
    });

    test("SendCommandBody emits variant only when provided", () {
      final withVariant = const SendCommandBody(
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: "xhigh",
        model: null,
      ).toJson();
      final withoutVariant = const SendCommandBody(
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        variant: null,
        model: null,
      ).toJson();

      expect(withVariant["variant"], equals("xhigh"));
      expect(withoutVariant.containsKey("variant"), isFalse);
    });
  });
}

class _FakeApi implements OpenCodeApi {
  final List<Session> _sessions;
  final List<GlobalSession> _globalSessions;
  final List<Project> _projects;
  final List<Command> _commands;
  final Session? _createdSession;
  String? lastCreateDirectory;
  String? lastCreateParentSessionId;
  String? lastPromptSessionId;
  String? lastPromptDirectory;
  SendPromptBody? lastPromptBody;
  final List<SendPromptBody> promptBodies = [];
  String? lastCommandSessionId;
  String? lastCommandDirectory;
  SendCommandBody? lastCommandBody;

  _FakeApi({
    List<Session>? sessions,
    List<GlobalSession>? globalSessions,
    List<Project>? projects,
    List<Command>? commands,
    Session? createdSession,
  }) : _sessions = sessions ?? [],
         _globalSessions = globalSessions ?? [],
        _projects = projects ?? [],
        _commands = commands ?? [],
        _createdSession = createdSession;

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
  Future<List<Command>> listCommands({required String? directory}) async => _commands;

  @override
  Future<Session> createSession({required String directory, String? parentSessionId}) async {
    lastCreateDirectory = directory;
    lastCreateParentSessionId = parentSessionId;
    return _createdSession ??
        const Session(
          id: "created",
          projectID: "global",
          directory: "/repo",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        );
  }

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
  }) async {
    lastPromptSessionId = sessionId;
    lastPromptDirectory = directory;
    lastPromptBody = body;
    promptBodies.add(body);
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {
    lastCommandSessionId = sessionId;
    lastCommandDirectory = directory;
    lastCommandBody = body;
  }

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
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async => {};

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
