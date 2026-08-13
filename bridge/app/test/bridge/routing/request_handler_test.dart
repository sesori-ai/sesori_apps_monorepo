import "package:sesori_bridge/src/bridge/routing/request_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

// Minimal concrete subclass used to exercise base-class behaviour.
class _StubHandler(super.method, super.path) extends RequestHandlerBase {
  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async => RelayResponse(
    id: request.id,
    status: 200,
    headers: {},
    body: null,
  );
}

// Throws the configured error from handle() to exercise error mapping.
class _ThrowingGetHandler(final Object _error) extends GetRequestHandler<Object> {
  this : super("/throw");

  @override
  Future<Object> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async => throw _error;
}

void main() {
  group("HttpMethod", () {
    test("parses supported external methods case-insensitively", () {
      expect(HttpMethod.parseExternal(rawMethod: "GET"), HttpMethod.get);
      expect(HttpMethod.parseExternal(rawMethod: "Post"), HttpMethod.post);
      expect(HttpMethod.parseExternal(rawMethod: "put"), HttpMethod.put);
      expect(HttpMethod.parseExternal(rawMethod: "PATCH"), HttpMethod.patch);
      expect(HttpMethod.parseExternal(rawMethod: "DELETE"), HttpMethod.delete);
    });

    test("does not parse unsupported methods or the handler wildcard", () {
      expect(HttpMethod.parseExternal(rawMethod: "OPTIONS"), isNull);
      expect(HttpMethod.parseExternal(rawMethod: "ANY"), isNull);
    });

    test("matches typed methods", () {
      expect(HttpMethod.get.matches(requestMethod: HttpMethod.get), isTrue);
      expect(HttpMethod.get.matches(requestMethod: HttpMethod.post), isFalse);
    });

    test("any matches every parsed method", () {
      for (final method in HttpMethod.values.where((method) => method != HttpMethod.any)) {
        expect(HttpMethod.any.matches(requestMethod: method), isTrue, reason: method.name);
      }
    });
  });

  group("RequestHandler.canHandle", () {
    test("returns false on method mismatch", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      expect(h.canHandle(makeRequest("POST", "/project")), isFalse);
    });

    test("returns false on path mismatch (different segment)", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      expect(h.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns false when segment count differs", () {
      final h = _StubHandler(HttpMethod.get, "/session/:id/message");
      expect(h.canHandle(makeRequest("GET", "/session/abc")), isFalse);
      expect(h.canHandle(makeRequest("GET", "/session/abc/message/extra")), isFalse);
    });

    test("returns true on exact path match", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      expect(h.canHandle(makeRequest("GET", "/project")), isTrue);
    });

    test("returns true when path contains a :param placeholder", () {
      final h = _StubHandler(HttpMethod.get, "/session/:id/message");
      expect(h.canHandle(makeRequest("GET", "/session/abc123/message")), isTrue);
    });

    test("ignores query string when matching path", () {
      final h = _StubHandler(HttpMethod.get, "/session");
      expect(h.canHandle(makeRequest("GET", "/session?start=0&limit=10")), isTrue);
    });

    test("ignores fragment when matching path", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      expect(h.canHandle(makeRequest("GET", "/project#section")), isTrue);
    });

    test("HttpMethod.any + '*' path matches anything", () {
      final h = _StubHandler(HttpMethod.any, "*");
      expect(h.canHandle(makeRequest("GET", "/anything")), isTrue);
      expect(h.canHandle(makeRequest("POST", "/other/path")), isTrue);
      expect(h.canHandle(makeRequest("DELETE", "/")), isTrue);
    });
  });

  group("RequestHandler.extractParams", () {
    test("extracts a single path param", () {
      final h = _StubHandler(HttpMethod.get, "/session/:id/message");
      final p = h.extractParams(makeRequest("GET", "/session/abc123/message"));
      expect(p.pathParams, equals({"id": "abc123"}));
    });

    test("extracts multiple path params", () {
      final h = _StubHandler(HttpMethod.get, "/org/:orgId/repo/:repoId");
      final p = h.extractParams(makeRequest("GET", "/org/my-org/repo/my-repo"));
      expect(p.pathParams, equals({"orgId": "my-org", "repoId": "my-repo"}));
    });

    test("pathParams is empty when path has no placeholders", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      final p = h.extractParams(makeRequest("GET", "/project"));
      expect(p.pathParams, isEmpty);
    });

    test("extracts query params", () {
      final h = _StubHandler(HttpMethod.get, "/session");
      final p = h.extractParams(makeRequest("GET", "/session?start=5&limit=20"));
      expect(p.queryParams, equals({"start": "5", "limit": "20"}));
    });

    test("queryParams is empty when no query string", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      final p = h.extractParams(makeRequest("GET", "/project"));
      expect(p.queryParams, isEmpty);
    });

    test("extracts fragment", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      final p = h.extractParams(makeRequest("GET", "/project#my-section"));
      expect(p.fragment, equals("my-section"));
    });

    test("fragment is null when absent", () {
      final h = _StubHandler(HttpMethod.get, "/project");
      final p = h.extractParams(makeRequest("GET", "/project"));
      expect(p.fragment, isNull);
    });

    test("extracts path params alongside query params and fragment", () {
      final h = _StubHandler(HttpMethod.get, "/session/:id/message");
      final p = h.extractParams(
        makeRequest("GET", "/session/s42/message?limit=5#anchor"),
      );
      expect(p.pathParams, equals({"id": "s42"}));
      expect(p.queryParams, equals({"limit": "5"}));
      expect(p.fragment, equals("anchor"));
    });

    test("catch-all (*) path yields empty pathParams", () {
      final h = _StubHandler(HttpMethod.any, "*");
      final p = h.extractParams(makeRequest("GET", "/anything/at/all?q=1"));
      expect(p.pathParams, isEmpty);
      expect(p.queryParams, equals({"q": "1"}));
    });
  });

  group("GetRequestHandler error mapping", () {
    Future<RelayResponse> respond(Object error) {
      final request = makeRequest("GET", "/throw");
      return _ThrowingGetHandler(error).handleInternal(
        request,
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );
    }

    test("PluginApiException keeps its upstream status", () async {
      final response = await respond(PluginApiException("/session/abc", 404));
      expect(response.status, 404);
    });

    test("PluginOperationException with a status forwards it", () async {
      final response = await respond(const PluginOperationException("op", statusCode: 409));
      expect(response.status, 409);
    });

    test("PluginOperationException without a status maps to 502, not 500", () async {
      final response = await respond(const PluginOperationException("createSession", message: "cli exited 1"));
      expect(response.status, 502);
    });

    test("unknown errors still map to 500", () async {
      final response = await respond(StateError("boom"));
      expect(response.status, 500);
    });
  });
}
