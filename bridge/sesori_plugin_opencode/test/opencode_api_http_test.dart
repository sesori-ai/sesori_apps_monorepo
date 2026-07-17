import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeApi.listProviders", () {
    test("uses the provider-list response shape for GET /provider", () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "all": [
              {
                "id": "openai",
                "name": "OpenAI",
                "source": "config",
                "env": <String>[],
                "options": <String, dynamic>{},
                "models": <String, dynamic>{},
              },
            ],
            "default": {"openai": "gpt-4.1"},
            "connected": ["openai"],
          }),
          200,
        );
      });

      final api = OpenCodeApi(
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      final response = await api.listProviders();

      expect(response.all.single.id, equals("openai"));
      expect(response.connected, equals(["openai"]));
    });
  });

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
                "source": "config",
                "env": <String>[],
                "options": <String, dynamic>{},
                "models": {
                  "gpt-4.1": {
                    "id": "openai/gpt-4.1",
                    "providerID": "openai",
                    "name": "GPT-4.1",
                    "api": {
                      "id": "openai/gpt-4.1",
                      "url": "https://api.openai.com/v1",
                      "npm": "@ai-sdk/openai",
                    },
                    "capabilities": {
                      "temperature": true,
                      "reasoning": false,
                      "attachment": false,
                      "toolcall": true,
                      "input": {
                        "text": true,
                        "audio": false,
                        "image": false,
                        "video": false,
                        "pdf": false,
                      },
                      "output": {
                        "text": true,
                        "audio": false,
                        "image": false,
                        "video": false,
                        "pdf": false,
                      },
                      "interleaved": false,
                    },
                    "cost": {
                      "input": 0,
                      "output": 0,
                      "cache": {"read": 0, "write": 0},
                    },
                    "limit": {"context": 0, "output": 0},
                    "status": "active",
                    "options": <String, dynamic>{},
                    "headers": <String, dynamic>{},
                    "release_date": "2025-01-01",
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
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      final response = await api.listConfigProviders(directory: "/repo");

      expect(capturedRequest.method, equals("GET"));
      expect(capturedRequest.url.toString(), equals("http://localhost:1234/config/providers"));
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(response.providers.single.models.values.single.variants?.keys, equals(["low", "high"]));
    });
  });

  group("OpenCodeApi.listAgents", () {
    test("uses GET /agent and forwards the directory header", () async {
      late http.BaseRequest capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {
              "name": "build",
              "description": "The default agent.",
              "mode": "primary",
              "permission": <dynamic>[],
              "options": <String, dynamic>{},
              "model": {"modelID": "gpt-4.1", "providerID": "openai"},
            },
          ]),
          200,
        );
      });

      final api = OpenCodeApi(
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      final agents = await api.listAgents(directory: "/repo");

      expect(capturedRequest.method, equals("GET"));
      expect(capturedRequest.url.toString(), equals("http://localhost:1234/agent"));
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(agents.single.name, equals("build"));
    });

    test("includes the upstream response body in the thrown exception", () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"name":"UnknownError","data":{"message":"boom"}}', 500);
      });

      final api = OpenCodeApi(
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      await expectLater(
        api.listAgents(directory: "/repo"),
        throwsA(
          isA<OpenCodeApiException>()
              .having((e) => e.statusCode, "statusCode", 500)
              .having((e) => e.responseBody, "responseBody", contains("UnknownError")),
        ),
      );
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
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
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

  group("OpenCodeApi.sendPrompt", () {
    test("uses the synchronous endpoint for no-reply prompts", () async {
      late http.BaseRequest capturedRequest;
      late String capturedBody;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response("{}", 200);
      });
      final api = OpenCodeApi(
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      await api.sendPrompt(
        sessionId: "ses-123",
        body: const SendPromptBody(
          parts: [PluginPromptPart.text(text: "Keep auth decisions")],
          agent: "build",
          variant: null,
          model: (providerID: "openai", modelID: "gpt-4.1"),
          noReply: true,
        ),
        directory: "/repo",
      );

      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/session/ses-123/message"),
      );
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(jsonDecodeMap(capturedBody)["noReply"], isTrue);
    });
  });

  group("OpenCodeApi.summarize", () {
    test("uses the injected client for POST /session/{id}/summarize", () async {
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
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      await api.summarize(
        sessionId: "ses-123",
        body: const SummarizeBody(providerID: "openai", modelID: "gpt-4.1"),
        directory: "/repo",
      );

      expect(calls, equals(1));
      expect(capturedRequest.method, equals("POST"));
      expect(
        capturedRequest.url.toString(),
        equals("http://localhost:1234/session/ses-123/summarize"),
      );
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
      expect(
        jsonDecode(capturedBody),
        equals({
          "providerID": "openai",
          "modelID": "gpt-4.1",
          "auto": false,
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
        noReply: false,
      );

      expect(body.toJson().containsKey("variant"), isFalse);
      expect(body.toJson().containsKey("noReply"), isFalse);
    });

    test("SendPromptBody includes noReply when enabled", () {
      const body = SendPromptBody(
        parts: [PluginPromptPart.text(text: "Keep auth decisions")],
        agent: "build",
        variant: null,
        model: (providerID: "openai", modelID: "gpt-4.1"),
        noReply: true,
      );

      expect(body.toJson()["noReply"], isTrue);
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
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      await api.replyToPermission(
        requestId: "perm-123",
        directory: "/repo",
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
      expect(capturedRequest.headers["x-opencode-directory"], equals("/repo"));
    });

    test("throws OpenCodeApiException on server error", () async {
      final mockClient = MockClient((request) async {
        return http.Response("Internal Server Error", 500);
      });

      final api = OpenCodeApi(
        client: OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: "test-pass",
          client: mockClient,
        ),
      );

      expect(
        () => api.replyToPermission(
          requestId: "perm-123",
          directory: "/repo",
          reply: .once,
        ),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}
