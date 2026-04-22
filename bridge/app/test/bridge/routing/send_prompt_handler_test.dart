import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/routing/send_prompt_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("SendPromptHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SendPromptHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      final sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      handler = SendPromptHandler(
        sessionPromptService: SessionPromptService(
          sessionRepository: sessionRepository,
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/prompt_async")),
        isTrue,
      );
    });

    test("does not handle GET /session/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/prompt_async")),
        isFalse,
      );
    });

    test("extracts session id", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          effort: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("s1"));
    });

    test("parses parts", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [
            PromptPart.text(text: "Hello"),
            PromptPart.text(text: "World"),
          ],
          effort: SessionEffort.low,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptParts, isNotNull);
      expect(plugin.lastSendPromptParts, hasLength(2));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Hello")));
      expect(plugin.lastSendPromptParts![1], equals(const PluginPromptPart.text(text: "World")));
      expect(plugin.lastSendPromptEffort, equals(PluginEffort.low));
    });

    test("parses agent + model", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          effort: null,
          agent: "planner",
          model: PromptModel(providerID: "openai", modelID: "gpt-4o"),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptAgent, equals("planner"));
      expect(plugin.lastSendPromptModel?.providerID, equals("openai"));
      expect(plugin.lastSendPromptModel?.modelID, equals("gpt-4o"));
    });

    test("records correct args", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s42",
          parts: [PromptPart.text(text: "Ship it")],
          effort: null,
          agent: "coder",
          model: PromptModel(
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("s42"));
      expect(plugin.lastSendPromptParts, hasLength(1));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Ship it")));
      expect(plugin.lastSendPromptAgent, equals("coder"));
      expect(plugin.lastSendPromptModel?.providerID, equals("anthropic"));
      expect(plugin.lastSendPromptModel?.modelID, equals("claude-3-5-sonnet"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          effort: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("does not call sendCommand when command is null", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          effort: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("s1"));
      expect(plugin.lastSendCommandSessionId, isNull);
      expect(plugin.lastSendCommand, isNull);
    });

    test("calls sendCommand without sending prompt when command is present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s7",
          parts: [PromptPart.text(text: "review this")],
          effort: SessionEffort.max,
          agent: null,
          model: null,
          command: "review",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, equals("s7"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("review this"));
      expect(plugin.lastSendCommandEffort, equals(PluginEffort.max));
      expect(plugin.lastSendCommandAgent, isNull);
      expect(plugin.lastSendCommandModel, isNull);
    });

    test("passes empty arguments when no text part present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s8",
          parts: [
            PromptPart.filePath(mime: "text/plain", path: "/tmp/f.txt", filename: null),
          ],
          effort: null,
          agent: null,
          model: null,
          command: "attach",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendCommandSessionId, equals("s8"));
      expect(plugin.lastSendCommand, equals("attach"));
      expect(plugin.lastSendCommandArguments, equals(""));
    });

    test("passes agent and model when command is present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s10",
          parts: [PromptPart.text(text: "review this")],
          effort: null,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          command: "review",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, equals("s10"));
      expect(plugin.lastSendCommandAgent, equals("coder"));
      expect(plugin.lastSendCommandModel, equals((providerID: "openai", modelID: "gpt-5.4")));
    });

    test("treats blank command as no command", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s9",
          parts: [PromptPart.text(text: "Hello")],
          effort: SessionEffort.medium,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          command: "   ",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("s9"));
      expect(plugin.lastSendPromptAgent, equals("coder"));
      expect(plugin.lastSendPromptModel?.providerID, equals("openai"));
      expect(plugin.lastSendPromptEffort, isNull);
      expect(plugin.lastSendCommandSessionId, isNull);
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/session/prompt_async"),
          body: const SendPromptRequest(
            sessionId: "",
            parts: [PromptPart.text(text: "Hello")],
            effort: null,
            agent: null,
            model: null,
            command: null,
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
