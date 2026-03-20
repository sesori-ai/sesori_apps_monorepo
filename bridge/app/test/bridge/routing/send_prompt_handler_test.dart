import "package:sesori_bridge/src/bridge/routing/send_prompt_handler.dart";
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

    test("canHandle POST /session/:id/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/s1/prompt_async")),
        isTrue,
      );
    });

    test("does not handle GET /session/:id/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/s1/prompt_async")),
        isFalse,
      );
    });

    test("extracts id", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body: '{"parts":[{"type":"text","text":"Hello"}]}',
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptSessionId, equals("s1"));
    });

    test("parses parts", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body: '{"parts":[{"type":"text","text":"Hello"},{"type":"text","text":"World"}]}',
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptParts, isNotNull);
      expect(plugin.lastSendPromptParts, hasLength(2));
      expect(plugin.lastSendPromptParts![0].type, equals("text"));
      expect(plugin.lastSendPromptParts![0].text, equals("Hello"));
      expect(plugin.lastSendPromptParts![1].text, equals("World"));
    });

    test("parses agent + model", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body:
              '{"parts":[{"type":"text","text":"Hello"}],"agent":"planner","model":{"providerID":"openai","modelID":"gpt-4o"}}',
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptAgent, equals("planner"));
      expect(plugin.lastSendPromptProviderID, equals("openai"));
      expect(plugin.lastSendPromptModelID, equals("gpt-4o"));
    });

    test("records correct args", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s42/prompt_async",
          body:
              '{"parts":[{"type":"text","text":"Ship it"}],"agent":"coder","model":{"providerID":"anthropic","modelID":"claude-3-5-sonnet"}}',
        ),
        pathParams: {"id": "s42"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptSessionId, equals("s42"));
      expect(plugin.lastSendPromptParts, hasLength(1));
      expect(plugin.lastSendPromptParts![0].text, equals("Ship it"));
      expect(plugin.lastSendPromptAgent, equals("coder"));
      expect(plugin.lastSendPromptProviderID, equals("anthropic"));
      expect(plugin.lastSendPromptModelID, equals("claude-3-5-sonnet"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body: '{"parts":[{"type":"text","text":"Hello"}]}',
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, isNull);
    });
  });
}
