import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/routing/reject_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RejectQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late RejectQuestionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      final db = createTestDatabase();
      addTearDown(db.close);
      handler = RejectQuestionHandler(
        questionRepository: QuestionRepository(plugin: plugin, sessionDao: db.sessionDao),
      );
    });

    tearDown(() => plugin.close());

    test("canHandle POST /question/reject", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reject")), isTrue);
    });

    test("extracts requestId and records reject call", () async {
      await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
      expect(plugin.lastRejectSessionId, equals("ses-1"));
    });

    test("allows null sessionId for backwards compatibility", () async {
      await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
      expect(plugin.lastRejectSessionId, isNull);
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("throws 400 on empty request id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reject"),
          body: const RejectQuestionRequest(requestId: "", sessionId: null),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
