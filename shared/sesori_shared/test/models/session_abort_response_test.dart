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
