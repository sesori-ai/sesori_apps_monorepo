import "dart:convert";
import "dart:io";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeConfig.fromJson", () {
    test("parses model and small_model correctly", () {
      final config = OpenCodeConfig.fromJson({
        "model": "claude-opus-4",
        "small_model": "claude-haiku-3",
      });

      expect(config.model, equals("claude-opus-4"));
      expect(config.smallModel, equals("claude-haiku-3"));
    });

    test("handles missing fields gracefully — both null", () {
      final config = OpenCodeConfig.fromJson({});

      expect(config.model, isNull);
      expect(config.smallModel, isNull);
    });

    test("ignores unknown fields in the response", () {
      final config = OpenCodeConfig.fromJson({
        "model": "gpt-4o",
        "small_model": "gpt-4o-mini",
        "some_unknown_field": "ignored",
        "another_field": 42,
      });

      expect(config.model, equals("gpt-4o"));
      expect(config.smallModel, equals("gpt-4o-mini"));
    });
  });

  group("SendMessageSyncBody.toJson", () {
    test("serializes parts, system, and model correctly", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hello"},
        ],
        system: "You are a helpful assistant.",
        model: (providerID: "anthropic", modelID: "claude-opus-4"),
      );

      final json = body.toJson();

      expect(
        json["parts"],
        equals([
          {"type": "text", "text": "Hello"},
        ]),
      );
      expect(json["system"], equals("You are a helpful assistant."));
      expect(json["model"], equals({"providerID": "anthropic", "modelID": "claude-opus-4"}));
    });

    test("omits null system from JSON", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hi"},
        ],
        system: null,
        model: null,
      );

      final json = body.toJson();

      expect(json.containsKey("system"), isFalse);
      expect(json.containsKey("model"), isFalse);
    });

    test("omits null model from JSON", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hi"},
        ],
        system: "sys",
        model: null,
      );

      final json = body.toJson();

      expect(json["system"], equals("sys"));
      expect(json.containsKey("model"), isFalse);
    });

    test("includes model when provided but system is null", () {
      const body = SendMessageSyncBody(
        parts: [],
        system: null,
        model: (providerID: "openai", modelID: "gpt-4o"),
      );

      final json = body.toJson();

      expect(json.containsKey("system"), isFalse);
      expect(json["model"], equals({"providerID": "openai", "modelID": "gpt-4o"}));
    });
  });

  group("OpenCodeApi.getConfig", () {
    late _FakeServer server;

    setUp(() async {
      server = _FakeServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    test("parses config response correctly", () async {
      server.configResponse = {
        "model": "claude-opus-4",
        "small_model": "claude-haiku-3",
        "extra_field": "ignored",
      };

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);
      final config = await api.getConfig();

      expect(config.model, equals("claude-opus-4"));
      expect(config.smallModel, equals("claude-haiku-3"));
    });

    test("handles config with missing model fields", () async {
      server.configResponse = {"some_other_field": "value"};

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);
      final config = await api.getConfig();

      expect(config.model, isNull);
      expect(config.smallModel, isNull);
    });

    test("throws OpenCodeApiException on non-2xx response", () async {
      server.configStatusCode = HttpStatus.internalServerError;

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);

      expect(api.getConfig(), throwsA(isA<OpenCodeApiException>()));
    });
  });

  group("OpenCodeApi.sendMessageSync", () {
    late _FakeServer server;

    setUp(() async {
      server = _FakeServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    test("sends correct request and parses MessageWithParts response", () async {
      server.sendMessageResponse = {
        "info": {
          "id": "msg-1",
          "role": "assistant",
          "sessionID": "ses-abc",
        },
        "parts": [
          {
            "id": "part-1",
            "sessionID": "ses-abc",
            "messageID": "msg-1",
            "type": "text",
            "text": "Hello from AI",
          },
        ],
      };

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hi"},
        ],
        system: null,
        model: null,
      );

      final result = await api.sendMessageSync(
        sessionId: "ses-abc",
        directory: "/my/project",
        body: body,
      );

      expect(result.info.id, equals("msg-1"));
      expect(result.info.role, equals("assistant"));
      expect(result.parts, hasLength(1));

      // Verify the request was sent with the correct directory header
      expect(server.lastDirectoryHeader, equals("/my/project"));
      expect(server.lastContentType, contains("application/json"));
    });

    test("sends body parts and model in request", () async {
      server.sendMessageResponse = {
        "info": {"id": "msg-2", "role": "assistant", "sessionID": "ses-xyz"},
        "parts": <dynamic>[],
      };

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "test prompt"},
        ],
        system: "be concise",
        model: (providerID: "anthropic", modelID: "claude-opus-4"),
      );

      await api.sendMessageSync(
        sessionId: "ses-xyz",
        directory: "/proj",
        body: body,
      );

      final sentBody = server.lastRequestBody!;
      expect(
        sentBody["parts"],
        equals([
          {"type": "text", "text": "test prompt"},
        ]),
      );
      expect(sentBody["system"], equals("be concise"));
      expect(sentBody["model"], equals({"providerID": "anthropic", "modelID": "claude-opus-4"}));
    });

    test("throws OpenCodeApiException on non-2xx response", () async {
      server.sendMessageStatusCode = HttpStatus.badRequest;

      final api = OpenCodeApi(serverURL: server.baseUrl, password: null);
      const body = SendMessageSyncBody(parts: [], system: null, model: null);

      expect(
        api.sendMessageSync(sessionId: "ses-err", directory: "/d", body: body),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}

class _FakeServer {
  HttpServer? _server;

  Map<String, dynamic>? configResponse;
  int configStatusCode = HttpStatus.ok;

  Map<String, dynamic>? sendMessageResponse;
  int sendMessageStatusCode = HttpStatus.ok;

  String? lastDirectoryHeader;
  String? lastContentType;
  Map<String, dynamic>? lastRequestBody;

  String get baseUrl => "http://${_server!.address.address}:${_server!.port}";

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;

      if (request.method == "GET" && path == "/config") {
        await _sendJson(request.response, configResponse ?? {}, configStatusCode);
        return;
      }

      final messageMatch = RegExp(r"^/session/([^/]+)/message$").firstMatch(path);
      if (messageMatch != null && request.method == "POST") {
        lastDirectoryHeader = request.headers.value("x-opencode-directory");
        lastContentType = request.headers.value("content-type");
        final rawBody = await utf8.decoder.bind(request).join();
        lastRequestBody = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        await _sendJson(
          request.response,
          sendMessageResponse ?? <String, dynamic>{"info": <String, dynamic>{}, "parts": <dynamic>[]},
          sendMessageStatusCode,
        );
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _sendJson(HttpResponse response, Object body, int statusCode) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
