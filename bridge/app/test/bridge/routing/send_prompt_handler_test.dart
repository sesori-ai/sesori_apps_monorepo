import "dart:convert";

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
          body: jsonEncode(
            const SendPromptRequest(
              parts: [PromptPart.text(text: "Hello")],
            ).toJson(),
          ),
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
          body: jsonEncode(
            const SendPromptRequest(
              parts: [
                PromptPart.text(text: "Hello"),
                PromptPart.text(text: "World"),
              ],
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptParts, isNotNull);
      expect(plugin.lastSendPromptParts, hasLength(2));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Hello")));
      expect(plugin.lastSendPromptParts![1], equals(const PluginPromptPart.text(text: "World")));
    });

    test("parses agent + model", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body: jsonEncode(
            const SendPromptRequest(
              parts: [PromptPart.text(text: "Hello")],
              agent: "planner",
              model: PromptModel(providerID: "openai", modelID: "gpt-4o"),
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastSendPromptAgent, equals("planner"));
      expect(plugin.lastSendPromptModel?.providerID, equals("openai"));
      expect(plugin.lastSendPromptModel?.modelID, equals("gpt-4o"));
    });

    test("records correct args", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/session/s42/prompt_async",
          body: jsonEncode(
            const SendPromptRequest(
              parts: [PromptPart.text(text: "Ship it")],
              agent: "coder",
              model: PromptModel(
                providerID: "anthropic",
                modelID: "claude-3-5-sonnet",
              ),
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s42"},
        queryParams: {},
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
        makeRequest(
          "POST",
          "/session/s1/prompt_async",
          body: jsonEncode(
            const SendPromptRequest(
              parts: [PromptPart.text(text: "Hello")],
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, isNull);
    });
  });
}
