import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _target = McpServerTarget(
  scope: McpSessionScope(sessionId: "session"),
  serverKey: "opaque/server",
);
const _attempt = McpAuthenticationAttempt(
  attemptId: "attempt",
  pluginId: "integration",
  target: _target,
  cancellation: McpAuthenticationCancellation.cancelable,
);

void main() {
  test("each native authentication state round-trips with its required data", () {
    for (final state in <McpAuthenticationState>[
      const McpAuthenticationIdle(),
      const McpAuthenticationStarting(attempt: _attempt),
      const McpAuthenticationCallbackChallenge(
        attempt: _attempt,
        authorizationUrl: "https://issuer.example/authorize?state=secret",
        expectedCallbackUrl: "http://localhost:4321/callback",
      ),
      const McpAuthenticationSettling(attempt: _attempt),
      const McpAuthenticationCompleted(attempt: _attempt),
      const McpAuthenticationFailed(attempt: _attempt, reason: McpAuthenticationFailureReason.declined),
      const McpAuthenticationCancelled(attempt: _attempt),
    ]) {
      final result = McpAuthenticationStateResult(state: state);
      expect(McpAuthenticationResult.fromJson(result.toJson()).toJson(), result.toJson());
      expect(state.toString(), isNot(contains("secret")));
      expect(result.toString(), isNot(contains("secret")));
    }
  });

  test("callback request round-trips without exposing credentials in presentation", () {
    const request = McpAuthenticationContinueRequest(
      attemptId: "attempt",
      callbackUrl: "http://localhost:4321/callback?code=private-code&state=secret",
    );
    expect(McpAuthenticationContinueRequest.fromJson(request.toJson()).toJson(), request.toJson());
    expect(request.toString(), isNot(contains("private-code")));
    expect(request.toString(), isNot(contains("secret")));
  });

  test("unknown response and state variants degrade explicitly", () {
    expect(McpAuthenticationResult.fromJson({"type": "future"}), isA<McpAuthenticationResultUnknown>());
    expect(McpAuthenticationState.fromJson({"type": "future"}), isA<McpAuthenticationUnknown>());
    final unavailable = McpAuthenticationResult.fromJson({"type": "unavailable", "reason": "future"});
    expect((unavailable as McpAuthenticationUnavailable).reason, McpAuthenticationUnavailableReason.unknown);
    final attempt = McpAuthenticationAttempt.fromJson({..._attempt.toJson(), "cancellation": "future"});
    expect(attempt.cancellation, McpAuthenticationCancellation.unknown);
  });

  test("malformed callback decoding cannot reflect authorization data into an error", () {
    expect(
      () => McpAuthenticationContinueRequest.fromJson({
        "attemptId": "attempt",
        "callbackUrl": ["private-code"],
      }),
      throwsA(
        isA<McpAuthenticationCallbackDecodingException>()
            .having((error) => error.innerError, "innerError", isA<TypeError>())
            .having((error) => error.toString(), "presentation", isNot(contains("private-code"))),
      ),
    );
  });

  test("start and cancel preserve target and attempt binding", () {
    const start = McpAuthenticationStartRequest(pluginId: "integration", target: _target);
    const cancel = McpAuthenticationCancelRequest(attemptId: "attempt");
    expect(McpAuthenticationStartRequest.fromJson(start.toJson()).toJson(), start.toJson());
    expect(McpAuthenticationCancelRequest.fromJson(cancel.toJson()).toJson(), cancel.toJson());
    expect(
      () => McpAuthenticationStartRequest.fromJson({
        "pluginId": "integration",
        "target": const McpConnectorOfferTarget(scope: McpHarnessScope(), offerKey: "other").toJson(),
      }),
      throwsFormatException,
    );
  });
}
