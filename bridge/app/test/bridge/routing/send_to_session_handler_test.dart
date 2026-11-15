import "dart:convert";

import "package:sesori_bridge/src/routing/send_to_session_handler.dart";
import "package:sesori_bridge/src/services/session_send_rejected_exception.dart";
import "package:sesori_bridge/src/services/session_send_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late _SendService service;
  late SendToSessionHandler handler;

  setUp(() {
    service = _SendService();
    handler = SendToSessionHandler(sessionSendService: service);
  });

  RelayRequest request({required String source, required String target}) => makeRequest(
    "POST",
    "/session/send-to-session",
    body: jsonEncode(SendToSessionRequest(sourceSessionId: source, targetSessionId: target).toJson()),
  );

  test("answers 200 once the target accepted the handoff", () async {
    final response = await handler.routeForTest(request(source: "a", target: "b"));

    expect(response.status, 200);
    expect(service.sends, [("a", "b")]);
  });

  test("answers 409 with the reason a send did not happen", () async {
    service.failure = const SessionSendRejectedException(
      code: SendToSessionErrorCode.targetRefused,
      userFacingReason: "The target is read-only.",
      cause: null,
      causeStackTrace: null,
    );

    final response = await handler.routeForTest(request(source: "a", target: "b"));

    expect(response.status, 409);
    expect(jsonDecode(response.body ?? ""), {"code": "targetRefused", "message": "The target is read-only."});
  });

  test("answers 404 for a missing session", () async {
    service.failure = const PluginOperationException.notFound(operation: "getSession");

    final response = await handler.routeForTest(request(source: "a", target: "b"));

    expect(response.status, 404);
  });

  test("answers 400 for an empty session id", () async {
    final response = await handler.routeForTest(request(source: "", target: "b"));

    expect(response.status, 400);
    expect(service.sends, isEmpty);
  });
}

final class _SendService() implements SessionSendService {
  final List<(String, String)> sends = [];
  Object? failure;

  @override
  Future<void> send({required String sourceSessionId, required String targetSessionId}) async {
    if (failure case final failure?) throw failure;
    sends.add((sourceSessionId, targetSessionId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
