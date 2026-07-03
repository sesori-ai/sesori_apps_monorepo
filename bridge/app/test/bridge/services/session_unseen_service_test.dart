import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
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

    SessionUnseenRepository unseenRepository() => SessionUnseenRepository(
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      db: db,
      calculator: const SessionUnseenCalculator(),
    );

    ProjectRepository projectRepository() => ProjectRepository(
      plugin: _FakePlugin(),
      projectsDao: db.projectsDao,
      sessionDao: db.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );

    Future<bool> unseen(String sessionId) {
      return unseenRepository().isUnseen(sessionId: sessionId);
    }

    setUp(() {
      db = createTestDatabase();
      clock = 1000;
      viewTracker = SessionViewTracker();
      service = SessionUnseenService(
        unseenRepository: unseenRepository(),
        projectRepository: projectRepository(),
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

    test("activity for a session with no row is a no-op", () async {
      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await service.recordActivity(sessionId: "never-learned", isUserMessage: false);
      await Future<void>.delayed(Duration.zero);

      expect(await unseen("never-learned"), isFalse);
      expect(events, isEmpty);
      await sub.cancel();
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
      await service.markRead(sessionId: "s1");
      expect(await unseen("s1"), isFalse);

      clock = 750;
      await service.markUnread(sessionId: "s1");
      expect(await unseen("s1"), isTrue);

      clock = 800;
      await service.markRead(sessionId: "s1");
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
      await service.markUnread(sessionId: "s1");
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

      await service.recordSessionDeleted(sessionId: "s1", projectId: "p1");
      // Row is gone -> session is no longer unseen and can't keep the project bold.
      expect(await projectRepository().projectHasUnseenChanges(projectId: "p1"), isFalse);
    });

    test("recordSessionDeleted emits against the STORED project id, not the event's", () async {
      // Row persisted under the canonical project p1.
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      // The delete event for a dedicated-worktree session can carry the
      // worktree directory instead of the canonical project id.
      await service.recordSessionDeleted(sessionId: "s1", projectId: "/tmp/worktree-dir");
      await Future<void>.delayed(Duration.zero);

      expect(events.single.projectId, "p1");
      expect(events.single.unseen, isFalse);
      await sub.cancel();
    });

    test("recordSessionDeleted for a row-less session still emits the cleared state", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await service.recordSessionDeleted(sessionId: "ghost", projectId: "p1");
      await Future<void>.delayed(Duration.zero);

      final last = events.single;
      expect(last.sessionId, "ghost");
      expect(last.projectId, "p1");
      expect(last.unseen, isFalse);
      expect(last.projectHasUnseenChanges, isFalse);
      await sub.cancel();
    });

    test("reconcileVanishedSessions deletes stale rows and emits their clears", () async {
      // Two persisted sessions; the backend now only knows about s1.
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      await service.recordSessionCreated(sessionId: "gone", projectId: "p1", parentId: null);
      expect(await unseen("gone"), isTrue);

      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      clock = 5000;
      await service.reconcileVanishedSessions(
        projectId: "p1",
        keepSessionIds: ["s1"],
        fetchStartedAt: 5000,
      );
      await Future<void>.delayed(Duration.zero);

      expect(await unseen("gone"), isFalse);
      expect(await unseen("s1"), isTrue);
      final clear = events.where((e) => e.sessionId == "gone").single;
      expect(clear.unseen, isFalse);
      // s1 is still unseen, so the aggregate stays true.
      expect(clear.projectHasUnseenChanges, isTrue);
      await sub.cancel();
    });

    test("reconcileVanishedSessions keeps rows created after the fetch started", () async {
      await service.recordSessionCreated(sessionId: "s1", projectId: "p1", parentId: null);
      // A session created AFTER the (stale) snapshot was taken: its row's
      // created_at is past fetchStartedAt, so it must survive the reconcile
      // even though it is absent from keepSessionIds.
      clock = 9000;
      await service.recordSessionCreated(sessionId: "concurrent", projectId: "p1", parentId: null);

      await service.reconcileVanishedSessions(
        projectId: "p1",
        keepSessionIds: ["s1"],
        fetchStartedAt: 8000,
      );

      expect(await unseen("concurrent"), isTrue);
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

    test("coalesces repeated assistant activity once the session is already unseen", () async {
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

      // Subsequent assistant activity (not viewed) is coalesced: no additional
      // DB write or emit while it's already unseen.
      clock = 2001;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      clock = 2002;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      await Future<void>.delayed(Duration.zero);
      expect(events.length, equals(afterFirst));

      // A later mark-read still clears it (correctness preserved despite the
      // skipped activity bumps).
      clock = 3000;
      await service.markRead(sessionId: "s1");
      expect(await unseen("s1"), isFalse);

      await sub.cancel();
    });

    test("a re-emitted user message does not clear unseen state (OpenCode re-sends the user record)", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // The user sends a message (payload created at 2000, processed now).
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 2000);
      expect(await unseen("s1"), isFalse);

      // The assistant replies -> unseen.
      clock = 3000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);

      // The backend re-emits the SAME user message (diff-summary bookkeeping,
      // fired after the assistant completes) — original created time. This is
      // not a user interaction and must not clear the unseen state.
      clock = 4000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 2000);
      expect(await unseen("s1"), isTrue);

      // A genuinely NEW user message (newer created time) clears it.
      clock = 5000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 5000);
      expect(await unseen("s1"), isFalse);
    });

    test("re-emission guard holds when the bridge clock is BEHIND the server clock", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Server creation time (5000) is ahead of the bridge's local clock
      // (1000). The marker is stamped from the creation time, so the domains
      // stay comparable.
      clock = 1000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 5000);
      expect(await unseen("s1"), isFalse);

      // Assistant activity clamps strictly past the (locally-future) marker
      // and still bolds despite the skew.
      clock = 1500;
      await service.recordActivity(sessionId: "s1", isUserMessage: false);
      expect(await unseen("s1"), isTrue);

      // The re-emission (original creation time) must still be skipped.
      clock = 2000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 5000);
      expect(await unseen("s1"), isTrue);
    });

    test("a delayed first user message does not swallow a genuinely newer reply (backlog replay)", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // A reconnect backlog processed late (local clock 9000+): user message
      // created at 2000, assistant reply created at 2500, user reply created
      // at 3000. All stamps come from the messages' own creation times, so the
      // late processing time is irrelevant.
      clock = 9000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 2000);
      clock = 9001;
      await service.recordActivity(sessionId: "s1", isUserMessage: false, occurredAt: 2500);
      expect(await unseen("s1"), isTrue);

      // The user's reply (created 3000, after the assistant's 2500) is a
      // genuine interaction: not mistaken for a re-emission, clears the state.
      clock = 9002;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 3000);
      expect(await unseen("s1"), isFalse);
    });

    test("an old user re-emission cannot clear unseen state on a row with no user marker", () async {
      // A row learned via a /sessions placeholder (all markers null): the
      // original user message was processed before this bridge ever ran, so
      // the re-emission guard has no marker to compare against.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      // Assistant activity bolds the session.
      clock = 5000;
      await service.recordActivity(sessionId: "s1", isUserMessage: false, occurredAt: 5000);
      expect(await unseen("s1"), isTrue);

      // The backend re-emits an OLD user message (diff bookkeeping) created
      // long before the assistant activity. It bootstraps the marker but must
      // not clear the unseen state — it only proves engagement as of 1000.
      clock = 6000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 1000);
      expect(await unseen("s1"), isTrue);

      // A genuine reply (created after the assistant activity) clears it.
      clock = 7000;
      await service.recordActivity(sessionId: "s1", isUserMessage: true, occurredAt: 7000);
      expect(await unseen("s1"), isFalse);
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

    test("markRead on an unknown session is a no-op success (nothing emitted)", () async {
      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await service.markRead(sessionId: "ghost");
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });

    test("markUnread on an unknown session throws so the client refreshes", () async {
      final events = <UnseenChange>[];
      final sub = service.unseenChanges.listen(events.add);

      await expectLater(
        () => service.markUnread(sessionId: "ghost"),
        throwsA(isA<SessionUnseenRowMissingException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
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
        unseenRepository: unseenRepository(),
        projectRepository: _ThrowingProjectRepository(),
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
      await failing.markRead(sessionId: "s1");
      expect(await unseen("s1"), isFalse);
    });

    test("markUnread on an EXISTING row succeeds even when the aggregate emit throws", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "p1", createdAt: 500, archivedAt: null)],
      );
      expect(await unseen("s1"), isFalse);

      final failing = SessionUnseenService(
        unseenRepository: unseenRepository(),
        projectRepository: _ThrowingProjectRepository(),
        viewTracker: SessionViewTracker(),
        now: () => clock,
      );
      addTearDown(failing.dispose);

      // The unread write commits, so the request SUCCEEDS even though the
      // aggregate emit throws; the row already reflects the user's action.
      clock = 700;
      await failing.markUnread(sessionId: "s1");
      expect(await unseen("s1"), isTrue);
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
