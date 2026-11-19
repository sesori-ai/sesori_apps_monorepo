import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/routing/reject_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/agent_page_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RejectQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late RejectQuestionHandler handler;
    late AgentPageRepository pages;
    late RecordingSessionNotices notices;

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
      final agentPages = buildTestAgentPages(database: db, plugin: plugin);
      pages = agentPages.pages;
      notices = agentPages.notices;
      addTearDown(pages.dispose);
      handler = RejectQuestionHandler(
        pendingInteractionService: pending.service,
        agentPageService: agentPages.service,
      );
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

    test("a page's id dismisses the page instead of reaching the plugin", () async {
      final pageId = await addTestPage(pages: pages, sessionId: "ses-1");

      final response = await handler.handle(
        request: makeRequest("POST", "/question/reject"),
        body: RejectQuestionRequest(requestId: pageId, sessionId: "ses-1"),
      );

      expect(response, equals(const SuccessEmptyResponse()));
      expect(plugin.lastRejectQuestionId, isNull);
      expect(await pages.pendingPages(sessionId: "ses-1"), isEmpty);
      final [delivered] = notices.delivered;
      expect(delivered.sessionId, "ses-1");
      expect(delivered.notice.summary, "You closed “Release plan” without answering.");
      expect(delivered.notice.pageRequestId, pageId);
    });

    test("a settled page answers 404 and tells nobody again", () async {
      final pageId = await addTestPage(pages: pages, sessionId: "ses-1");
      final request = makeRequest(
        "POST",
        "/question/reject",
        body: jsonEncode(RejectQuestionRequest(requestId: pageId, sessionId: "ses-1").toJson()),
      );
      await handler.routeForTest(request);

      final response = await handler.routeForTest(request);

      expect(response.status, 404);
      expect(notices.delivered, hasLength(1));
      expect(plugin.lastRejectQuestionId, isNull);
    });

    test("an archived session's page stays pending", () async {
      final pageId = await addTestPage(pages: pages, sessionId: "ses-1");
      await db.sessionDao.setArchived(sessionId: "ses-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await handler.routeForTest(
        makeRequest(
          "POST",
          "/question/reject",
          body: jsonEncode(RejectQuestionRequest(requestId: pageId, sessionId: "ses-1").toJson()),
        ),
      );

      expect(response.status, 409);
      expect(notices.delivered, isEmpty);
      expect(await pages.pendingPages(sessionId: "ses-1"), hasLength(1));
    });

    test("a page asked for from another session reaches the plugin", () async {
      final pageId = await addTestPage(pages: pages, sessionId: "ses-1");
      await recordSessionBinding(
        database: db,
        sessionId: "ses-2",
        backendSessionId: "backend-ses-2",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );

      await handler.handle(
        request: makeRequest("POST", "/question/reject"),
        body: RejectQuestionRequest(requestId: pageId, sessionId: "ses-2"),
      );

      expect(plugin.lastRejectQuestionId, pageId);
      expect(notices.delivered, isEmpty);
    });

    test("canHandle POST /question/reject", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reject")), isTrue);
    });

    test("extracts requestId and records reject call", () async {
      await handler.handle(
        request: makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
      expect(plugin.lastRejectSessionId, equals("backend-ses-1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        request: makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1", sessionId: "ses-1"),
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("throws 400 on empty request id", () async {
      expect(
        () => handler.handle(
          request: makeRequest("POST", "/question/reject"),
          body: const RejectQuestionRequest(requestId: "", sessionId: "ses-1"),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          request: makeRequest("POST", "/question/reject"),
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
