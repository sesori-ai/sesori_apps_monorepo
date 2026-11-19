import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../services/pending_page_service_test.dart" show page;

void main() {
  setUpAll(() {
    registerFallbackValue(const RelayRequest(id: "fixture", method: "POST", path: "/", headers: {}, body: null));
    registerFallbackValue(Duration.zero);
  });
  late MockRelayClient relay;
  late SessionApi api;
  setUp(() {
    final connection = MockConnectionService();
    relay = MockRelayClient();
    when(() => connection.relayClient).thenReturn(relay);
    when(() => relay.isConnected).thenReturn(true);
    api = SessionApi(client: RelayHttpApiClient(connection));
  });

  const submitRequest = SubmitPageRequest(
    requestId: "sesori-page-1",
    sessionId: "owner",
    answers: [
      PageAnswer(
        questionId: "plan",
        value: PageChoiceAnswer(optionId: "a"),
        note: null,
      ),
    ],
    note: null,
  );

  test("page routes send typed bodies and decode their results", () async {
    final requests = <RelayRequest>[];
    when(
      () => relay.sendRequest(
        request: any(named: "request"),
        timeout: any(named: "timeout"),
      ),
    ).thenAnswer((
      invocation,
    ) async {
      final request = invocation.namedArguments[#request] as RelayRequest;
      requests.add(request);
      return RelayResponse(
        id: request.id,
        status: 200,
        headers: const {},
        body: jsonEncode(switch (request.path) {
          "/page" => const PageLookupResponse.pending(page: page).toJson(),
          _ => const PageSubmitResult.alreadySettled().toJson(),
        }),
      );
    });

    final lookup = await api.lookupPage(
      request: const PageLookupRequest(sessionId: "root", requestId: "sesori-page-1"),
    );
    expect((lookup as SuccessResponse<PageLookupResponse>).data, const PageLookupPending(page: page));
    final submitted = await api.submitPage(request: submitRequest);
    expect((submitted as SuccessResponse<PageSubmitResult>).data, const PageSubmitAlreadySettled());

    expect(requests.map((r) => r.path), ["/page", "/page/submit"]);
    expect(jsonDecode(requests.first.body ?? fail("no request body")), {
      "sessionId": "root",
      "requestId": "sesori-page-1",
    });
    expect(jsonDecode(requests.last.body ?? fail("no request body")), submitRequest.toJson());
  });

  for (final path in ["/page", "/page/submit"]) {
    test("$path response errors omit page content", () async {
      when(
        () => relay.sendRequest(
          request: any(named: "request"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) async =>
            const RelayResponse(id: "request", status: 200, headers: {}, body: '{"private":"private-fixture-answer",'),
      );
      final ApiResponse<Object> response = path == "/page"
          ? await api.lookupPage(
              request: const PageLookupRequest(sessionId: "root", requestId: "sesori-page-1"),
            )
          : await api.submitPage(request: submitRequest);
      final error = (response as ErrorResponse<Object>).error;
      expect(error.toString(), isNot(contains("private-fixture-answer")));
    });
  }
}
