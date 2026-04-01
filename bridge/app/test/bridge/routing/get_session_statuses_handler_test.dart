import "package:sesori_bridge/src/bridge/routing/get_session_statuses_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("returns typed statuses map", () async {
      plugin.sessionStatusesResult = {
        "s1": const PluginSessionStatus.idle(),
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/status"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.statuses.containsKey("s1"), isTrue);
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
        fragment: null,
      );

      expect(response.statuses["idle-session"], equals(const SessionStatus.idle()));
      expect(response.statuses["busy-session"], equals(const SessionStatus.busy()));
      expect(
        response.statuses["retry-session"],
        equals(const SessionStatus.retry(attempt: 2, message: "Rate limited", next: 123456)),
      );
    });
  });
}
