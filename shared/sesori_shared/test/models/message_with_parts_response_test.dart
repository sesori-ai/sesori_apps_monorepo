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

    test("round-trips replayed prompt defaults", () {
      const defaults = SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "openai", modelID: "gpt-5", variant: "high"),
      );
      const response = MessageWithPartsResponse(
        messages: [],
        nextCursor: null,
        replayedPromptDefaults: defaults,
      );

      expect(MessageWithPartsResponse.fromJson(response.toJson()).replayedPromptDefaults, defaults);
    });
  });
}
