import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/routing/reject_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RejectQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late RejectQuestionHandler handler;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      addTearDown(db.close);
      await recordSessionBinding(
        database: db,
        sessionId: "ses-1",
        backendSessionId: "backend-ses-1",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      final pending = buildTestPendingInteractionService(database: db, plugin: plugin);
      addTearDown(pending.dispatcher.dispose);
      addTearDown(pending.service.dispose);
      handler = RejectQuestionHandler(pendingInteractionService: pending.service);
    });

    tearDown(() => plugin.close());

    test("returns 409 for an archived session", () async {
      await db.sessionDao.setArchived(sessionId: "ses-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await handler.routeForTest(
        makeRequest(
          "POST",
          "/question/reject",
          body: jsonEncode(const RejectQuestionRequest(requestId: "q-1", sessionId: "ses-1").toJson()),
        ),
      );

      expect(response.status, 409);
      expect(plugin.lastRejectQuestionId, isNull);
    });

    test("canHandle POST /question/reject", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reject")), isTrue);
    });

    test("extracts requestId and records reject call", () async {
      await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
      expect(plugin.lastRejectSessionId, equals("backend-ses-1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("throws 400 on empty request id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reject"),
          body: const RejectQuestionRequest(requestId: "", sessionId: "ses-1"),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reject"),
          body: const RejectQuestionRequest(requestId: "q1", sessionId: ""),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    for (final invalidBody in ['{"requestId":"q1"}', '{"requestId":"q1","sessionId":null}']) {
      test("returns 400 when sessionId is missing or null: $invalidBody", () async {
        final response = await handler.routeForTest(
          makeRequest("POST", "/question/reject", body: invalidBody),
        );

        expect(response.status, 400);
      });
    }
  });
}
