import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_session_statuses_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionStatusesHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionStatusesHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetSessionStatusesHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /session/status", () {
      expect(handler.canHandle(makeRequest("GET", "/session/status")), isTrue);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns JSON map", () async {
      plugin.sessionStatusesResult = {
        "s1": const PluginSessionStatus.idle(),
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/status"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body.containsKey("s1"), isTrue);
    });

    test("maps idle, busy, and retry correctly", () async {
      plugin.sessionStatusesResult = {
        "idle-session": const PluginSessionStatus.idle(),
        "busy-session": const PluginSessionStatus.busy(),
        "retry-session": const PluginSessionStatus.retry(
          attempt: 2,
          message: "Rate limited",
          next: 123456,
        ),
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/status"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;

      final idle = body["idle-session"] as Map<String, dynamic>;
      expect(idle["type"], equals("idle"));

      final busy = body["busy-session"] as Map<String, dynamic>;
      expect(busy["type"], equals("busy"));

      final retry = body["retry-session"] as Map<String, dynamic>;
      expect(retry["type"], equals("retry"));
      expect(retry["attempt"], equals(2));
      expect(retry["message"], equals("Rate limited"));
      expect(retry["next"], equals(123456));
    });
  });
}
