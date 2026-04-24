import "package:sesori_dart_core/src/services/agent_variant_options_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AgentVariantOptionsBuilder", () {
    const builder = AgentVariantOptionsBuilder();

    test("returns empty list when providerID is null", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "xhigh",
            mode: AgentMode.primary,
          ),
        ],
        providerID: null,
        modelID: "gpt-4",
      );
      expect(result, isEmpty);
    });

    test("returns empty list when modelID is null", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "xhigh",
            mode: AgentMode.primary,
          ),
        ],
        providerID: "openai",
        modelID: null,
      );
      expect(result, isEmpty);
    });

    test("returns variant matching the model", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "fast",
            mode: AgentMode.primary,
          ),
          AgentInfo(
            name: "review",
            description: "Review",
            model: AgentModel(providerID: "anthropic", modelID: "claude-3"),
            variant: "deep",
            mode: AgentMode.primary,
          ),
        ],
        providerID: "anthropic",
        modelID: "claude-3",
      );
      expect(result, const [SessionVariant(id: "deep")]);
    });

    test("returns empty list when no agent has the model", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "fast",
            mode: AgentMode.primary,
          ),
        ],
        providerID: "google",
        modelID: "gemini",
      );
      expect(result, isEmpty);
    });

    test("returns empty list when variant is none", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "none",
            mode: AgentMode.primary,
          ),
        ],
        providerID: "openai",
        modelID: "gpt-4",
      );
      expect(result, isEmpty);
    });

    test("returns empty list when variant is null", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: null,
            mode: AgentMode.primary,
          ),
        ],
        providerID: "openai",
        modelID: "gpt-4",
      );
      expect(result, isEmpty);
    });

    test("ignores agent name and only matches by model", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "foo",
            description: "Foo",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "xhigh",
            mode: AgentMode.primary,
          ),
        ],
        providerID: "openai",
        modelID: "gpt-4",
      );
      expect(result, const [SessionVariant(id: "xhigh")]);
    });
  });
}
