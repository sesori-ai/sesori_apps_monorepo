import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_relay_bridge.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  test("a socket close reports the drop before the requests it cut off fail", () async {
    final bridge = FakeRelayBridge(answer: (_) => null);
    final service = await bridge.connect();
    expect(service.currentStatus, isA<ConnectionConnected>());
    final observed = <Object>[];
    final statusSubscription = service.status.skip(1).listen(observed.add);
    addTearDown(statusSubscription.cancel);

    final requestArrived = bridge.unansweredRequests.first;
    final response = RelayHttpApiClient(service).get("/plugin", fromJson: PluginListResponse.fromJson);
    await requestArrived;
    await bridge.closeSocket();
    observed.add(await response);

    expect(observed, [
      isA<ConnectionReconnecting>(),
      isA<ErrorResponse<PluginListResponse>>().having(
        (response) => response.error,
        "error",
        isA<DartHttpClientError>().having(
          (error) => error.innerError,
          "innerError",
          // The socket's close, not the teardown that follows it.
          isA<RelayResponseLostException>().having(
            (lost) => lost.message,
            "message",
            startsWith("Relay socket closed"),
          ),
        ),
      ),
    ]);
  });
}
