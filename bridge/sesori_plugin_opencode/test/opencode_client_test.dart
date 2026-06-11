// Behavior tests for the GENERATED OpenCodeClient (lib/src/opencode_client.dart):
// auth header construction, URI building (base path prefix, query
// handling), success decoding, and non-2xx error propagation.

import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/models/openapi/session.dart";
import "package:opencode_plugin/src/opencode_client.dart";
import "package:test/test.dart";

Map<String, dynamic> sessionJson() => <String, dynamic>{
      "id": "ses_1",
      "slug": "fix-auth",
      "projectID": "prj_1",
      "directory": "/repo",
      "title": "Fix auth flow",
      "version": "1.16.2",
      "time": <String, dynamic>{"created": 100, "updated": 200},
    };

OpenCodeClient _client({
  required Future<http.Response> Function(http.Request request) handler,
  String baseUrl = "http://127.0.0.1:4096",
}) {
  return OpenCodeClient(
    baseUrl: baseUrl,
    password: "secret",
    httpClient: MockClient(handler),
  );
}

void main() {
  group("OpenCodeClient", () {
    test("decodes a typed list response", () async {
      final client = _client(
        handler: (request) async =>
            http.Response(jsonEncode(<Object>[sessionJson()]), 200),
      );
      final sessions = await client.sessionList();
      expect(sessions, hasLength(1));
      expect(sessions.first, isA<Session>());
      expect(sessions.first.time.created, 100);
    });

    test("sends Basic auth for the opencode user", () async {
      late http.Request seen;
      final client = _client(
        handler: (request) async {
          seen = request;
          return http.Response("[]", 200);
        },
      );
      await client.sessionList();
      final expected =
          "Basic ${base64Encode(utf8.encode('opencode:secret'))}";
      expect(seen.headers["Authorization"], expected);
    });

    test("omits the query string entirely when no parameters are set",
        () async {
      late Uri seen;
      final client = _client(
        handler: (request) async {
          seen = request.url;
          return http.Response("[]", 200);
        },
      );
      await client.sessionList();
      expect(seen.path, "/session");
      expect(seen.hasQuery, isFalse);
      expect(seen.toString(), isNot(contains("?")));
    });

    test("encodes provided query parameters", () async {
      late Uri seen;
      final client = _client(
        handler: (request) async {
          seen = request.url;
          return http.Response("[]", 200);
        },
      );
      await client.sessionList(directory: "/tmp/my repo");
      expect(seen.queryParameters["directory"], "/tmp/my repo");
    });

    test("preserves a path prefix on baseUrl", () async {
      late Uri seen;
      final client = _client(
        baseUrl: "http://127.0.0.1:4096/prefix",
        handler: (request) async {
          seen = request.url;
          return http.Response("[]", 200);
        },
      );
      await client.sessionList();
      expect(seen.path, "/prefix/session");
    });

    test("percent-encodes path parameters", () async {
      late Uri seen;
      final client = _client(
        handler: (request) async {
          seen = request.url;
          return http.Response(jsonEncode(sessionJson()), 200);
        },
      );
      await client.sessionGet(sessionID: "ses 1/x");
      expect(seen.toString(), contains("/session/ses%201%2Fx"));
    });

    test("throws OpenCodeApiException on non-2xx responses", () async {
      final client = _client(
        handler: (request) async => http.Response("boom", 500),
      );
      await expectLater(
        client.sessionList(),
        throwsA(
          isA<OpenCodeApiException>()
              .having((e) => e.statusCode, "statusCode", 500)
              .having((e) => e.body, "body", "boom"),
        ),
      );
    });
  });
}
