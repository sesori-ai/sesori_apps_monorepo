import "package:sesori_bridge/src/bridge/routing/proxy_handler.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("ProxyHandler", () {
    late FakeBridgePlugin plugin;
    late ProxyHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = ProxyHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle any GET request", () {
      expect(handler.canHandle(makeRequest("GET", "/anything")), isTrue);
    });

    test("canHandle any POST request", () {
      expect(handler.canHandle(makeRequest("POST", "/resource")), isTrue);
    });

    test("canHandle any DELETE request", () {
      expect(handler.canHandle(makeRequest("DELETE", "/foo/bar")), isTrue);
    });

    test("forwards method to plugin.proxyRequest", () async {
      await handler.handle(
        makeRequest("POST", "/api/run"),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastProxyMethod, equals("POST"));
    });

    test("forwards full path (including query string) to plugin.proxyRequest", () async {
      await handler.handle(
        makeRequest("GET", "/api/v1/resource?foo=bar"),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastProxyPath, equals("/api/v1/resource?foo=bar"));
    });

    test("forwards headers to plugin.proxyRequest", () async {
      const headers = {"authorization": "Bearer tok", "x-custom": "val"};
      await handler.handle(
        makeRequest("GET", "/api", headers: headers),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastProxyHeaders, equals(headers));
    });

    test("forwards body to plugin.proxyRequest", () async {
      await handler.handle(
        makeRequest("POST", "/api", body: '{"key":"value"}'),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastProxyBody, equals('{"key":"value"}'));
    });

    test("forwards null body to plugin.proxyRequest", () async {
      await handler.handle(
        makeRequest("GET", "/api"),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastProxyBody, isNull);
    });

    test("returns the proxy status code", () async {
      plugin.proxyStatus = 201;
      final response = await handler.handle(
        makeRequest("POST", "/resource"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(201));
    });

    test("returns the proxy response headers", () async {
      plugin.proxyHeaders = {"x-created": "yes", "location": "/resource/1"};
      final response = await handler.handle(
        makeRequest("POST", "/resource"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.headers, equals({"x-created": "yes", "location": "/resource/1"}));
    });

    test("returns the proxy response body", () async {
      plugin.proxyBody = '{"id":"new"}';
      final response = await handler.handle(
        makeRequest("POST", "/resource"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.body, equals('{"id":"new"}'));
    });

    test("returns null body when proxy returns null", () async {
      plugin.proxyBody = null;
      final response = await handler.handle(
        makeRequest("DELETE", "/resource/1"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.body, isNull);
    });
  });
}
