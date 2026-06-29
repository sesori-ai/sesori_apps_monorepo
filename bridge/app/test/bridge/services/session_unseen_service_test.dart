import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_unseen_service.dart";
import "package:sesori_bridge/src/bridge/services/session_view_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionUnseenService", () {
    late AppDatabase db;
    late SessionViewTracker viewTracker;
    late SessionUnseenService service;
    var clock = 1000;

    Future<bool> unseen(String sessionId) async {
      final repo = SessionUnseenRepository(
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        db: db,
        calculator: const SessionUnseenCalculator(),
      );
      return repo.isUnseen(sessionId: sessionId);
    }

    setUp(() {
      db = createTestDatabase();
      clock = 1000;
      viewTracker = SessionViewTracker();
      service = SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          db: db,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          plugin: _FakePlugin(),
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        sessionRepository: SessionRepository(
          plugin: _FakePlugin(),
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        viewTracker: viewTracker,
        now: () => clock,
      );
    });

    tearDown(() async {
      await service.dispose();
      await viewTracker.dispose();
      await db.close();
    });

    test("new root session is unseen; child session is ignored", () async {
      await service.recordSessionCreated(sessionId: "root", projectId: "p1", parentId: null);
      await service.recordSessionCreated(sessionId: "child", projectId: "p1", parentId: "root");

      expect(await unseen("root"), isTrue);
      expect(await unseen("child"), isFalse); // never persisted
    });

    test("activity on an unviewed pre-existing session bolds it", () async {
      // Pre-existing (baseline-seen) row.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      expect(await unseen("s1"), isFalse);

      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);
    });

    test("activity while viewing does not bold (seen advances)", () async {
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      viewTracker.setViewing(connID: 1, sessionId: "s1");
      // view-start marks it seen.
      await Future<void>.delayed(Duration.zero);
      expect(await unseen("s1"), isFalse);

      clock = 3000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isFalse);
    });

    test("mark unread then mark read toggles bold", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Some AI activity exists, but it's currently seen.
      clock = 600;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      clock = 700;
      await service.markRead(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isFalse);

      clock = 750;
      await service.markUnread(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isTrue);

      clock = 800;
      await service.markRead(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isFalse);
    });

    test("mark unread forces bold even when the user's own message is latest", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Latest activity is the user's own message -> normally NOT bold.
      clock = 600;
      await service.recordActivity(sessionId: "s1", isUserMessage: true);
      expect(await unseen("s1"), isFalse);

      clock = 700;
      await service.markUnread(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isTrue);
    });

    test("monotonic clock keeps same-ms user+assistant activity ordered (stays unseen)", () async {
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      // Both events fall in the same wall-clock millisecond. A user message then
      // an assistant message must still leave activity strictly above the
      // user-message timestamp, so the session stays unseen.
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true);
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);
    });

    test("serializes ordered activity for one session (no out-of-order clear)", () async {
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      clock = 2000;
      // Fire a user message then an AI message without awaiting between them;
      // the AI activity (later) must win so the session stays unseen.
      final f1 = service.recordActivity(sessionId: "s1", isUserMessage: true);
      final f2 = service.recordActivity(sessionId: "s1", isUserMessage: false);
      await Future.wait([f1, f2]);
      expect(await unseen("s1"), isTrue);
    });

    test("activity timestamp is clamped above persisted markers (clock rollback)", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Persist markers far in the future (e.g. stored before a clock rollback).
      await db.sessionDao.setActivityTimestamps(
        sessionId: "s1",
        activityAt: 10000,
        userMessageAt: 10000,
        seenAt: 10000,
      );
      expect(await unseen("s1"), isFalse);

      // New assistant activity arrives with a wall clock BELOW the stored
      // markers; it must still bold the session.
      clock = 1000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);
    });

    test("recordSessionDeleted removes the row so it stops contributing to the project", () async {
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      expect(await unseen("s1"), isTrue);

      await service.recordSessionDeleted(sessionId: "s1");
      // Row is gone -> session is no longer unseen and can't keep the project bold.
      final repo = ProjectRepository(
        plugin: _FakePlugin(),
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      expect(await repo.projectHasUnseenChanges(projectId: "p1"), isFalse);
    });

    test("recordSessionCreated stamps a bare placeholder row so it bolds", () async {
      // A /sessions refresh inserted a placeholder (no unseen markers) before
      // the live session.created event is processed.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      expect(await unseen("s1"), isFalse);

      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      expect(await unseen("s1"), isTrue);
    });

    test("coalesces streaming assistant deltas once the session is already unseen", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      // First assistant activity bolds the session and emits.
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      await Future<void>.delayed(Duration.zero);
      expect(await unseen("s1"), isTrue);
      final afterFirst = events.length;
      expect(afterFirst, greaterThanOrEqualTo(1));

      // Subsequent streaming deltas (assistant, not viewed) are coalesced: no
      // additional DB write or emit while it's already unseen.
      clock = 2001;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      clock = 2002;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      await Future<void>.delayed(Duration.zero);
      expect(events.length, equals(afterFirst));

      // A later mark-read still clears it (correctness preserved despite the
      // skipped activity bumps).
      clock = 3000;
      await service.markRead(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isFalse);

      await sub.cancel();
    });

    test("a user message after the session is unseen is NOT coalesced (updates user-message marker)", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);

      // The user then sends their own message: this must still be recorded (it
      // advances last_user_message_at), and clears the bold.
      clock = 2500;
      await service.recordActivity(sessionId: "s1", isUserMessage: true);
      expect(await unseen("s1"), isFalse);
    });

    test("mark on an unknown session emits an authoritative clear for its project", () async {
      // A project with one genuinely-unseen session, plus a stale "ghost" the
      // client still shows after a missed delete.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      // Mark the gone ghost read: no row, but with projectId the bridge emits an
      // authoritative clear (ghost unseen:false) with the recomputed aggregate.
      await service.markRead(sessionId: "ghost", projectId: "p1");
      await Future<void>.delayed(Duration.zero);

      final last = events.last;
      expect(last.sessionId, "ghost");
      expect(last.projectId, "p1");
      expect(last.unseen, isFalse);
      // s1 is still genuinely unseen, so the project aggregate stays true.
      expect(last.projectHasUnseenChanges, isTrue);
      await sub.cancel();
    });

    test("markUnread on an unknown session emits a clear AND throws so the client rolls back", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await expectLater(
        () => service.markUnread(sessionId: "ghost", projectId: "p1"),
        throwsA(isA<SessionUnseenRowMissingException>()),
      );
      await Future<void>.delayed(Duration.zero);

      // It still emitted the authoritative clear for other clients.
      expect(events.where((e) => e.sessionId == "ghost").single.unseen, isFalse);
      await sub.cancel();
    });

    test("markRead on an EXISTING row succeeds even when the aggregate emit throws", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Bold the row so mark-read has a real effect.
      clock = 600;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);

      final failing = SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          db: db,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: _ThrowingProjectRepository(),
        sessionRepository: SessionRepository(
          plugin: _FakePlugin(),
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        viewTracker: SessionViewTracker(),
        now: () => clock,
      );
      addTearDown(failing.dispose);

      // The row write commits, so the user-initiated mark-read SUCCEEDS even
      // though the aggregate emit throws. Failing the request would make the
      // client roll back its optimistic clear while the row is already seen
      // (client bold vs server seen) until the next refresh. The emit failure is
      // swallowed + logged; the committed row reflects the user's action.
      clock = 700;
      await failing.markRead(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isFalse);
    });

    test("markUnread on an EXISTING row succeeds even when the aggregate emit throws", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      expect(await unseen("s1"), isFalse);

      final failing = SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          db: db,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: _ThrowingProjectRepository(),
        sessionRepository: SessionRepository(
          plugin: _FakePlugin(),
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        viewTracker: SessionViewTracker(),
        now: () => clock,
      );
      addTearDown(failing.dispose);

      // The unread write commits, so the request SUCCEEDS even though the
      // aggregate emit throws; the row already reflects the user's action.
      clock = 700;
      await failing.markUnread(sessionId: "s1", projectId: "p1");
      expect(await unseen("s1"), isTrue);
    });

    test("markRead on an unknown session propagates an emit failure to the caller", () async {
      // A service whose project repository throws when recomputing the aggregate.
      final failing = SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          db: db,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: _ThrowingProjectRepository(),
        sessionRepository: SessionRepository(
          plugin: _FakePlugin(),
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        ),
        viewTracker: SessionViewTracker(),
        now: () => clock,
      );
      addTearDown(failing.dispose);

      // The missing-row clear can't be computed (repo throws), so the
      // user-initiated mark-read must surface the failure, not report success.
      await expectLater(
        () => failing.markRead(sessionId: "ghost", projectId: "p1"),
        throwsA(anything),
      );
    });

    test("markUnread on an unknown session without a projectId throws without emitting", () async {
      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);
      await expectLater(
        () => service.markUnread(sessionId: "ghost", projectId: null),
        throwsA(isA<SessionUnseenRowMissingException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test("emits unseenChanges with project aggregate", () async {
      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await service.recordSessionCreated(sessionId: "root", projectId: "p1", parentId: null);
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      final last = events.last;
      expect(last.sessionId, "root");
      expect(last.projectId, "p1");
      expect(last.unseen, isTrue);
      expect(last.projectHasUnseenChanges, isTrue);

      await sub.cancel();
    });
  });
}

class _FakePlugin implements BridgePluginApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingProjectRepository implements ProjectRepository {
  @override
  Future<bool> projectHasUnseenChanges({required String projectId}) async => throw Exception("boom");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
