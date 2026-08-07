import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("ArchivedSessionValidator", () {
    late AppDatabase db;
    late FakeBridgePlugin plugin;
    late ArchivedSessionValidator validator;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      validator = ArchivedSessionValidator(
        sessionRepository: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
      );
      await db.sessionDao.insertSession(
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "fake",
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("allows a session that is not archived", () async {
      await expectLater(validator.requireNotArchived(sessionId: "s1"), completes);
    });

    test("allows an unknown session so the caller decides on 404", () async {
      await expectLater(validator.requireNotArchived(sessionId: "missing"), completes);
    });

    test("rejects an archived session with the archived read-only rejection", () async {
      await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

      await expectLater(
        validator.requireNotArchived(sessionId: "s1"),
        throwsA(
          isA<SessionArchivedReadOnlyException>().having(
            (e) => e.rejection,
            "rejection",
            const SessionArchivedRejection(
              sessionId: "s1",
              reason: SessionArchivedReason.archivedReadOnly,
            ),
          ),
        ),
      );
    });
  });
}
