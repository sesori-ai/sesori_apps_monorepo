import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_external_action_service.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../services/session_external_action_service_test.dart" show action;

void main() {
  setUpAll(() {
    registerFallbackValue(const RelayRequest(id: "fixture", method: "POST", path: "/", headers: {}, body: null));
    registerFallbackValue(Duration.zero);
  });
  test("service uses the declared relay routes, shared bodies and typed native results", () async {
    final connection = MockConnectionService();
    final relay = MockRelayClient();
    final requests = <RelayRequest>[];
    when(() => connection.relayClient).thenReturn(relay);
    when(() => relay.isConnected).thenReturn(true);
    when(
      () => relay.sendRequest(
        request: any(named: "request"),
        timeout: any(named: "timeout"),
      ),
    ).thenAnswer((invocation) async {
      final request = invocation.namedArguments[#request] as RelayRequest;
      requests.add(request);
      return RelayResponse(
        id: request.id,
        status: 200,
        headers: const {},
        body: jsonEncode(
          request.path == "/session/external-actions"
              ? const PendingExternalActionsResponse(data: [action]).toJson()
              : const ExternalActionReplyAccepted().toJson(),
        ),
      );
    });
    final service = SessionExternalActionService(
      repository: SessionRepository(api: SessionApi(client: RelayHttpApiClient(connection))),
    );
    final read = await service.read(requestId: "request", sessionId: "owner");
    expect(read?.authorizationUrl, action.authorizationUrl);
    expect(
      await service.reply(action: read!, choice: ExternalActionChoice.decline),
      isA<ExternalActionReplyAccepted>(),
    );
    expect(requests.map((r) => r.path), ["/session/external-actions", "/external-action/reply"]);
    expect(requests.map((r) => r.method), everyElement("POST"));
    expect(jsonDecode(requests.first.body!), {"sessionId": "owner"});
    expect(jsonDecode(requests.last.body!), {"requestId": "request", "sessionId": "owner", "choice": "decline"});
  });
}
