import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/mcp_api.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerCoreFallbackValues();
    registerFallbackValue(const RelayRequest(id: "fixture", method: "POST", path: "/", headers: {}, body: null));
  });

  test("a slow native management action completes after the ordinary relay request budget", () {
    fakeAsync((clock) {
      final connection = MockConnectionService();
      final relay = MockRelayClient();
      when(() => connection.relayClient).thenReturn(relay);
      when(() => relay.isConnected).thenReturn(true);
      when(
        () => relay.sendRequest(
          request: any(named: "request"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (invocation) => Future<RelayResponse>.delayed(
          const Duration(seconds: 45),
          () => const RelayResponse(
            id: "fixture",
            status: 200,
            headers: {},
            body: '{"type":"completed","inventory":{"type":"unknown"}}',
          ),
        ).timeout(invocation.namedArguments[#timeout] as Duration),
      );
      ApiResponse<McpEntryActionResult>? response;
      final api = McpApi(client: RelayHttpApiClient(connection));
      unawaited(
        api
            .executeAction(
              request: const McpEntryActionRequest(
                pluginId: "fixture",
                action: McpServerEntryAction(
                  target: McpServerTarget(scope: McpHarnessScope(), serverKey: "fixture"),
                  action: McpServerAction.reconnect,
                ),
              ),
            )
            .then((result) => response = result),
      );
      clock.elapse(const Duration(seconds: 31));
      expect(response, isNull);
      clock.elapse(const Duration(seconds: 14));
      expect(
        response,
        isA<SuccessResponse<McpEntryActionResult>>().having((result) => result.data, "data", isA<McpActionCompleted>()),
      );
    });
  });
}
