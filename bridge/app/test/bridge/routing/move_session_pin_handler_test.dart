import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/move_session_pin_handler.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/session_interruption_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("MoveSessionPinHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late SessionOperationDispatcher sessionOperationDispatcher;
    late SessionMutationDispatcher sessionMutationDispatcher;
    late MoveSessionPinHandler handler;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      sessionOperationDispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      sessionMutationDispatcher = SessionMutationDispatcher(
        interruptions: const NoSessionInterruptions(),
        sessionRepository: sessionRepository,
        sessionOperationDispatcher: sessionOperationDispatcher,
      );
      handler = MoveSessionPinHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionMutationDispatcher: sessionMutationDispatcher,
      );
      await insertTestSession(
        db: db,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: "fake",
        projectId: "p1",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      // Pinned in this order, so s1 lists last.
      for (final sessionId in ["s1", "s2", "s3"]) {
        if (sessionId != "s1") {
          await insertTestSession(
            db: db,
            sessionId: sessionId,
            backendSessionId: "backend-$sessionId",
            pluginId: "fake",
            projectId: "p1",
            isDedicated: false,
            createdAt: 1,
            worktreePath: null,
            baseBranch: null,
            baseCommit: null,
            agent: null,
            agentModel: null,
          );
        }
        await db.sessionDao.setPinned(sessionId: sessionId, pinned: true);
      }
    });

    tearDown(() async {
      await sessionOperationDispatcher.dispose();
      await sessionMutationDispatcher.dispose();
      await plugin.close();
      await db.close();
    });

    Future<RelayResponse> patch({required String sessionId, required String? afterSessionId}) => handler.routeForTest(
      makeRequest(
        "PATCH",
        "/session/pin-position",
        body: jsonEncode(MoveSessionPinRequest(sessionId: sessionId, afterSessionId: afterSessionId).toJson()),
      ),
    );

    test("handles PATCH /session/pin-position only", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/pin-position")), isTrue);
      expect(handler.canHandle(makeRequest("POST", "/session/pin-position")), isFalse);
      expect(handler.canHandle(makeRequest("PATCH", "/session/pinned")), isFalse);
    });

    test("moves the pin and returns every session whose place changed, top first", () async {
      final response = await patch(sessionId: "s1", afterSessionId: null);

      expect(response.status, 200);
      final moved = MoveSessionPinResponse.fromJson(jsonDecodeMap(response.body ?? ""));
      expect([for (final session in moved.sessions) session.id], ["s1"]);
      expect([for (final row in await db.sessionDao.getPinnedOrder()) row.sessionId], ["s1", "s3", "s2"]);
    });

    test("a session or anchor that is not pinned is the route's own 404", () async {
      await db.sessionDao.setPinned(sessionId: "s2", pinned: false);

      for (final (sessionId, afterSessionId) in [("missing", null), ("s1", "s2")]) {
        final response = await patch(sessionId: sessionId, afterSessionId: afterSessionId);
        expect(response.status, 404);
        expect(response.body, isNot(startsWith("no handler found for ")));
      }
    });

    test("an empty session or anchor id is a 400", () async {
      expect((await patch(sessionId: "", afterSessionId: null)).status, 400);
      expect((await patch(sessionId: "s1", afterSessionId: "")).status, 400);
    });
  });
}
