import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("ActiveSessionTracker", () {
    test("empty tracker has empty activeSessions", () {
      final tracker = ActiveSessionTracker(_fakeRepository());
      expect(tracker.activeSessions, isEmpty);
    });

    test("empty tracker buildSummary returns empty list", () {
      final tracker = ActiveSessionTracker(_fakeRepository());
      expect(tracker.buildSummary(), isEmpty);
    });

    test("session directory exactly matches worktree", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/projects/foo": 1}));
    });

    test("session directory as subdirectory resolves to project", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo/lib/src"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/projects/foo": 1}));
    });

    test("session directory with no matching worktree is ignored", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/tmp/other"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), "/tmp/other");

      expect(changed, isFalse);
      expect(tracker.activeSessions, isEmpty);
    });

    test("empty directory is handled gracefully", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", ""), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), "");

      expect(changed, isFalse);
      expect(tracker.activeSessions, isEmpty);
    });

    test("longest matching worktree is selected", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/projects/foo"),
          const Project(id: "p2", worktree: "/projects/foo/packages/bar"),
        ],
      );

      tracker.handleEvent(
        _sessionCreated("s1", "/projects/foo/packages/bar/src"),
        null,
      );
      tracker.handleEvent(_sessionBusy("s1"), null);

      tracker.handleEvent(_sessionCreated("s2", "/projects/foo/lib"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      expect(
        tracker.activeSessions,
        equals({"/projects/foo/packages/bar": 1, "/projects/foo": 1}),
      );
    });

    test("windows-style path prefixes resolve to project", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: r"C:\repo\foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", r"C:\repo\foo\subdir"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({r"C:\repo\foo": 1}));
    });

    test("busy increments and idle decrements active count", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);

      final busyChanged = tracker.handleEvent(_sessionBusy("s1"), null);
      expect(busyChanged, isTrue);
      expect(tracker.activeSessions, equals({"/repo": 1}));

      final idleChanged = tracker.handleEvent(_sessionIdle("s1"), null);
      expect(idleChanged, isTrue);
      expect(tracker.activeSessions, isEmpty);
    });

    test("retry session status counts as active", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      final changed = tracker.handleEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.retry(
            attempt: 2,
            message: "retrying",
            next: 123,
          ),
        ),
        null,
      );

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/repo": 1}));
    });

    test("multiple busy sessions in same project are all counted", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionCreated("s2", "/repo/lib"), null);

      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      expect(tracker.activeSessions, equals({"/repo": 2}));
    });

    test(
      "deleted session is removed from maps and active count updates",
      () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        expect(tracker.activeSessions, equals({"/repo": 1}));

        final changed = tracker.handleEvent(
          _sessionDeleted("s1", "/repo"),
          null,
        );
        expect(changed, isTrue);
        expect(tracker.activeSessions, isEmpty);

        final afterDeleteStatus = tracker.handleEvent(_sessionBusy("s1"), null);
        expect(afterDeleteStatus, isFalse);
        expect(tracker.activeSessions, isEmpty);
      },
    );

    test(
      "unknown directory on status event does not crash and returns false",
      () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        final changed = tracker.handleEvent(_sessionBusy("s1"), "/tmp/unknown");

        expect(changed, isFalse);
        expect(tracker.activeSessions, isEmpty);
      },
    );

    test("reset clears all state", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      expect(tracker.activeSessions, equals({"/repo": 1}));

      tracker.reset();

      expect(tracker.activeSessions, isEmpty);
      expect(tracker.buildSummary(), isEmpty);
    });

    test("buildSummary includes only projects with active sessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/repo-a"),
          const Project(id: "p2", worktree: "/repo-b"),
        ],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo-a"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);

      final summary = tracker.buildSummary();
      final pairs = summary.map((item) => (item.id, item.activeSessionIds.length)).toSet();

      expect(pairs, equals({("/repo-a", 1)}));
    });

    test("handleEvent change detection and idempotency", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);

      final changedOnBusy = tracker.handleEvent(_sessionBusy("s1"), null);
      expect(changedOnBusy, isTrue);

      final unchangedOnNonSession = tracker.handleEvent(
        const SseEventData.serverHeartbeat(),
        null,
      );
      expect(unchangedOnNonSession, isFalse);

      final unchangedOnDuplicate = tracker.handleEvent(
        _sessionBusy("s1"),
        null,
      );
      expect(unchangedOnDuplicate, isFalse);
    });

    test("coldStart populates state from API", () async {
      final tracker = ActiveSessionTracker(
        _fakeRepository(
          projects: [
            const Project(id: "p1", worktree: "/foo"),
            const Project(id: "p2", worktree: "/bar"),
          ],
          statuses: {"s1": const SessionStatus.busy(), "s2": const SessionStatus.idle()},
        ),
      );

      await tracker.coldStart();

      expect(tracker.activeSessions, isEmpty);
    });

    test("buildSummary includes activeSessionIds for busy sessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessionIds, unorderedEquals(["s1", "s2"]));
      expect(summary.first.activeSessionIds.length, equals(2));
    });

    test("buildSummary excludes idle sessions from activeSessionIds", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);
      tracker.handleEvent(_sessionIdle("s1"), null);

      final summary = tracker.buildSummary();

      expect(summary.first.activeSessionIds, equals(["s2"]));
      expect(summary.first.activeSessionIds.length, equals(1));
    });

    test("buildSummary groups session IDs by worktree correctly", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/projects/foo"),
          const Project(id: "p2", worktree: "/projects/bar"),
        ],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/bar"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(2));

      final fooEntry = summary.firstWhere((e) => e.id == "/projects/foo");
      final barEntry = summary.firstWhere((e) => e.id == "/projects/bar");

      expect(fooEntry.activeSessionIds, equals(["s1"]));
      expect(barEntry.activeSessionIds, equals(["s2"]));
    });
  });
}

SseEventData _sessionCreated(String id, String directory) {
  return SseEventData.sessionCreated(
    info: Session(id: id, projectID: "project", directory: directory),
  );
}

SseEventData _sessionDeleted(String id, String directory) {
  return SseEventData.sessionDeleted(
    info: Session(id: id, projectID: "project", directory: directory),
  );
}

SseEventData _sessionBusy(String id) {
  return SseEventData.sessionStatus(
    sessionID: id,
    status: const SessionStatus.busy(),
  );
}

SseEventData _sessionIdle(String id) {
  return SseEventData.sessionStatus(
    sessionID: id,
    status: const SessionStatus.idle(),
  );
}

OpenCodeRepository _fakeRepository({
  List<Project>? projects,
  List<Session>? sessions,
  Map<String, SessionStatus>? statuses,
}) {
  return OpenCodeRepository(
    _FakeApi(projects: projects, sessions: sessions, statuses: statuses),
  );
}

Future<ActiveSessionTracker> _coldStartedTracker({
  required List<Project> projects,
  List<Session> sessions = const [],
  Map<String, SessionStatus> statuses = const {},
}) async {
  final tracker = ActiveSessionTracker(
    _fakeRepository(projects: projects, sessions: sessions, statuses: statuses),
  );
  await tracker.coldStart();
  return tracker;
}

class _FakeApi implements OpenCodeApi {
  final List<Project> _projects;
  final List<Session> _sessions;
  final Map<String, SessionStatus> _statuses;

  _FakeApi({
    List<Project>? projects,
    List<Session>? sessions,
    Map<String, SessionStatus>? statuses,
  }) : _projects = projects ?? [],
       _sessions = sessions ?? [],
       _statuses = statuses ?? {};

  @override
  String get serverURL => "http://fake";

  @override
  Future<List<Project>> listProjects() async => _projects;

  @override
  Future<List<Session>> listRootSessions() async => _sessions;

  @override
  Future<List<Session>> listSessions({String? directory}) async => _sessions;

  @override
  Future<Session> createSession(String directory, {required String sessionId}) async => throw UnimplementedError();

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
  }) async => [];

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
  Future<Map<String, SessionStatus>> getSessionStatuses() async => _statuses;

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaults: {}, connected: []);
}
