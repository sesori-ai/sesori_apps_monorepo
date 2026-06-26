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
