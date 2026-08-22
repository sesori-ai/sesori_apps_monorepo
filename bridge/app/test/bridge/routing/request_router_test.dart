import "dart:async";

import "package:sesori_bridge/src/routing/request_handler.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/routed_request.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RequestRouter", () {
    test("routes to the first matching handler and extracts URI values", () async {
      final calls = <String>[];
      final router = RequestRouter(
        handlers: [
          _TestHandler(
            method: HttpMethod.get,
            path: "/session/:id",
            handle: ({required request, required pathParams, required queryParams, required fragment}) async {
              calls.add("first");
              expect(pathParams, {"id": "s1"});
              expect(queryParams, {"view": "full"});
              expect(fragment, "messages");
              return _response(request: request, status: 201, body: "first");
            },
          ),
          _TestHandler(
            method: HttpMethod.get,
            path: "/session/:id",
            handle: ({required request, required pathParams, required queryParams, required fragment}) async {
              calls.add("second");
              return _response(request: request, status: 202, body: "second");
            },
          ),
        ],
      );

      final pending = router.route(
        request: _request(method: "GET", path: "/session/s1?view=full#messages"),
      );

      expect(
        pending.routeIdentity,
        isA<MatchedRoute>()
            .having((identity) => identity.method, "method", HttpMethod.get)
            .having((identity) => identity.pathTemplate, "pathTemplate", "/session/:id"),
      );
      expect(pending.routeIdentity.diagnosticLabel, "GET /session/:id");
      final outcome = await pending.completion;
      final response = outcome.response;

      expect(outcome, isA<ResponseOnly>());
      expect(response.status, 201);
      expect(response.body, "first");
      expect(calls, ["first"]);
    });

    test("stores an unmodifiable copy of the handler list", () async {
      final handlers = <RequestHandlerBase>[
        _TestHandler(
          method: HttpMethod.get,
          path: "/original",
          handle: ({required request, required pathParams, required queryParams, required fragment}) async {
            return _response(request: request, status: 200, body: "original");
          },
        ),
      ];
      final router = RequestRouter(handlers: handlers);
      handlers
        ..clear()
        ..add(
          _TestHandler(
            method: HttpMethod.get,
            path: "/replacement",
            handle: ({required request, required pathParams, required queryParams, required fragment}) async {
              return _response(request: request, status: 200, body: "replacement");
            },
          ),
        );

      expect((await _route(router, _request(method: "GET", path: "/original"))).status, 200);
      expect((await _route(router, _request(method: "GET", path: "/replacement"))).status, 404);
    });

    test("returns 404 when no handler matches", () async {
      final router = RequestRouter(handlers: const []);

      final pending = router.route(
        request: _request(method: "GET", path: "/unknown?secret=value"),
      );
      final response = (await pending.completion).response;

      expect(pending.routeIdentity, isA<UnmatchedRoute>());
      expect(pending.routeIdentity.diagnosticLabel, "GET unmatched route");
      expect(pending.routeIdentity.diagnosticLabel, isNot(contains("secret")));
      expect(response.status, 404);
      expect(response.body, "no handler found for GET /unknown?secret=value");
    });

    test("returns closed identities for invalid methods and targets", () async {
      final router = RequestRouter(handlers: const []);

      final invalidMethod = router.route(
        request: _request(method: "CUSTOM-secret", path: "/private/path"),
      );
      expect(invalidMethod.routeIdentity, isA<InvalidMethodRoute>());
      expect(invalidMethod.routeIdentity.diagnosticLabel, "invalid method");
      expect((await invalidMethod.completion).response.status, 404);

      final invalidTarget = router.route(
        request: _request(method: "GET", path: "http://[target-secret"),
      );
      expect(invalidTarget.routeIdentity, isA<InvalidTargetRoute>());
      expect(invalidTarget.routeIdentity.diagnosticLabel, "GET invalid target");
      expect((await invalidTarget.completion).response.status, 502);
    });

    test("returns route identity before asynchronous completion", () async {
      final responseGate = Completer<RelayResponse>();
      final router = RequestRouter(
        handlers: [
          _TestHandler(
            method: HttpMethod.get,
            path: "/session/:id",
            handle: ({required request, required pathParams, required queryParams, required fragment}) {
              return responseGate.future;
            },
          ),
        ],
      );

      final pending = router.route(
        request: _request(method: "get", path: "/session/private-id"),
      );

      expect(pending.routeIdentity.diagnosticLabel, "GET /session/:id");
      responseGate.complete(
        _response(
          request: _request(method: "GET", path: "/"),
          status: 200,
          body: "ok",
        ),
      );
      expect((await pending.completion).response.body, "ok");
    });

    test("maps plugin operation failures to their status", () async {
      final router = RequestRouter(
        handlers: [
          _TestHandler(
            method: HttpMethod.get,
            path: "/plugin-failure",
            handle: ({required request, required pathParams, required queryParams, required fragment}) {
              throw const PluginOperationException.notFound("test");
            },
          ),
        ],
      );

      final response = await _route(router, _request(method: "GET", path: "/plugin-failure"));

      expect(response.status, 404);
      expect(response.body, contains("PluginOperationException"));
    });

    test("maps unexpected routing failures to 502", () async {
      final router = RequestRouter(
        handlers: [
          _TestHandler(
            method: HttpMethod.get,
            path: "/failure",
            handle: ({required request, required pathParams, required queryParams, required fragment}) {
              throw StateError("boom");
            },
          ),
        ],
      );

      final response = await _route(router, _request(method: "GET", path: "/failure"));

      expect(response.status, 502);
      expect(response.body, contains("boom"));
    });
  });
}

class _TestHandler({
  required HttpMethod method,
  required String path,
  required final Future<RelayResponse> Function({
    required RelayRequest request,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  })
  _handle,
}) extends RequestHandlerBase {
  this : super(method, path);

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) {
    return _handle(
      request: request,
      pathParams: pathParams,
      queryParams: queryParams,
      fragment: fragment,
    );
  }
}

RelayRequest _request({required String method, required String path}) {
  return RelayMessage.request(
    id: "test-id",
    method: method,
    path: path,
    headers: const {},
    body: null,
  ) as RelayRequest;
}

RelayResponse _response({required RelayRequest request, required int status, required String body}) {
  return RelayResponse(
    id: request.id,
    status: status,
    headers: const {},
    body: body,
  );
}

Future<RelayResponse> _route(RequestRouter router, RelayRequest request) async {
  return (await router.route(request: request).completion).response;
}
