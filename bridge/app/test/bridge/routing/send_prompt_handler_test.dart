import "package:sesori_bridge/src/bridge/routing/send_prompt_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("SendPromptHandler", () {
    late FakeBridgePlugin plugin;
    late SendPromptHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = SendPromptHandler(plugin);
    });

    tearDown(() => plugin.close());

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
          agent: null,
          model: null,
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
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptParts, isNotNull);
      expect(plugin.lastSendPromptParts, hasLength(2));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Hello")));
      expect(plugin.lastSendPromptParts![1], equals(const PluginPromptPart.text(text: "World")));
    });

    test("parses agent + model", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          agent: "planner",
          model: PromptModel(providerID: "openai", modelID: "gpt-4o"),
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
          agent: "coder",
          model: PromptModel(
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
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
          agent: null,
          model: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/session/prompt_async"),
          body: const SendPromptRequest(
            sessionId: "",
            parts: [PromptPart.text(text: "Hello")],
            agent: null,
            model: null,
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
