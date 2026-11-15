import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  Message userMessage({required MessageHandoff? handoff}) => Message.user(
    id: "m1",
    sessionID: "s1",
    agent: null,
    time: null,
    promptId: "p1",
    invocation: null,
    handoff: handoff,
  );

  MessageHandoff? handoffOf(Message message) => switch (message) {
    MessageUser(:final handoff) => handoff,
    _ => fail("expected a user message"),
  };

  test("a user message round-trips each handoff kind under the kind key", () {
    const handoffs = [
      MessageHandoff.sent(targetSessionId: "target", targetTitle: "Target"),
      MessageHandoff.notSent(targetSessionId: "target", targetTitle: null),
      MessageHandoff.received(
        sourceSessionId: "source",
        sourceTitle: null,
        summary: "Fixture summary",
        transcriptPath: "/fixture/transcript.md",
      ),
    ];
    for (final handoff in handoffs) {
      final json = userMessage(handoff: handoff).toJson();

      expect(Message.fromJson(json), userMessage(handoff: handoff));
    }
    expect(MessageHandoff.fromJson(handoffs.first.toJson()), handoffs.first);
    expect(handoffs.first.toJson()["kind"], "sent");
    expect(handoffs[1].toJson()["kind"], "notSent");
  });

  test("a kind this build does not know reads as unknown", () {
    final json = {
      ...userMessage(handoff: null).toJson(),
      "handoff": {"kind": "forwarded", "targetSessionId": "target"},
    };

    expect(handoffOf(Message.fromJson(json)), const MessageHandoff.unknown());
  });

  test("older payloads omit the key, and a reader that predates it ignores it", () {
    expect(handoffOf(Message.fromJson(const {"role": "user", "id": "m1", "sessionID": "s1"})), isNull);

    // An older client decodes the same JSON with no handoff field; the
    // generated decoder ignores keys it does not know, as it does here for one
    // this build does not know.
    final withNewKey = {
      ...userMessage(handoff: const MessageHandoff.sent(targetSessionId: "target", targetTitle: null)).toJson(),
      "laterField": {"kind": "anything"},
    };
    expect(handoffOf(Message.fromJson(withNewKey)), isA<MessageHandoffSent>());
  });

  test("printing a received handoff leaves the summary out", () {
    const handoff = MessageHandoff.received(
      sourceSessionId: "source",
      sourceTitle: null,
      summary: "Fixture summary",
      transcriptPath: "/fixture/transcript.md",
    );

    expect("$handoff", isNot(contains("Fixture summary")));
  });
}
