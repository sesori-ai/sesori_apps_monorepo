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
        cannotContinueMessage: null,
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
        cannotContinueMessage: null,
      );

      expect(MessageWithPartsResponse.fromJson(response.toJson()).replayedPromptDefaults, defaults);
    });

    test("round-trips a can't-continue message", () {
      const response = MessageWithPartsResponse(
        messages: [],
        nextCursor: null,
        replayedPromptDefaults: null,
        awaitingHarnessSync: true,
        userMessagesBefore: 0,
        cannotContinueMessage: "This session can't be continued.",
      );

      final decoded = MessageWithPartsResponse.fromJson(response.toJson());
      expect(decoded.cannotContinueMessage, "This session can't be continued.");
      expect(decoded.awaitingHarnessSync, isTrue);
    });

    test("an older bridge payload carries no can't-continue message", () {
      final response = MessageWithPartsResponse.fromJson(const {
        "messages": <Object?>[],
        "nextCursor": null,
      });

      expect(response.cannotContinueMessage, isNull);
    });
  });
}
