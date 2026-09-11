import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("released request omission preserves client-owned descendant fanout", () {
    final request = AbortSessionRequest.fromJson({"sessionId": "session", "subAgents": "stop"});

    expect(request.useAtomicStop, isFalse);
    expect(request.toJson()["useAtomicStop"], isFalse);
  });

  test("released empty response decodes as no bridge descendant acknowledgment", () {
    final response = SessionAbortResponse.fromJson(const {});

    expect(response.subAgentsHandled, isFalse);
    expect(response.toJson(), {"subAgentsHandled": false});
  });

  test("typed not-performed refusal requires both discriminators", () {
    const refusal = SessionAbortRefusal(
      kind: SessionAbortRefusalKind.notPerformed,
      reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
    );

    expect(SessionAbortRefusal.fromJson(refusal.toJson()), refusal);
    for (final invalid in const [
      <String, Object?>{"kind": "notPerformed"},
      <String, Object?>{"reason": "residentWorkCompletionUnknown"},
      <String, Object?>{"kind": null, "reason": "residentWorkCompletionUnknown"},
      <String, Object?>{"kind": "notPerformed", "reason": null},
    ]) {
      expect(() => SessionAbortRefusal.fromJson(invalid), throwsA(anything));
    }
    expect(
      SessionAbortRefusal.fromJson(const {"kind": "future", "reason": "future"}),
      const SessionAbortRefusal(
        kind: SessionAbortRefusalKind.unknownEnumValue,
        reason: SessionAbortRefusalReason.unknownEnumValue,
      ),
    );
  });

  test("current handshake round-trips explicit atomic handling", () {
    const request = AbortSessionRequest(
      sessionId: "session",
      subAgents: SessionAbortSubAgentPolicy.stop,
      useAtomicStop: true,
    );
    const response = SessionAbortResponse(subAgentsHandled: true);

    expect(AbortSessionRequest.fromJson(request.toJson()), request);
    expect(SessionAbortResponse.fromJson(response.toJson()), response);
  });
}
