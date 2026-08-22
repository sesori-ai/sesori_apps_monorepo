import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/routing/reply_to_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("ReplyToQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ReplyToQuestionHandler handler;

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
      handler = ReplyToQuestionHandler(pendingInteractionService: pending.service);
    });

    tearDown(() => plugin.close());

    test("returns 409 for an archived session", () async {
      await db.sessionDao.setArchived(sessionId: "ses-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/question/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              requestId: "q-1",
              sessionId: "ses-1",
              answers: [ReplyAnswer(values: ["yes"])],
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 409);
      expect(plugin.lastReplyQuestionId, isNull);
    });

    test("canHandle POST /question/reply", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reply")), isTrue);
    });

    test("extracts requestId, sessionId, and parses answers", () async {
      await handler.handle(
        makeRequest("POST", "/question/reply"),
        body: const ReplyToQuestionRequest(
          requestId: "q1",
          sessionId: "ses-1",
          answers: [
            ReplyAnswer(values: ["yes"]),
            ReplyAnswer(values: ["tool-a", "tool-b"]),
          ],
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastReplyQuestionId, equals("q1"));
      expect(plugin.lastReplySessionId, equals("backend-ses-1"));
      expect(
        plugin.lastReplyAnswers,
        equals(const [
          ["yes"],
          ["tool-a", "tool-b"],
        ]),
      );
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/reply"),
        body: const ReplyToQuestionRequest(
          requestId: "q1",
          sessionId: "ses-1",
          answers: [
            ReplyAnswer(values: ["ok"]),
          ],
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("returns 400 on empty request id", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/question/reply"),
          body: const ReplyToQuestionRequest(
            requestId: "",
            sessionId: "ses-1",
            answers: [
              ReplyAnswer(values: ["ok"]),
            ],
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reply"),
          body: const ReplyToQuestionRequest(
            requestId: "q1",
            sessionId: "",
            answers: [
              ReplyAnswer(values: ["ok"]),
            ],
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
