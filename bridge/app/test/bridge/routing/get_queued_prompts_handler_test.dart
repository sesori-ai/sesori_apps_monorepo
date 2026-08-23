import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/get_queued_prompts_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetQueuedPromptsHandler", () {
    late FakeBridgePlugin plugin;
    late GetQueuedPromptsHandler handler;

    setUp(() async {
      plugin = FakeBridgePlugin();
      final db = createTestDatabase();
      addTearDown(db.close);
      await recordSessionBinding(
        database: db,
        sessionId: "s-1",
        backendSessionId: "backend-s-1",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      handler = GetQueuedPromptsHandler(
        sessionRepository: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
      );
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session/queued_prompts and rejects GET", () {
      expect(handler.canHandle(makeRequest("POST", "/session/queued_prompts")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/queued_prompts")), isFalse);
    });

    test("returns 400 when session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/queued_prompts"),
          body: const SessionIdRequest(sessionId: ""),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("maps plugin entries to the shared wire model in order", () async {
      plugin.queuedPrompts.addAll(const [
        PluginQueuedPrompt(id: "prm_1", text: "first", command: null, attachmentCount: 0, createdAt: 10),
        PluginQueuedPrompt(id: "prm_2", text: null, command: "review", attachmentCount: 2, createdAt: 20),
      ]);

      final response = await handler.handle(
        makeRequest("POST", "/session/queued_prompts"),
        body: const SessionIdRequest(sessionId: "s-1"),
      );

      expect(response.data, const [
        QueuedSessionPrompt(id: "prm_1", text: "first", command: null, attachmentCount: 0, createdAt: 10),
        QueuedSessionPrompt(id: "prm_2", text: null, command: "review", attachmentCount: 2, createdAt: 20),
      ]);
    });

    test("returns an empty list when the plugin queues nothing", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/queued_prompts"),
        body: const SessionIdRequest(sessionId: "s-1"),
      );

      expect(response.data, isEmpty);
    });

    test("throws not-found for an unknown session", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/queued_prompts"),
          body: const SessionIdRequest(sessionId: "missing"),
        ),
        throwsA(isA<PluginOperationException>().having((e) => e.statusCode, "statusCode", equals(404))),
      );
    });
  });
}
