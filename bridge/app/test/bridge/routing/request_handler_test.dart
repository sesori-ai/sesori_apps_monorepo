import "package:sesori_bridge/src/bridge/routing/request_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

// Minimal concrete subclass used to exercise base-class behaviour.
class _StubHandler extends RequestHandlerBase {
  _StubHandler(super.method, super.path);

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

void main() {
  group("HttpMethod.matches", () {
    test("each method matches its own name (uppercase)", () {
      expect(HttpMethod.get.matches("GET"), isTrue);
      expect(HttpMethod.post.matches("POST"), isTrue);
      expect(HttpMethod.put.matches("PUT"), isTrue);
      expect(HttpMethod.patch.matches("PATCH"), isTrue);
      expect(HttpMethod.delete.matches("DELETE"), isTrue);
    });

    test("matching is case-insensitive", () {
      expect(HttpMethod.get.matches("get"), isTrue);
      expect(HttpMethod.post.matches("Post"), isTrue);
      expect(HttpMethod.delete.matches("delete"), isTrue);
    });

    test("method mismatch returns false", () {
      expect(HttpMethod.get.matches("POST"), isFalse);
      expect(HttpMethod.post.matches("GET"), isFalse);
      expect(HttpMethod.put.matches("PATCH"), isFalse);
    });

    test("any matches every method string", () {
      for (final raw in ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"]) {
        expect(HttpMethod.any.matches(raw), isTrue, reason: raw);
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
}
