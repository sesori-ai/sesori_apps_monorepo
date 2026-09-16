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

  test("abort refusal keeps variant-specific fields and conservative fallback", () {
    const refusal = SessionAbortRefusal.notPerformed(
      reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
    );
    expect(refusal.toJson(), {"kind": "notPerformed", "reason": "residentWorkCompletionUnknown"});
    expect(SessionAbortRefusal.fromJson(refusal.toJson()), refusal);
    expect(
      SessionAbortRefusal.fromJson(const {"kind": "notPerformed", "reason": "future"}),
      const SessionAbortRefusal.notPerformed(reason: SessionAbortRefusalReason.unknownEnumValue),
    );
    for (final invalid in const [
      <String, Object?>{"kind": "notPerformed"},
      <String, Object?>{"kind": "notPerformed", "reason": null},
      <String, Object?>{"kind": "notPerformed", "reason": 1},
    ]) {
      expect(() => SessionAbortRefusal.fromJson(invalid), throwsA(anything));
    }
    for (final ambiguous in const [
      <String, Object?>{"reason": "residentWorkCompletionUnknown"},
      <String, Object?>{"kind": null, "reason": "residentWorkCompletionUnknown"},
      <String, Object?>{"kind": "future", "reason": "residentWorkCompletionUnknown"},
    ]) {
      expect(SessionAbortRefusal.fromJson(ambiguous), const SessionAbortRefusal.unknown());
    }
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
