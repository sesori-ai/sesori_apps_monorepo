import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a user turn round-trips its invocation, and an unknown source reads as unknown", () {
    const message = Message.user(
      id: "m1",
      sessionID: "s1",
      agent: null,
      time: null,
      promptId: "p1",
      invocation: CommandInvocation(name: "review", source: CommandSource.skill, arguments: "src"),
    );
    final json = message.toJson();

    expect(Message.fromJson(json), message);
    final invocationJson = {...(json["invocation"] as Map<String, dynamic>), "source": "future-kind"};
    expect(
      switch (Message.fromJson({...json, "invocation": invocationJson})) {
        MessageUser(:final invocation) => invocation?.source,
        _ => null,
      },
      CommandSource.unknown,
    );
  });

  test("payloads from older peers omit the new fields", () {
    expect(
      switch (Message.fromJson(const {"role": "user", "id": "m1", "sessionID": "s1"})) {
        MessageUser(:final invocation) => invocation,
        _ => fail("expected a user message"),
      },
      isNull,
    );
    expect(
      SendPromptRequest.fromJson(const {"sessionId": "s1", "parts": <Object>[]}).commandSource,
      isNull,
    );
    expect(
      PluginMetadata.fromJson(const {
        "id": "codex",
        "displayName": "Codex",
        "isDefault": true,
        "state": "ready",
      }).namesCommandInvocations,
      isFalse,
    );
  });
}
