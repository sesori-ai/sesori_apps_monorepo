import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeConfig.fromJson", () {
    test("parses model and small_model correctly", () {
      final config = OpenCodeConfig.fromJson({
        "model": "claude-opus-4",
        "small_model": "claude-haiku-3",
      });

      expect(config.model, equals("claude-opus-4"));
      expect(config.smallModel, equals("claude-haiku-3"));
    });

    test("handles missing fields gracefully — both null", () {
      final config = OpenCodeConfig.fromJson({});

      expect(config.model, isNull);
      expect(config.smallModel, isNull);
    });

    test("ignores unknown fields in the response", () {
      final config = OpenCodeConfig.fromJson({
        "model": "gpt-4o",
        "small_model": "gpt-4o-mini",
        "some_unknown_field": "ignored",
        "another_field": 42,
      });

      expect(config.model, equals("gpt-4o"));
      expect(config.smallModel, equals("gpt-4o-mini"));
    });
  });

  group("SendMessageSyncBody.toJson", () {
    test("serializes parts, system, and model correctly", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hello"},
        ],
        system: "You are a helpful assistant.",
        model: (providerID: "anthropic", modelID: "claude-opus-4"),
      );

      final json = body.toJson();

      expect(
        json["parts"],
        equals([
          {"type": "text", "text": "Hello"},
        ]),
      );
      expect(json["system"], equals("You are a helpful assistant."));
      expect(json["model"], equals({"providerID": "anthropic", "modelID": "claude-opus-4"}));
    });

    test("omits null system from JSON", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hi"},
        ],
        system: null,
        model: null,
      );

      final json = body.toJson();

      expect(json.containsKey("system"), isFalse);
      expect(json.containsKey("model"), isFalse);
    });

    test("omits null model from JSON", () {
      const body = SendMessageSyncBody(
        parts: [
          {"type": "text", "text": "Hi"},
        ],
        system: "sys",
        model: null,
      );

      final json = body.toJson();

      expect(json["system"], equals("sys"));
      expect(json.containsKey("model"), isFalse);
    });

    test("includes model when provided but system is null", () {
      const body = SendMessageSyncBody(
        parts: [],
        system: null,
        model: (providerID: "openai", modelID: "gpt-4o"),
      );

      final json = body.toJson();

      expect(json.containsKey("system"), isFalse);
      expect(json["model"], equals({"providerID": "openai", "modelID": "gpt-4o"}));
    });
  });
}
