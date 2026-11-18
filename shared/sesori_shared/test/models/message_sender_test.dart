import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("MessageAssistant.sender", () {
    test("defaults an older bridge payload to agent", () {
      final message = Message.fromJson({
        "role": "assistant",
        "id": "msg-1",
        "sessionID": "session-1",
        "agent": null,
        "modelID": null,
        "providerID": null,
        "time": null,
      });

      expect(message, isA<MessageAssistant>());
      expect((message as MessageAssistant).sender, MessageSender.agent);
    });

    for (final (sender, wire) in [(MessageSender.system, "system"), (MessageSender.sesori, "sesori")]) {
      test("round-trips $wire attribution on the assistant wire envelope", () {
        final message = Message.assistant(
          id: "msg-1",
          sessionID: "session-1",
          agent: null,
          modelID: null,
          providerID: null,
          sender: sender,
          time: null,
        );

        final json = message.toJson();

        expect(json["role"], "assistant");
        expect(json["sender"], wire);
        expect(Message.fromJson(json), message);
      });
    }

    test("decodes a future sender as unknown", () {
      final message = Message.fromJson({
        "role": "assistant",
        "id": "msg-1",
        "sessionID": "session-1",
        "sender": "future-sender",
      });

      expect((message as MessageAssistant).sender, MessageSender.unknown);
    });
  });
}
