import "dart:convert";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeRawHttpClient", () {
    test("builds the URL with query params and merges Basic auth + caller headers", () async {
      late http.BaseRequest captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response("[]", 200);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: "pw",
        client: mockClient,
      );

      await client.get(
        path: "/session",
        queryParameters: const {"roots": "true"},
        headers: const {"x-opencode-directory": "/repo"},
      );

      expect(captured.method, equals("GET"));
      expect(captured.url.toString(), equals("http://localhost:1234/session?roots=true"));
      expect(
        captured.headers["authorization"],
        equals("Basic ${base64.encode(utf8.encode("opencode:pw"))}"),
      );
      expect(captured.headers["x-opencode-directory"], equals("/repo"));
    });

    test("omits the auth header when no password is configured", () async {
      late http.BaseRequest captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response("{}", 200);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: null,
        client: mockClient,
      );

      await client.get(path: "/project");

      expect(captured.headers.containsKey("authorization"), isFalse);
    });

    test("forwards the body on POST", () async {
      late String capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response("true", 200);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: null,
        client: mockClient,
      );

      await client.post(path: "/session/s1/command", body: '{"command":"/x"}');

      expect(capturedBody, equals('{"command":"/x"}'));
    });

    test("throws OpenCodeApiException carrying the upstream status, body, and endpoint label", () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"name":"UnknownError"}', 500);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: null,
        client: mockClient,
      );

      await expectLater(
        client.get(path: "/agent"),
        throwsA(
          isA<OpenCodeApiException>()
              .having((e) => e.statusCode, "statusCode", 500)
              .having((e) => e.responseBody, "responseBody", contains("UnknownError"))
              .having((e) => e.endpoint, "endpoint", "GET /agent"),
        ),
      );
    });

    test("maps a timeout to OpenCodeApiException with status 504", () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response("late", 200);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: null,
        client: mockClient,
      );

      await expectLater(
        client.get(path: "/session", timeout: const Duration(milliseconds: 10)),
        throwsA(
          isA<OpenCodeApiException>()
              .having((e) => e.statusCode, "statusCode", 504)
              .having((e) => e.endpoint, "endpoint", "GET /session"),
        ),
      );
    });

    test("a null timeout lets a slow request complete", () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response("done", 200);
      });

      final client = OpenCodeRawHttpClient(
        serverURL: "http://localhost:1234",
        password: null,
        client: mockClient,
      );

      final response = await client.post(
        path: "/session/s1/command",
        body: "x",
        timeout: null,
      );

      expect(response.body, equals("done"));
    });

    test("applies the default 30s timeout to idempotent GET reads", () {
      fakeAsync((async) {
        final mockClient = MockClient((request) async {
          await Future<void>.delayed(const Duration(minutes: 5));
          return http.Response("late", 200);
        });

        final client = OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: null,
          client: mockClient,
        );

        Object? error;
        () async {
          try {
            await client.get(path: "/session");
          } catch (e) {
            error = e;
          }
        }();

        // A read with no explicit timeout must abort at the 30s default.
        async.elapse(const Duration(seconds: 31));

        expect(error, isA<OpenCodeApiException>());
        expect((error! as OpenCodeApiException).statusCode, equals(504));
      });
    });

    test("imposes no default timeout on non-idempotent writes", () {
      // Guards the regression the PR fixes: a POST/PATCH/DELETE that inherits
      // the read timeout would surface a false 504 while OpenCode still commits
      // the mutation. Writes must wait for the real response instead.
      fakeAsync((async) {
        final mockClient = MockClient((request) async {
          await Future<void>.delayed(const Duration(minutes: 5));
          return http.Response("done", 200);
        });

        final client = OpenCodeRawHttpClient(
          serverURL: "http://localhost:1234",
          password: null,
          client: mockClient,
        );

        Object? error;
        http.Response? response;
        () async {
          try {
            response = await client.post(path: "/session", body: "x");
          } catch (e) {
            error = e;
          }
        }();

        // Well past the 30s read deadline: the write must NOT have timed out.
        async.elapse(const Duration(seconds: 31));
        expect(error, isNull);
        expect(response, isNull);

        // It still completes once OpenCode eventually responds.
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(error, isNull);
        expect(response?.body, equals("done"));
      });
    });
  });
}
