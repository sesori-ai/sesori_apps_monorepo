import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../services/pending_form_service_test.dart" show form;

void main() {
  setUpAll(() {
    registerFallbackValue(const RelayRequest(id: "fixture", method: "POST", path: "/", headers: {}, body: null));
    registerFallbackValue(Duration.zero);
  });
  late MockConnectionService connection;
  late MockRelayClient relay;
  late SessionApi api;
  setUp(() {
    connection = MockConnectionService();
    relay = MockRelayClient();
    when(() => connection.relayClient).thenReturn(relay);
    when(() => relay.isConnected).thenReturn(true);
    api = SessionApi(client: RelayHttpApiClient(connection));
  });

  test("declared form routes use typed bodies and decode actual JSON field errors", () async {
    final requests = <RelayRequest>[];
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
        body: jsonEncode(switch (request.path) {
          "/session/forms" => const PendingFormsResponse(data: [form]).toJson(),
          "/form/reply" => const FormValidationFailed(
            fieldErrors: {"integer": FormValidationIssue.outOfRange},
          ).toJson(),
          _ => const FormReplyAccepted().toJson(),
        }),
      );
    });
    final snapshot = await api.getPendingForms(sessionId: "owner");
    expect((snapshot as SuccessResponse<PendingFormsResponse>).data.data.single, form);
    final submitted = await api.replyToForm(
      request: const ReplyToFormRequest(
        requestId: "request",
        sessionId: "owner",
        values: {"boolean": FormBooleanValue(value: false), "integer": FormIntegerValue(value: 0)},
      ),
    );
    expect(
      (submitted as SuccessResponse<FormReplyResult>).data,
      const FormValidationFailed(fieldErrors: {"integer": FormValidationIssue.outOfRange}),
    );
    await api.declineForm(
      request: const DeclineFormRequest(requestId: "request", sessionId: "owner", choice: FormDismissalChoice.cancel),
    );
    expect(requests.map((r) => r.path), ["/session/forms", "/form/reply", "/form/decline"]);
    expect(jsonDecode(requests[1].body!), {
      "requestId": "request",
      "sessionId": "owner",
      "values": {
        "boolean": {"type": "boolean", "value": false},
        "integer": {"type": "integer", "value": 0},
      },
    });
    expect(jsonDecode(requests.last.body!), {"requestId": "request", "sessionId": "owner", "choice": "cancel"});
  });

  for (final path in ["/session/forms", "/form/reply", "/form/decline"]) {
    for (final status in [200, 503]) {
      test("$path response errors omit form content for status $status", () async {
        when(
          () => relay.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => RelayResponse(
            id: "request",
            status: status,
            headers: const {},
            body: '{"private":"private-fixture-answer",',
          ),
        );
        final ApiResponse<Object> response = switch (path) {
          "/session/forms" => await api.getPendingForms(sessionId: "owner"),
          "/form/reply" => await api.replyToForm(
            request: const ReplyToFormRequest(requestId: "request", sessionId: "owner", values: {}),
          ),
          _ => await api.declineForm(
            request: const DeclineFormRequest(
              requestId: "request",
              sessionId: "owner",
              choice: FormDismissalChoice.cancel,
            ),
          ),
        };
        final error = (response as ErrorResponse<Object>).error;
        expect(error.toString(), isNot(contains("private-fixture-answer")));
        if (status == 200) {
          expect(
            error,
            isA<JsonParsingError>()
                .having((e) => e.jsonString, "body", "Sensitive response omitted")
                .having((e) => e.innerError, "original cause", isA<FormatException>()),
          );
        } else {
          expect(error, isA<NonSuccessCodeError>().having((e) => e.rawErrorString, "body", isNull));
        }
      });
    }
  }
}
