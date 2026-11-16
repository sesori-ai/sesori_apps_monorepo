import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/set_session_pinned_handler.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/session_interruption_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("SetSessionPinnedHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late SessionOperationDispatcher sessionOperationDispatcher;
    late SessionMutationDispatcher sessionMutationDispatcher;
    late SetSessionPinnedHandler handler;

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
      handler = SetSessionPinnedHandler(
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
    });

    tearDown(() async {
      await sessionOperationDispatcher.dispose();
      await sessionMutationDispatcher.dispose();
      await plugin.close();
      await db.close();
    });

    Future<RelayResponse> patch({required String sessionId, required bool pinned}) => handler.routeForTest(
      makeRequest(
        "PATCH",
        "/session/pinned",
        body: jsonEncode(SetSessionPinnedRequest(sessionId: sessionId, pinned: pinned).toJson()),
      ),
    );

    test("handles PATCH /session/pinned only", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/pinned")), isTrue);
      expect(handler.canHandle(makeRequest("POST", "/session/pinned")), isFalse);
      expect(handler.canHandle(makeRequest("PATCH", "/session/title")), isFalse);
    });

    test("pins the session and returns it", () async {
      final response = await patch(sessionId: "s1", pinned: true);

      expect(response.status, 200);
      final session = Session.fromJson(jsonDecodeMap(response.body ?? ""));
      expect((session.id, session.pinned), ("s1", true));
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.pinned, isTrue);
    });

    test("a missing session is the route's own 404, unlike an unknown route", () async {
      final response = await patch(sessionId: "missing", pinned: true);

      expect(response.status, 404);
      expect(response.body, isNot(startsWith("no handler found for ")));
    });

    test("an empty session id is a 400", () async {
      expect((await patch(sessionId: "", pinned: true)).status, 400);
    });
  });
}
