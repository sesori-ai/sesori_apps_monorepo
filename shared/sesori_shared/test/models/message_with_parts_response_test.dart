import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("MessageWithPartsResponse", () {
    test("defaults replayed prompt defaults for an older bridge payload", () {
      final response = MessageWithPartsResponse.fromJson(const {
        "messages": <Object?>[],
        "nextCursor": null,
      });

      expect(response.replayedPromptDefaults, isNull);
    });

    test("an older bridge payload carries no user message count", () {
      final response = MessageWithPartsResponse.fromJson(const {
        "messages": <Object?>[],
        "nextCursor": null,
      });

      expect(response.userMessagesBefore, isNull);
    });

    test("round-trips the user message count", () {
      const response = MessageWithPartsResponse(
        messages: [],
        nextCursor: 7,
        replayedPromptDefaults: null,
        userMessagesBefore: 12,
      );

      expect(response.toJson()["userMessagesBefore"], 12);
      expect(MessageWithPartsResponse.fromJson(response.toJson()).userMessagesBefore, 12);
    });

    test("round-trips replayed prompt defaults", () {
      const defaults = SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "openai", modelID: "gpt-5", variant: "high"),
      );
      const response = MessageWithPartsResponse(
        messages: [],
        nextCursor: null,
        replayedPromptDefaults: defaults,
        userMessagesBefore: 0,
      );

      expect(MessageWithPartsResponse.fromJson(response.toJson()).replayedPromptDefaults, defaults);
    });
  });
}
