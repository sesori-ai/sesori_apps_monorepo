import "package:sesori_bridge/src/bridge/routing/request_handler.dart";
import "package:sesori_bridge/src/bridge/routing/request_router.dart";
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

      final response = await router.route(_request(method: "GET", path: "/session/s1?view=full#messages"));

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

      expect((await router.route(_request(method: "GET", path: "/original"))).status, 200);
      expect((await router.route(_request(method: "GET", path: "/replacement"))).status, 404);
    });

    test("returns 404 when no handler matches", () async {
      final router = RequestRouter(handlers: const []);

      final response = await router.route(_request(method: "GET", path: "/unknown"));

      expect(response.status, 404);
      expect(response.body, "no handler found for GET /unknown");
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

      final response = await router.route(_request(method: "GET", path: "/plugin-failure"));

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

      final response = await router.route(_request(method: "GET", path: "/failure"));

      expect(response.status, 502);
      expect(response.body, contains("boom"));
    });
  });
}

typedef _HandleRequest =
    Future<RelayResponse> Function({
      required RelayRequest request,
      required Map<String, String> pathParams,
      required Map<String, String> queryParams,
      required String? fragment,
    });

class _TestHandler extends RequestHandlerBase {
  final _HandleRequest _handle;

  _TestHandler({
    required HttpMethod method,
    required String path,
    required _HandleRequest handle,
  }) : _handle = handle,
       super(method, path);

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
      )
      as RelayRequest;
}

RelayResponse _response({required RelayRequest request, required int status, required String body}) {
  return RelayResponse(
    id: request.id,
    status: status,
    headers: const {},
    body: body,
  );
}
