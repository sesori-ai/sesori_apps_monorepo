import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/cancel_queued_prompt_handler.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_session_options_service.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("CancelQueuedPromptHandler", () {
    late FakeBridgePlugin plugin;
    late CancelQueuedPromptHandler handler;
    late AppDatabase db;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      addTearDown(db.close);
      await recordSessionBinding(
        database: db,
        sessionId: "s-1",
        backendSessionId: "backend-s-1",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final service = SessionPromptService(
        sessionRepository: repository,
        dispatcher: dispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: repository),
        sessionOptionsService: FakeSessionOptionsService(),
      );
      addTearDown(dispatcher.dispose);
      addTearDown(service.dispose);
      handler = CancelQueuedPromptHandler(sessionPromptService: service);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session/prompt/cancel", () {
      expect(handler.canHandle(makeRequest("POST", "/session/prompt/cancel")), isTrue);
    });

    test("returns 400 for an empty session or prompt id", () async {
      for (final body in const [
        CancelQueuedPromptRequest(sessionId: "", promptId: "prm_1"),
        CancelQueuedPromptRequest(sessionId: "s-1", promptId: ""),
      ]) {
        await expectLater(
          () => handler.handle(
            makeRequest("POST", "/session/prompt/cancel"),
            body: body,
            pathParams: {},
            queryParams: {},
            fragment: null,
          ),
          throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
        );
      }
    });

    test("removes the queued entry via the backend session id", () async {
      plugin.queuedPrompts.add(
        const PluginQueuedPrompt(id: "prm_1", text: "queued", command: null, attachmentCount: 0, createdAt: 1),
      );

      final response = await handler.handle(
        makeRequest("POST", "/session/prompt/cancel"),
        body: const CancelQueuedPromptRequest(sessionId: "s-1", promptId: "prm_1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.queuedPrompts, isEmpty);
      expect(plugin.cancelQueuedPromptCalls, [(sessionId: "backend-s-1", promptId: "prm_1")]);
    });

    test("refuses to cancel on an archived session without reaching the plugin", () async {
      plugin.queuedPrompts.add(
        const PluginQueuedPrompt(id: "prm_1", text: "queued", command: null, attachmentCount: 0, createdAt: 1),
      );
      await db.sessionDao.setArchived(sessionId: "s-1", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/prompt/cancel"),
          body: const CancelQueuedPromptRequest(sessionId: "s-1", promptId: "prm_1"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<SessionArchivedReadOnlyException>()),
      );
      expect(plugin.cancelQueuedPromptCalls, isEmpty);
      expect(plugin.queuedPrompts, hasLength(1));
    });

    test("returns 404 when the entry no longer exists", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/prompt/cancel"),
          body: const CancelQueuedPromptRequest(sessionId: "s-1", promptId: "prm_gone"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(404))),
      );
    });
  });
}
