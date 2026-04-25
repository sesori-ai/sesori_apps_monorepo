import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeApi.listConfigProviders", () {
    test("uses GET /config/providers and forwards the directory header", () async {
      late http.BaseRequest capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            "providers": [
              {
                "id": "openai",
                "name": "OpenAI",
                "models": {
                  "gpt-4.1": {
                    "id": "openai/gpt-4.1",
                    "providerID": "openai",
                    "name": "GPT-4.1",
                    "variants": {
                      "low": {"disabled": false},
                      "high": {"disabled": false},
                    },
                  },
                },
              },
            ],
            "default": {"openai": "openai/gpt-4.1"},
          }),
          200,
        );
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      final response = await api.listConfigProviders(directory: "/repo");

      expect(capturedRequest.method, equals("GET"));
      expect(capturedRequest.url.toString(), equals("http://localhost:1234/config/providers"));
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(response.providers.single.models.values.single.variants, equals(["low", "high"]));
    });
  });

  group("OpenCodeApi.sendCommand", () {
    test("uses the injected client for POST /session/{id}/command", () async {
      var calls = 0;
      late http.BaseRequest capturedRequest;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        calls += 1;
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response("true", 200);
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      await api.sendCommand(
        sessionId: "ses-123",
        body: const SendCommandBody(
          command: "/review-work",
          arguments: "recent changes",
          agent: "reviewer",
          variant: "xhigh",
          model: (providerID: "openai", modelID: "gpt-4.1"),
        ),
        directory: "/repo",
      );

      expect(calls, equals(1));
      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/session/ses-123/command"),
      );
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(
        jsonDecode(capturedBody),
        equals({
          "command": "/review-work",
          "arguments": "recent changes",
          "agent": "reviewer",
          "variant": "xhigh",
          "model": "openai/gpt-4.1",
        }),
      );
    });
  });

  group("Send body serialization", () {
    test("SendPromptBody omits variant when null", () {
      const body = SendPromptBody(
        parts: [PluginPromptPart.text(text: "Hello")],
        agent: null,
        variant: null,
        model: null,
      );

      expect(body.toJson().containsKey("variant"), isFalse);
    });

    test("SendCommandBody includes variant when provided", () {
      const body = SendCommandBody(
        command: "/review-work",
        arguments: "recent changes",
        agent: null,
        variant: "low",
        model: null,
      );

      expect(body.toJson()["variant"], equals("low"));
    });
  });

  group("OpenCodeApi.replyToPermission", () {
    test("sends POST to /permission/{requestId}/reply with reply body", () async {
      late http.BaseRequest capturedRequest;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response("true", 200);
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      await api.replyToPermission(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: .once,
      );

      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/permission/perm-123/reply"),
      );
      expect(jsonDecode(capturedBody), equals({"reply": "once"}));
      expect(capturedRequest.headers["authorization"], isNotNull);
      expect(capturedRequest.headers["content-type"], equals("application/json"));
    });

    test("throws OpenCodeApiException on server error", () async {
      final mockClient = MockClient((request) async {
        return http.Response("Internal Server Error", 500);
      });

      final api = OpenCodeApi(
        serverURL: "http://localhost:1234",
        password: "test-pass",
        client: mockClient,
      );

      expect(
        () => api.replyToPermission(
          requestId: "perm-123",
          sessionId: "ses-456",
          reply: .once,
        ),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}
