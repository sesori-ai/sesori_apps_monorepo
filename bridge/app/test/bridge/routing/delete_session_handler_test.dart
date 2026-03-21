import "package:sesori_bridge/src/bridge/routing/delete_session_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("DeleteSessionHandler", () {
    late FakeBridgePlugin plugin;
    late DeleteSessionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = DeleteSessionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle DELETE /session/:id", () {
      expect(handler.canHandle(makeRequest("DELETE", "/session/s1")), isTrue);
    });

    test("extracts id from pathParams", () async {
      await handler.handle(
        makeRequest("DELETE", "/session/s1"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastDeleteSessionId, equals("s1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("DELETE", "/session/s1"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
    });

    test("records correct id", () async {
      await handler.handle(
        makeRequest("DELETE", "/session/session-xyz"),
        pathParams: {"id": "session-xyz"},
        queryParams: {},
      );

      expect(plugin.lastDeleteSessionId, equals("session-xyz"));
    });

    test("returns 200 when plugin throws PluginApiException with 404", () async {
      plugin.throwOnDeleteSessionError = PluginApiException("/session/s1", 404);

      final response = await handler.handle(
        makeRequest("DELETE", "/session/s1"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
    });
  });
}
