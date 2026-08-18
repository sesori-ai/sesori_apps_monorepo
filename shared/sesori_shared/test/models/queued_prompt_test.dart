import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("QueuedSessionPrompt", () {
    test("round-trips all fields through JSON", () {
      const prompt = QueuedSessionPrompt(
        id: "prm_1234",
        text: "fix the tests",
        command: null,
        attachmentCount: 2,
        createdAt: 1755450000000,
      );

      final decoded = QueuedSessionPrompt.fromJson(prompt.toJson());

      expect(decoded, equals(prompt));
    });

    test("round-trips a command entry with null text", () {
      const prompt = QueuedSessionPrompt(
        id: "prm_5678",
        text: null,
        command: "review",
        attachmentCount: 0,
        createdAt: 1755450000000,
      );

      final json = prompt.toJson();
      final decoded = QueuedSessionPrompt.fromJson(json);

      expect(json.containsKey("text"), isFalse, reason: "null text must be omitted, never an empty string");
      expect(decoded, equals(prompt));
    });

    test("decodes a payload without attachmentCount to zero", () {
      final decoded = QueuedSessionPrompt.fromJson({
        "id": "prm_9",
        "createdAt": 1,
      });

      expect(decoded.attachmentCount, 0);
      expect(decoded.text, isNull);
      expect(decoded.command, isNull);
    });
  });

  group("QueuedPromptResponse", () {
    test("round-trips its data list through JSON", () {
      const response = QueuedPromptResponse(
        data: [
          QueuedSessionPrompt(id: "prm_1", text: "a", command: null, attachmentCount: 0, createdAt: 1),
          QueuedSessionPrompt(id: "prm_2", text: null, command: "compact", attachmentCount: 0, createdAt: 2),
        ],
      );

      expect(QueuedPromptResponse.fromJson(response.toJson()), equals(response));
    });
  });

  group("CancelQueuedPromptRequest", () {
    test("round-trips through JSON", () {
      const request = CancelQueuedPromptRequest(sessionId: "ses_1", promptId: "prm_1");

      expect(CancelQueuedPromptRequest.fromJson(request.toJson()), equals(request));
    });
  });

  group("SendPromptRequest.promptId", () {
    test("round-trips when present and is omitted from JSON when null", () {
      const withId = SendPromptRequest(
        sessionId: "ses_1",
        parts: [PromptPart.text(text: "hello")],
        agent: null,
        model: null,
        command: null,
        variant: null,
        promptId: "prm_abc",
      );

      expect(SendPromptRequest.fromJson(withId.toJson()).promptId, "prm_abc");

      final withoutId = withId.copyWith(promptId: null).toJson();
      expect(withoutId.containsKey("promptId"), isFalse);
    });

    test("decodes an old-client payload without promptId to null", () {
      final decoded = SendPromptRequest.fromJson({
        "sessionId": "ses_1",
        "parts": [
          {"type": "text", "text": "hello"},
        ],
      });

      expect(decoded.promptId, isNull);
    });
  });

  group("MessageUser.promptId", () {
    test("round-trips when present and decodes old payloads to null", () {
      const message = Message.user(
        id: "msg_1",
        sessionID: "ses_1",
        agent: null,
        time: null,
        promptId: "prm_abc",
      );

      final decoded = Message.fromJson(message.toJson());
      expect(decoded, isA<MessageUser>());
      expect((decoded as MessageUser).promptId, "prm_abc");

      final old = Message.fromJson({"role": "user", "id": "msg_1", "sessionID": "ses_1"});
      expect((old as MessageUser).promptId, isNull);
    });
  });

  group("SesoriSessionQueuedPrompts", () {
    test("round-trips through the SSE union with its wire type tag", () {
      const event = SesoriSseEvent.sessionQueuedPrompts(
        sessionID: "ses_1",
        prompts: [
          QueuedSessionPrompt(id: "prm_1", text: "queued text", command: null, attachmentCount: 1, createdAt: 7),
        ],
      );

      final json = event.toJson();
      expect(json["type"], "session.queued-prompts");

      final decoded = SesoriSseEvent.fromJson(json);
      expect(decoded, equals(event));
      expect(decoded, isA<SesoriSessionEvent>());
    });
  });
}
